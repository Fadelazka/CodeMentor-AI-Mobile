import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/app_settings.dart';
import '../domain/chat_answer.dart';
import 'chat_repository.dart';

/// Isi layar Chat: daftar pertanyaan + jawabannya.
@immutable
class ChatConversation {
  const ChatConversation({this.exchanges = const <ChatExchange>[]});

  final List<ChatExchange> exchanges;

  bool get isEmpty => exchanges.isEmpty;

  bool get isNotEmpty => exchanges.isNotEmpty;

  /// true bila ada permintaan yang sedang berjalan.
  ///
  /// Hanya boleh satu permintaan pada satu waktu (tombol kirim dimatikan bila
  /// true), jadi cukup melihat entri terakhir.
  bool get isSending => exchanges.isNotEmpty && exchanges.last.isPending;

  ChatConversation copyWith({List<ChatExchange>? exchanges}) =>
      ChatConversation(exchanges: exchanges ?? this.exchanges);
}

/// State + aksi layar Chat.
///
/// Sengaja memakai `Notifier` biasa (bukan `AsyncNotifier`): status asinkron di
/// sini melekat pada TIAP pesan (ada yang masih dikirim, gagal, atau sudah
/// dijawab), sehingga lebih tepat disimpan di dalam `ChatExchange` daripada
/// membungkus seluruh percakapan dalam satu `AsyncValue`.
class ChatController extends Notifier<ChatConversation> {
  var _sequence = 0;

  @override
  ChatConversation build() => const ChatConversation();

  /// Kirim kode (+ pesan error opsional) dan tambahkan jawaban ke daftar.
  Future<void> ask({
    required String sourceCode,
    required String language,
    String? errorMessage,
  }) async {
    if (state.isSending) return;
    final code = sourceCode.trim();
    if (code.isEmpty) return;

    final pesanError = (errorMessage ?? '').trim();
    final exchange = ChatExchange(
      id: 'x${++_sequence}',
      sourceCode: code,
      language: language,
      errorMessage: pesanError.isEmpty ? null : pesanError,
    );
    state = state.copyWith(exchanges: [...state.exchanges, exchange]);
    await _request(exchange.id);
  }

  /// Ulangi permintaan yang gagal (memakai isi yang sama).
  Future<void> retry(String id) async {
    if (state.isSending) return;
    if (_find(id) == null) return;
    _update(id, (item) => item.copyWith(clearError: true));
    await _request(id);
  }

  /// Kirim umpan balik untuk satu jawaban yang sudah tersimpan.
  ///
  /// Melempar [ChatException] bila jawaban belum tersimpan (belum login /
  /// auto-save dimatikan) supaya UI bisa menampilkan alasannya.
  Future<void> sendFeedback({
    required String exchangeId,
    required ChatFeedback feedback,
    String? comment,
  }) async {
    final exchange = _find(exchangeId);
    final historyId = exchange?.answer?.chatHistoryId;
    if (historyId == null || historyId.isEmpty) {
      throw const ChatException(
        'Jawaban ini tidak tersimpan di riwayat, jadi umpan balik belum '
        'bisa dikirim.',
      );
    }

    await ref
        .read(chatRepositoryProvider)
        .sendFeedback(
          chatHistoryId: historyId,
          feedback: feedback,
          comment: comment,
        );
    _update(exchangeId, (item) => item.copyWith(feedback: feedback));
  }

  /// Menghapus percakapan.
  void clearConversation() => state = const ChatConversation();

  Future<void> _request(String id) async {
    final exchange = _find(id);
    if (exchange == null) return;

    final settings = ref.read(appSettingsProvider);
    try {
      final answer = await ref
          .read(chatRepositoryProvider)
          .ask(
            sourceCode: exchange.sourceCode,
            language: exchange.language,
            errorMessage: exchange.errorMessage,
            saveHistory: settings.autoSaveHistory,
            aiDetailLevel: settings.aiDetailLevel,
            aiLanguage: settings.aiLanguage,
          );
      _update(id, (item) => item.copyWith(answer: answer, clearError: true));
    } on ChatException catch (error) {
      _update(id, (item) => item.copyWith(error: error.message));
    } catch (error) {
      _update(
        id,
        (item) => item.copyWith(error: 'Terjadi kesalahan tak terduga: $error'),
      );
    }
  }

  ChatExchange? _find(String id) {
    for (final item in state.exchanges) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _update(String id, ChatExchange Function(ChatExchange) transform) {
    state = state.copyWith(
      exchanges: [
        for (final item in state.exchanges)
          if (item.id == id) transform(item) else item,
      ],
    );
  }
}

/// Percakapan pada layar Chat.
///
/// `build` mengembalikan percakapan kosong; kirim pesan lewat
/// `chatControllerProvider.notifier`.
final chatControllerProvider =
    NotifierProvider<ChatController, ChatConversation>(ChatController.new);
