// Test UI layar Chat (Fase 2) — repository palsu, tanpa jaringan.
import 'dart:async';

import 'package:codementor_mobile/core/widgets/code_block_view.dart';
import 'package:codementor_mobile/features/chat/data/chat_repository.dart';
import 'package:codementor_mobile/features/chat/domain/chat_answer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_test_harness.dart';
import 'support/fake_chat_repository.dart';

/// Jawaban AI contoh: heading + paragraf tebal + blok kode.
const String _answerMarkdown = '''
## Penyebab

Variabel **x** belum didefinisikan sebelum dipakai.

```python
x = 1
print(y)
```
''';

const ChatAnswer _answer = ChatAnswer(
  explanation: _answerMarkdown,
  confidence: 92,
  detectedErrorCode: 'NameError',
  responseTimeMs: 900,
  ragMatches: 2,
  chatHistoryId: 'h1',
);

/// Menyalakan aplikasi di tab Chat (user biasa) dengan repository palsu.
Future<void> _pumpChat(WidgetTester tester, FakeChatRepository repo) async {
  await pumpApp(
    tester,
    session: studentSession(),
    overrides: [chatRepositoryProvider.overrideWithValue(repo)],
  );
  expect(find.text('Tempel kode & pesan errornya'), findsOneWidget);
}

/// Isi kode lalu tekan Kirim.
Future<void> _send(WidgetTester tester, String code, {String? error}) async {
  await tester.enterText(find.byType(TextField).first, code);
  if (error != null) {
    await tester.enterText(find.byType(TextField).last, error);
  }
  await tester.pump();
  await tester.tap(find.text('Kirim'));
  await pumpSteps(tester);
}

void main() {
  setUpAll(configureAppTests);
  setUp(configureAppTests);

  testWidgets('kirim kode: bubble user, jawaban AI, dan metanya', (
    tester,
  ) async {
    final repo = FakeChatRepository()..answer = _answer;
    await _pumpChat(tester, repo);

    await _send(tester, 'print(x)', error: 'NameError: name x is not defined');

    // Permintaan terkirim apa adanya (pesan error ikut).
    expect(repo.requests.single.sourceCode, 'print(x)');
    expect(repo.requests.single.language, 'python');
    expect(repo.requests.single.errorMessage, 'NameError: name x is not defined');

    // Bubble user: kode + pesan error masih terlihat, editor sudah bersih.
    expect(find.textContaining('NameError: name x is not defined'), findsOneWidget);
    // Dua blok kode: milik user + milik jawaban AI.
    expect(find.byType(CodeBlockView), findsNWidgets(2));

    // Jawaban AI: heading & paragraf (Markdown) dan blok kode di dalamnya.
    expect(find.textContaining('Penyebab'), findsWidgets);
    expect(find.textContaining('belum didefinisikan sebelum dipakai'), findsOneWidget);
    expect(find.textContaining('x = 1'), findsOneWidget);

    // Meta jawaban: error code, keyakinan, rujukan KB, tombol salin & feedback.
    expect(find.text('NameError'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget);
    expect(find.text('2 rujukan KB'), findsOneWidget);
    expect(find.text('0.9s'), findsOneWidget);
    expect(find.byTooltip('Salin jawaban'), findsOneWidget);
    expect(find.byTooltip('Membantu'), findsOneWidget);
    expect(find.byTooltip('Kurang tepat'), findsOneWidget);
  });

  testWidgets('umpan balik: thumbs up langsung, thumbs down lewat dialog', (
    tester,
  ) async {
    final repo = FakeChatRepository()..answer = _answer;
    await _pumpChat(tester, repo);
    await _send(tester, 'print(x)');

    // Thumbs up: langsung tersimpan.
    await tester.tap(find.byTooltip('Membantu'));
    await pumpSteps(tester);
    expect(repo.feedbackCalls.single.chatHistoryId, 'h1');
    expect(repo.feedbackCalls.single.feedback, ChatFeedback.helpful);
    expect(find.textContaining('Terima kasih'), findsOneWidget);

    // Biarkan SnackBar hilang dulu supaya tidak menutupi tombol.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));

    // Thumbs down: meminta komentar (opsional) lewat dialog.
    await tester.tap(find.byTooltip('Kurang tepat'));
    await pumpSteps(tester);
    expect(find.text('Apa yang kurang tepat?'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Jawabannya terlalu singkat',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Kirim'),
      ),
    );
    await pumpSteps(tester);

    expect(repo.feedbackCalls, hasLength(2));
    expect(repo.feedbackCalls.last.feedback, ChatFeedback.notHelpful);
    expect(repo.feedbackCalls.last.comment, 'Jawabannya terlalu singkat');
  });

  testWidgets('gagal mengirim: pesan error + tombol Coba lagi', (tester) async {
    final repo = FakeChatRepository()
      ..askError = const ChatException(
        'Tidak dapat terhubung ke server. Periksa koneksi internetmu.',
      );
    await _pumpChat(tester, repo);

    await _send(tester, 'print(x)');

    expect(find.text('GAGAL MENGIRIM'), findsOneWidget);
    expect(
      find.textContaining('Tidak dapat terhubung ke server'),
      findsOneWidget,
    );
    expect(find.byType(CodeBlockView), findsOneWidget); // hanya kode user

    // Coba lagi -> berhasil.
    repo.answer = const ChatAnswer(explanation: 'Sudah bisa berjalan.');
    await tester.tap(find.text('Coba lagi'));
    await pumpSteps(tester);

    expect(find.text('GAGAL MENGIRIM'), findsNothing);
    expect(find.textContaining('Sudah bisa berjalan'), findsOneWidget);
    expect(repo.requests, hasLength(2));
  });

  testWidgets('selagi menunggu jawaban: bubble "Menganalisis" tampil', (
    tester,
  ) async {
    final repo = FakeChatRepository();
    final gate = Completer<void>();
    repo
      ..pending = gate
      ..answer = _answer;

    await _pumpChat(tester, repo);
    await tester.enterText(find.byType(TextField).first, 'print(x)');
    await tester.pump();
    await tester.tap(find.text('Kirim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Menganalisis'), findsOneWidget);
    expect(find.text('Menganalisis kode python...'), findsOneWidget);

    gate.complete();
    await pumpSteps(tester);
    expect(find.textContaining('Menganalisis kode'), findsNothing);
    expect(find.textContaining('Penyebab'), findsWidgets);
  });

  testWidgets('kode kosong: tombol Kirim tidak mengirim apa pun', (
    tester,
  ) async {
    final repo = FakeChatRepository();
    await _pumpChat(tester, repo);

    await tester.tap(find.text('Kirim'));
    await pumpSteps(tester);

    expect(repo.requests, isEmpty);
    expect(find.text('Tempel kode & pesan errornya'), findsOneWidget);
  });

  testWidgets('Bersihkan mengosongkan percakapan', (tester) async {
    final repo = FakeChatRepository()..answer = _answer;
    await _pumpChat(tester, repo);
    await _send(tester, 'print(x)');

    expect(find.byType(CodeBlockView), findsNWidgets(2));

    await tester.tap(find.text('Bersihkan'));
    await pumpSteps(tester);

    expect(find.byType(CodeBlockView), findsNothing);
    expect(find.text('Tempel kode & pesan errornya'), findsOneWidget);
  });
}
