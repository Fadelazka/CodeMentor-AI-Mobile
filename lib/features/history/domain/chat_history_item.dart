import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/format.dart';

/// Satu entri riwayat konsultasi — padanan tipe `HistoryItem` di web
/// (`src/app/(app)/riwayat/page.tsx:24-33`).
///
/// Bentuk data dari server (`GET /api/history`, lihat
/// `src/app/api/history/route.ts`) mengikuti kolom `ChatHistory` di Prisma:
/// ```json
/// { "id": "clx...", "language": "python", "errorCode": "NameError",
///   "errorMessage": null, "sourceCode": "print(x)", "aiResponse": "## ...",
///   "confidence": 88, "createdAt": "2026-10-06T10:30:00.000Z" }
/// ```
@immutable
class ChatHistoryItem {
  const ChatHistoryItem({
    required this.id,
    required this.language,
    required this.sourceCode,
    required this.aiResponse,
    this.errorCode,
    this.errorMessage,
    this.confidence,
    this.createdAt,
  });

  /// ID entri (`ChatHistory.id`).
  final String id;

  /// Kode bahasa wire (`python`, `javascript`, `java`, `cpp`, `php`).
  final String language;

  /// Error code yang dideteksi AI (mis. `NameError`) — boleh null.
  final String? errorCode;

  /// Pesan error yang diketik user saat bertanya — boleh null.
  final String? errorMessage;

  /// Kode sumber yang dikirim user.
  final String sourceCode;

  /// Jawaban AI (Markdown).
  final String aiResponse;

  /// Keyakinan AI (0-100) — boleh null untuk data lama.
  final int? confidence;

  /// Waktu konsultasi.
  final DateTime? createdAt;

  /// Label bahasa untuk UI (mis. `JavaScript`).
  String get languageLabel =>
      ApiConstants.languageLabels[language] ?? language.toUpperCase();

  /// Tanggal ala web: `06 Okt 2026, 10.30`.
  String get formattedDate => formatDateTimeId(createdAt);

  /// Error code untuk UI — web menampilkan `N/A` bila kosong
  /// (`src/app/(app)/riwayat/page.tsx:196`).
  String get errorCodeLabel {
    final code = errorCode?.trim() ?? '';
    return code.isEmpty ? 'N/A' : code;
  }

  /// Cuplikan jawaban AI untuk kartu daftar (satu baris rapi, maks 200 huruf).
  String get responsePreview {
    final plain = aiResponse.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (plain.length <= 200) return plain;
    return '${plain.substring(0, 200)}...';
  }

  /// true bila entri cocok dengan kata kunci pencarian.
  ///
  /// Web mencari di `errorCode` dan `sourceCode` saja
  /// (`src/app/(app)/riwayat/page.tsx:100-106`), bukan di jawaban AI.
  bool matches(String query) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) return true;
    return (errorCode ?? '').toLowerCase().contains(keyword) ||
        sourceCode.toLowerCase().contains(keyword);
  }

  /// Membaca satu baris JSON dari server; kolom yang hilang jadi null/''.
  factory ChatHistoryItem.fromJson(Map<dynamic, dynamic> json) =>
      ChatHistoryItem(
        id: _asText(json['id']) ?? '',
        language: _asText(json['language']) ?? 'python',
        errorCode: _asText(json['errorCode']),
        errorMessage: _asText(json['errorMessage']),
        sourceCode: _asText(json['sourceCode']) ?? '',
        aiResponse: _asText(json['aiResponse']) ?? '',
        confidence: _asInt(json['confidence']),
        createdAt: _asDate(json['createdAt']),
      );
}

/// Teks yang sudah dirapikan; null bila kosong/bukan teks.
String? _asText(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

/// Angka bulat; menerima int, double, maupun teks angka dari JSON.
int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Tanggal ISO 8601 dari server; null bila tidak bisa diparse.
DateTime? _asDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toLocal();
}
