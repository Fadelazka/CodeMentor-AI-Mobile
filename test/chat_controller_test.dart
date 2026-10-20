// Test `ChatController`: pengiriman kode, penanganan gagal, ulangi, dan umpan
// balik. Repository-nya palsu, jadi tidak ada jaringan sama sekali.
import 'dart:async';

import 'package:codementor_mobile/features/chat/data/chat_controller.dart';
import 'package:codementor_mobile/features/chat/data/chat_repository.dart';
import 'package:codementor_mobile/features/chat/domain/chat_answer.dart';
import 'package:codementor_mobile/features/settings/data/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_test_harness.dart';
import 'support/fake_chat_repository.dart';

/// Kontainer & repository palsu untuk seluruh test di berkas ini.
late FakeChatRepository repo;
late ProviderContainer container;

ChatController get controller =>
    container.read(chatControllerProvider.notifier);

ChatConversation get state => container.read(chatControllerProvider);

void main() {
  setUpAll(configureAppTests);
  setUp(configureAppTests);

  setUp(() {
    repo = FakeChatRepository();
    container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  test('awalnya percakapan kosong', () {
    expect(state.exchanges, isEmpty);
    expect(state.isEmpty, isTrue);
    expect(state.isSending, isFalse);
  });

  test('ask mengirim kode + preferensi lokal, lalu mengisi jawaban', () async {
    repo.answer = const ChatAnswer(
      explanation: 'Variabel x belum dibuat.',
      confidence: 90,
      chatHistoryId: 'h1',
    );

    await controller.ask(sourceCode: '  print(x)  ', language: 'python');

    expect(repo.requests, hasLength(1));
    final request = repo.requests.single;
    expect(request.sourceCode, 'print(x)'); // sudah di-trim
    expect(request.language, 'python');
    expect(request.errorMessage, isNull);
    // Nilai bawaan preferensi lokal (lihat AppSettings.fallback).
    expect(request.saveHistory, isTrue);
    expect(request.aiDetailLevel, 'medium');
    expect(request.aiLanguage, 'id');

    expect(state.exchanges, hasLength(1));
    final exchange = state.exchanges.single;
    expect(exchange.isPending, isFalse);
    expect(exchange.hasFailed, isFalse);
    expect(exchange.answer?.explanation, 'Variabel x belum dibuat.');
  });

  test('ask ikut mengirim pesan error yang diisi user', () async {
    await controller.ask(
      sourceCode: 'print(x)',
      language: 'python',
      errorMessage: '  NameError: name x is not defined  ',
    );

    expect(repo.requests.single.errorMessage, 'NameError: name x is not defined');
  });

  test('preferensi AI di pengaturan dipakai saat memanggil API', () async {
    final settings = container.read(appSettingsProvider.notifier);
    await settings.setAiDetailLevel('detailed');
    await settings.setAiLanguage('en');
    await settings.setAutoSaveHistory(false);

    await controller.ask(sourceCode: 'print(1)', language: 'python');

    final request = repo.requests.single;
    expect(request.aiDetailLevel, 'detailed');
    expect(request.aiLanguage, 'en');
    expect(request.saveHistory, isFalse);
  });

  test('ask dengan kode kosong tidak mengirim apa pun', () async {
    await controller.ask(sourceCode: '   ', language: 'python');

    expect(repo.requests, isEmpty);
    expect(state.exchanges, isEmpty);
  });

  test('ask gagal: pesan error disimpan di exchange', () async {
    repo.askError = const ChatException('Server terlalu lama merespons.');

    await controller.ask(sourceCode: 'print(x)', language: 'java');

    final exchange = state.exchanges.single;
    expect(exchange.hasFailed, isTrue);
    expect(exchange.error, 'Server terlalu lama merespons.');
    expect(exchange.answer, isNull);
  });

  test('retry memakai data yang sama dan mengisi jawaban', () async {
    repo.askError = const ChatException('Gagal memuat.');
    await controller.ask(
      sourceCode: 'print(x)',
      language: 'python',
      errorMessage: 'NameError',
    );
    final id = state.exchanges.single.id;
    expect(state.exchanges.single.hasFailed, isTrue);

    // Percobaan kedua berhasil.
    repo.answer = const ChatAnswer(explanation: 'Sudah diperbaiki.');
    await controller.retry(id);

    expect(state.exchanges, hasLength(1)); // tidak menambah bubble baru
    expect(repo.requests, hasLength(2));
    expect(repo.requests.last.sourceCode, 'print(x)');
    expect(repo.requests.last.errorMessage, 'NameError');

    final exchange = state.exchanges.single;
    expect(exchange.hasFailed, isFalse);
    expect(exchange.answer?.explanation, 'Sudah diperbaiki.');
  });

  test('selagi mengirim, permintaan kedua diabaikan', () async {
    final gate = Completer<void>();
    repo.pending = gate;

    final pertama = controller.ask(sourceCode: 'print(1)', language: 'python');
    expect(state.isSending, isTrue);

    await controller.ask(sourceCode: 'print(2)', language: 'python');
    expect(repo.requests, hasLength(1));

    gate.complete();
    await pertama;
    expect(state.isSending, isFalse);
    expect(state.exchanges, hasLength(1));
  });

  test('sendFeedback mengirim historyId + menandai exchange', () async {
    repo.answer = const ChatAnswer(explanation: 'ok', chatHistoryId: 'h9');
    await controller.ask(sourceCode: 'print(x)', language: 'python');
    final id = state.exchanges.single.id;

    await controller.sendFeedback(
      exchangeId: id,
      feedback: ChatFeedback.notHelpful,
      comment: 'Kurang jelas',
    );

    expect(repo.feedbackCalls.single.chatHistoryId, 'h9');
    expect(repo.feedbackCalls.single.feedback, ChatFeedback.notHelpful);
    expect(repo.feedbackCalls.single.comment, 'Kurang jelas');
    expect(state.exchanges.single.feedback, ChatFeedback.notHelpful);
  });

  test('sendFeedback tanpa historyId ditolak dengan pesan jelas', () async {
    repo.answer = const ChatAnswer(explanation: 'ok'); // tidak tersimpan
    await controller.ask(sourceCode: 'print(x)', language: 'python');
    final id = state.exchanges.single.id;

    await expectLater(
      controller.sendFeedback(exchangeId: id, feedback: ChatFeedback.helpful),
      throwsA(isA<ChatException>()),
    );
    expect(repo.feedbackCalls, isEmpty);
    expect(state.exchanges.single.feedback, isNull);
  });

  test('clearConversation mengosongkan layar', () async {
    await controller.ask(sourceCode: 'print(x)', language: 'python');
    expect(state.exchanges, hasLength(1));

    controller.clearConversation();
    expect(state.exchanges, isEmpty);
  });
}
