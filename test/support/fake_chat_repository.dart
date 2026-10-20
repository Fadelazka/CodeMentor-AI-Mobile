// Repository chat palsu untuk test (tanpa jaringan).
//
// Mencatat setiap permintaan agar test bisa memeriksa parameter yang dikirim ke
// server (sourceCode, language, saveHistory, aiDetailLevel, aiLanguage).
import 'dart:async';

import 'package:codementor_mobile/features/chat/data/chat_repository.dart';
import 'package:codementor_mobile/features/chat/domain/chat_answer.dart';
import 'package:dio/dio.dart';

/// Satu panggilan `POST /api/chat`.
class ChatRequest {
  const ChatRequest({
    required this.sourceCode,
    required this.language,
    required this.saveHistory,
    required this.aiDetailLevel,
    this.errorMessage,
    this.aiLanguage,
  });

  final String sourceCode;
  final String language;
  final String? errorMessage;
  final bool saveHistory;
  final String aiDetailLevel;
  final String? aiLanguage;
}

/// Satu panggilan `POST /api/chat/feedback`.
class FeedbackCall {
  const FeedbackCall({
    required this.chatHistoryId,
    required this.feedback,
    this.comment,
  });

  final String chatHistoryId;
  final ChatFeedback feedback;
  final String? comment;
}

class FakeChatRepository extends ChatRepository {
  FakeChatRepository() : super(dio: Dio());

  final List<ChatRequest> requests = <ChatRequest>[];
  final List<FeedbackCall> feedbackCalls = <FeedbackCall>[];

  /// Jawaban yang dikembalikan `ask` (ganti sebelum memanggil).
  ChatAnswer answer = const ChatAnswer(explanation: 'Penjelasan contoh.');

  /// Bila diisi, `ask` melempar error ini SEKALI lalu dikosongkan.
  Object? askError;

  /// Bila diisi, `sendFeedback` melempar error ini SEKALI lalu dikosongkan.
  Object? feedbackError;

  /// Bila diisi, `ask` menunggu completer ini (menguji keadaan "mengirim").
  Completer<void>? pending;

  @override
  Future<ChatAnswer> ask({
    required String sourceCode,
    required String language,
    String? errorMessage,
    bool saveHistory = true,
    String aiDetailLevel = 'medium',
    String? aiLanguage,
  }) async {
    requests.add(
      ChatRequest(
        sourceCode: sourceCode,
        language: language,
        errorMessage: errorMessage,
        saveHistory: saveHistory,
        aiDetailLevel: aiDetailLevel,
        aiLanguage: aiLanguage,
      ),
    );

    final gate = pending;
    if (gate != null) {
      await gate.future;
      pending = null;
    }

    final error = askError;
    if (error != null) {
      askError = null;
      throw error;
    }
    return answer;
  }

  @override
  Future<void> sendFeedback({
    required String chatHistoryId,
    required ChatFeedback feedback,
    String? comment,
  }) async {
    feedbackCalls.add(
      FeedbackCall(
        chatHistoryId: chatHistoryId,
        feedback: feedback,
        comment: comment,
      ),
    );

    final error = feedbackError;
    if (error != null) {
      feedbackError = null;
      throw error;
    }
  }
}
