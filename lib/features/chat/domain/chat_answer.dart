import 'package:flutter/foundation.dart';

/// Jawaban AI dari `POST /api/chat`.
///
/// Bentuk respons (lihat `src/app/api/chat/route.ts:161-169`):
/// ```json
/// { "explanation": "...", "confidence": 88, "mock": false,
///   "ragMatches": 2, "responseTimeMs": 1200,
///   "detectedErrorCode": "NameError", "chatHistoryId": "clx..." }
/// ```
/// `chatHistoryId` bernilai null bila riwayat tidak disimpan (belum login atau
/// `saveHistory: false`).
@immutable
class ChatAnswer {
  const ChatAnswer({
    required this.explanation,
    this.confidence,
    this.mock = false,
    this.ragMatches = 0,
    this.responseTimeMs,
    this.detectedErrorCode,
    this.chatHistoryId,
  });

  /// Penjelasan AI (Markdown) — inti jawaban.
  final String explanation;

  /// Keyakinan AI (0-100) bila dikirim server.
  final int? confidence;

  /// true bila server memakai jawaban contoh (mis. kunci AI belum diisi).
  final bool mock;

  /// Jumlah entri knowledge base yang ikut dijadikan konteks (RAG).
  final int ragMatches;

  /// Waktu proses di server (ms).
  final int? responseTimeMs;

  /// Kode error yang dikenali server (mis. `NameError`).
  final String? detectedErrorCode;

  /// ID entri riwayat; null bila tidak disimpan.
  final String? chatHistoryId;

  /// true bila jawaban ini tersimpan di riwayat sehingga bisa diberi feedback.
  bool get isSaved => (chatHistoryId ?? '').isNotEmpty;

  factory ChatAnswer.fromJson(Map<dynamic, dynamic> json) => ChatAnswer(
    explanation: _string(json['explanation']) ?? '',
    confidence: _int(json['confidence']),
    mock: json['mock'] == true,
    ragMatches: _int(json['ragMatches']) ?? 0,
    responseTimeMs: _int(json['responseTimeMs']),
    detectedErrorCode: _string(json['detectedErrorCode']),
    chatHistoryId: _string(json['chatHistoryId']),
  );
}

/// Umpan balik untuk satu jawaban AI (nilai yang dikirim ke server).
enum ChatFeedback {
  helpful('helpful', 'Membantu'),
  notHelpful('not_helpful', 'Kurang tepat');

  const ChatFeedback(this.wireName, this.label);

  /// Nilai yang dipahami server (`FEEDBACK_MAP`).
  final String wireName;

  /// Label bahasa Indonesia untuk UI.
  final String label;
}

/// Satu pasangan "pertanyaan user + jawaban AI" di layar Chat.
///
/// Chat di web/API bersifat SATU TANYA-SATU JAWAB per kirim (tidak ada
/// parameter riwayat percakapan), jadi layar chat menyimpan daftar
/// [ChatExchange] — persis seperti daftar bubble di
/// `src/components/chat/chat-interface.tsx`.
@immutable
class ChatExchange {
  const ChatExchange({
    required this.id,
    required this.sourceCode,
    required this.language,
    this.errorMessage,
    this.answer,
    this.error,
    this.feedback,
  });

  /// ID lokal (hanya untuk UI, tidak dikirim ke server).
  final String id;

  /// Kode yang dikirim user.
  final String sourceCode;

  /// Bahasa (python/javascript/java/cpp/php).
  final String language;

  /// Pesan error yang ditempel user (opsional).
  final String? errorMessage;

  /// Jawaban AI; null selama masih dikirim atau bila gagal.
  final ChatAnswer? answer;

  /// Pesan kegagalan yang siap ditampilkan; null bila belum selesai/gagal.
  final String? error;

  /// Umpan balik yang sudah dipilih user.
  final ChatFeedback? feedback;

  /// Masih menunggu jawaban.
  bool get isPending => answer == null && error == null;

  /// Gagal mendapat jawaban.
  bool get hasFailed => error != null;

  ChatExchange copyWith({
    ChatAnswer? answer,
    String? error,
    ChatFeedback? feedback,
    bool clearError = false,
  }) => ChatExchange(
    id: id,
    sourceCode: sourceCode,
    language: language,
    errorMessage: errorMessage,
    answer: answer ?? this.answer,
    error: clearError ? null : (error ?? this.error),
    feedback: feedback ?? this.feedback,
  );
}

// --- Pembaca JSON yang toleran (nilai bisa datang sebagai String) -----------

String? _string(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return value?.toString();
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
