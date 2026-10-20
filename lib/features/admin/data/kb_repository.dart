import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../auth/data/auth_repository.dart';
import 'kb_entry.dart';

/// Error kelola Knowledge Base dengan pesan siap tampil.
class KbException implements Exception {
  const KbException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Hasil satu mutasi (tambah/edit): entri hasil server + pesan singkatnya
/// (meniru `json.message` yang ditampilkan `toast.success` di web).
class KbMutationResult {
  const KbMutationResult({required this.entry, required this.message});

  final KbEntry entry;
  final String message;
}

/// Sumber data tab **Knowledge Base** di layar Admin.
///
/// Endpoint `GET/POST/PUT/DELETE /api/admin/knowledge-base` — SEMUA method
/// dijaga guard role ADMIN di server
/// (lihat `src/app/api/admin/knowledge-base/route.ts`), jadi bila sesi bukan
/// admin server menjawab 403 dan pesannya diteruskan apa adanya ke UI.
class KnowledgeBaseRepository {
  const KnowledgeBaseRepository({required this.dio});

  final Dio dio;

  /// `GET /api/admin/knowledge-base` -> daftar seluruh rekaman
  /// (urut `updatedAt` terbaru, sama seperti fetchRows di web).
  Future<List<KbEntry>> fetchEntries() async {
    try {
      final response = await dio.get<dynamic>(
        ApiConstants.adminKbEndpoint,
      );

      final data = response.data;
      if (data is! Map || data['data'] is! List) {
        throw const KbException('Format data tidak dikenali.');
      }

      return [
        for (final item in data['data'] as List)
          if (item is Map<String, dynamic>) KbEntry.fromJson(item),
      ];
    } on DioException catch (error) {
      throw KbException(
        _serverMessage(error) ??
            _messageFor(error, 'Gagal memuat rekaman knowledge base.'),
      );
    }
  }

  /// `POST /api/admin/knowledge-base` -> rekaman baru (201).
  Future<KbMutationResult> createEntry(KbEntryDraft draft) async {
    try {
      final response = await dio.post<dynamic>(
        ApiConstants.adminKbEndpoint,
        data: draft.toJson(),
      );
      return _resultFrom(
        response.data,
        fallbackMessage: 'Rekaman knowledge base ditambahkan.',
      );
    } on DioException catch (error) {
      throw KbException(
        _serverMessage(error) ?? _messageFor(error, 'Gagal menyimpan rekaman.'),
      );
    }
  }

  /// `PUT /api/admin/knowledge-base?id=` -> rekaman hasil edit.
  Future<KbMutationResult> updateEntry(
    String id,
    KbEntryDraft draft,
  ) async {
    try {
      final response = await dio.put<dynamic>(
        ApiConstants.adminKbEndpoint,
        queryParameters: <String, dynamic>{'id': id},
        data: draft.toJson(),
      );
      return _resultFrom(
        response.data,
        fallbackMessage: 'Rekaman diperbarui.',
      );
    } on DioException catch (error) {
      throw KbException(
        _serverMessage(error) ??
            _messageFor(error, 'Gagal memperbarui rekaman.'),
      );
    }
  }

  /// `PUT ?id=` dengan hanya `{ isActive }` — meniru `toggleActive` di
  /// `src/app/(app)/admin/page.tsx:170-176` (tombol status Aktif/Nonaktif).
  Future<KbMutationResult> toggleActive({
    required String id,
    required bool isActive,
  }) async {
    try {
      final response = await dio.put<dynamic>(
        ApiConstants.adminKbEndpoint,
        queryParameters: <String, dynamic>{'id': id},
        data: <String, dynamic>{'isActive': isActive},
      );
      return _resultFrom(
        response.data,
        fallbackMessage: 'Status rekaman diperbarui.',
      );
    } on DioException catch (error) {
      throw KbException(
        _serverMessage(error) ??
            _messageFor(error, 'Gagal memperbarui status.'),
      );
    }
  }

  /// `DELETE /api/admin/knowledge-base?id=` -> pesan konfirmasi server.
  Future<String> deleteEntry(String id) async {
    try {
      final response = await dio.delete<dynamic>(
        ApiConstants.adminKbEndpoint,
        queryParameters: <String, dynamic>{'id': id},
      );

      final data = response.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      return 'Rekaman dihapus.';
    } on DioException catch (error) {
      throw KbException(
        _serverMessage(error) ?? _messageFor(error, 'Gagal menghapus rekaman.'),
      );
    }
  }

  /// Membaca `{ data, message }` dari respons POST/PUT.
  static KbMutationResult _resultFrom(
    Object? data, {
    required String fallbackMessage,
  }) {
    if (data is! Map || data['data'] is! Map) {
      throw const KbException('Format data tidak dikenali.');
    }

    final message = data['message'];
    return KbMutationResult(
      entry: KbEntry.fromJson(Map<String, dynamic>.from(data['data'] as Map)),
      message: (message is String && message.trim().isNotEmpty)
          ? message.trim()
          : fallbackMessage,
    );
  }

  /// Pesan `{ "error": "..." }` dari server, bila ada — termasuk 403
  /// "Forbidden: admin only" yang dikirim guard backend.
  static String? _serverMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['error'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
    }
    return null;
  }

  static String _messageFor(DioException error, String fallback) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return 'Server terlalu lama merespons. Coba lagi.';
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server. Periksa koneksi internetmu.';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == 401 || code == 403) {
          return 'Sesi kamu tidak lagi valid. Silakan masuk ulang.';
        }
        return '$fallback (kode $code)';
      case DioExceptionType.cancel:
        return 'Permintaan dibatalkan.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return fallback;
    }
  }
}

/// Repository Knowledge Base (satu instance untuk seluruh aplikasi).
final kbRepositoryProvider = Provider<KnowledgeBaseRepository>(
  (ref) => KnowledgeBaseRepository(dio: ref.watch(apiDioProvider)),
);
