// Test UI layar Detail Riwayat
// (`lib/features/history/presentation/history_detail_screen.dart`).
//
// Yang dijaga: pemisahan blok "Kode yang Sudah Dibenarkan", panel khusus saat
// AI menyatakan kode sudah benar, keadaan 404 vs gagal memuat, dan tombol hapus
// yang kembali ke daftar.
import 'package:codementor_mobile/core/router/app_routes.dart';
import 'package:codementor_mobile/features/history/data/history_repository.dart';
import 'package:codementor_mobile/features/history/domain/chat_history_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_test_harness.dart';
import 'support/fake_history_repository.dart';

/// Layar tinggi supaya seluruh isi ListView terbangun.
void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Membuka `/riwayat/<id>` dengan repository palsu.
Future<void> _openDetail(
  WidgetTester tester,
  FakeHistoryRepository repository, {
  String id = 'h1',
}) async {
  _useTallView(tester);
  await pumpApp(
    tester,
    session: studentSession(),
    historyRepository: repository,
  );
  routerOf(tester).go('${AppRoutes.history}/$id');
  await pumpSteps(tester, steps: 8);
}

/// Isi semua blok kode (SelectableText) yang tampil di layar.
List<String?> _codeTexts(WidgetTester tester) => tester
    .widgetList<SelectableText>(find.byType(SelectableText))
    .map((widget) => widget.data)
    .toList();

void main() {
  setUpAll(configureAppTests);
  setUp(configureAppTests);

  testWidgets('detail: kode sumber, pesan error, dan kode perbaikan terpisah', (
    tester,
  ) async {
    final repository = FakeHistoryRepository(
      items: [fakeHistoryItem(id: 'h1')],
    );

    await _openDetail(tester, repository);

    expect(find.text('Detail Analisis'), findsOneWidget);
    expect(find.text('Analisis Python • 06 Okt 2026, 10.30'), findsOneWidget);
    expect(find.text('PESAN ERROR'), findsOneWidget);
    expect(find.text("name 'x' is not defined"), findsOneWidget);

    // Blok kode: sumber + kode perbaikan hasil `parseAiResponse`.
    final codes = _codeTexts(tester);
    expect(codes, contains('print(x)'));
    expect(codes, contains('x = 1\nprint(x)'));
    expect(find.text('KODE YANG SUDAH DIBENARKAN'), findsOneWidget);

    // Bagian "Kode yang Sudah Dibenarkan" tidak ikut di penjelasan.
    expect(find.textContaining('## Kode yang Sudah Dibenarkan'), findsNothing);
    expect(find.textContaining('Variabel'), findsWidgets);
  });

  testWidgets('detail: panel khusus bila AI menyatakan kode sudah benar', (
    tester,
  ) async {
    final repository = FakeHistoryRepository(
      items: [
        fakeHistoryItem(
          id: 'h1',
          aiResponse: 'Kode kamu SUDAH BENAR, tidak ada error.',
        ),
      ],
    );

    await _openDetail(tester, repository);

    expect(find.text('✓ Kode ini sudah benar 100%'), findsOneWidget);
    expect(
      find.textContaining('tidak ada error'),
      findsWidgets,
    );
  });

  testWidgets('detail: tombol Kembali menuju daftar riwayat', (tester) async {
    final repository = FakeHistoryRepository(
      items: [fakeHistoryItem(id: 'h1')],
    );

    await _openDetail(tester, repository);

    await tester.tap(find.text('Kembali'));
    await pumpSteps(tester, steps: 8);

    expect(routerOf(tester).state.uri.path, AppRoutes.history);
    expect(find.text('Riwayat Analisis'), findsOneWidget);
  });

  testWidgets('detail tidak ditemukan: pesan + tombol kembali ke daftar', (
    tester,
  ) async {
    // Repository kosong: `fetchDetail` melempar notFound.
    final repository = FakeHistoryRepository();

    await _openDetail(tester, repository, id: 'tidak-ada');

    expect(find.text('Riwayat Tidak Ditemukan'), findsOneWidget);
    expect(
      find.text('Riwayat yang Anda cari tidak ditemukan atau telah dihapus.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Kembali ke Riwayat'));
    await pumpSteps(tester, steps: 8);
    expect(routerOf(tester).state.uri.path, AppRoutes.history);
  });

  testWidgets('detail gagal memuat (bukan 404): panel error + Coba lagi', (
    tester,
  ) async {
    final repository = FakeHistoryRepository(
      items: [fakeHistoryItem(id: 'h1')],
    )..detailError = const HistoryException('Server terlalu lama merespons.');

    await _openDetail(tester, repository);

    expect(find.text('Gagal Memuat Riwayat'), findsOneWidget);
    expect(find.text('Server terlalu lama merespons.'), findsOneWidget);

    repository.detailError = null;
    await tester.tap(find.text('Coba lagi'));
    await pumpSteps(tester, steps: 8);

    expect(find.text('Gagal Memuat Riwayat'), findsNothing);
    expect(find.text('Detail Analisis'), findsOneWidget);
  });

  testWidgets('detail: hapus dengan konfirmasi lalu kembali ke daftar', (
    tester,
  ) async {
    final repository = FakeHistoryRepository(
      items: [fakeHistoryItem(id: 'h1')],
    );

    await _openDetail(tester, repository);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus riwayat ini?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, <String>['h1']);
    expect(find.text('Riwayat dihapus.'), findsOneWidget);
    expect(routerOf(tester).state.uri.path, AppRoutes.history);
  });

  testWidgets('detail: entri tanpa jawaban AI tetap tampil aman', (
    tester,
  ) async {
    final repository = FakeHistoryRepository(
      items: [
        ChatHistoryItem(
          id: 'h1',
          language: 'php',
          errorCode: null,
          sourceCode: 'echo 1;',
          aiResponse: '',
        ),
      ],
    );

    await _openDetail(tester, repository);

    expect(find.text('Detail Analisis'), findsOneWidget);
    expect(find.text('PESAN ERROR'), findsNothing);
    expect(_codeTexts(tester), contains('echo 1;'));
  });
}
