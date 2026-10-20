import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/chat_answer.dart';

/// Error chat yang sudah diterjemahkan menjadi pesan siap tampil.
class ChatException implements Exception {
  const ChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sumber data layar Chat.
///
/// Endpoint (lihat `src/app/api/chat/route.ts`):
/// - `POST /api/chat`            -> penjelasan AI,
/// - `POST /api/chat/feedback`   -> umpan balik jawaban (wajib login).
///
/// `userId` TIDAK dikirim: server selalu memakai ID dari cookie sesi
/// (`session.user.id`).
class ChatRepository {
  const ChatRepository({required this.dio});

  final Dio dio;

  /// Meminta penjelasan kode/error.
  ///
  /// [aiDetailLevel] dan [aiLanguage] berasal dari preferensi lokal
  /// (`appSettingsProvider`); server tetap memprioritaskan hasil kuis user.
  Future<ChatAnswer> ask({
    required String sourceCode,
    required String language,
    String? errorMessage,
    bool saveHistory = true,
    String aiDetailLevel = 'medium',
    String? aiLanguage,
  }) async {
    try {
      final response = await dio.post<dynamic>(
        ApiConstants.chatEndpoint,
        data: <String, dynamic>{
          'sourceCode': sourceCode,
          'language': language,
          if ((errorMessage ?? '').trim().isNotEmpty)
            'errorMessage': errorMessage!.trim(),
          'saveHistory': saveHistory,
          'aiDetailLevel': aiDetailLevel,
          if ((aiLanguage ?? '').trim().isNotEmpty) 'aiLanguage': aiLanguage,
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw const ChatException('Respons server tidak dikenali.');
      }
      return ChatAnswer.fromJson(data);
    } on DioException catch (error) {
      throw ChatException(_messageFor(error));
    }
  }

  /// Mengirim umpan balik untuk satu jawaban ([ChatAnswer.chatHistoryId]).
  Future<void> sendFeedback({
    required String chatHistoryId,
    required ChatFeedback feedback,
    String? comment,
  }) async {
    try {
      await dio.post<dynamic>(
        ApiConstants.chatFeedbackEndpoint,
        data: <String, dynamic>{
          'chatHistoryId': chatHistoryId,
          'feedback': feedback.wireName,
          if ((comment ?? '').trim().isNotEmpty) 'comment': comment!.trim(),
        },
      );
    } on DioException catch (error) {
      throw ChatException(_messageFor(error, ubahUmpanBalik: true));
    }
  }

  static String _messageFor(
    DioException error, {
    bool ubahUmpanBalik = false,
  }) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return 'Server terlalu lama merespons. Coba lagi.';
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server. Periksa koneksi internetmu.';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == 401 || status == 403) {
          return 'Sesi kamu tidak lagi valid. Silakan masuk ulang.';
        }
        if (status == 400) {
          // Server mengirim { error: "..." } untuk body yang tidak valid.
          final body = error.response?.data;
          if (body is Map && body['error'] is String) {
            return body['error'] as String;
          }
          return 'Permintaan tidak valid.';
        }
        if (status == 404) {
          return 'Data tidak ditemukan di server.';
        }
        return ubahUmpanBalik
            ? 'Gagal mengirim umpan balik (kode $status).'
            : 'Gagal meminta penjelasan (kode $status).';
      case DioExceptionType.cancel:
        return 'Permintaan dibatalkan.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return 'Terjadi kesalahan. Coba lagi.';
    }
  }
}

/// Repository chat (satu instance untuk seluruh aplikasi).
final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(dio: ref.watch(apiDioProvider)),
);
