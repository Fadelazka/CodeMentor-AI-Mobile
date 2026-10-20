import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/services/export_saver.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/chat_history_item.dart';

/// Error riwayat yang sudah diterjemahkan menjadi pesan siap tampil.
class HistoryException implements Exception {
  const HistoryException(this.message, {this.notFound = false});

  final String message;

  /// true bila server menjawab 404 (riwayat sudah dihapus / bukan milik user).
  final bool notFound;

  @override
  String toString() => message;
}

/// Sumber data layar Riwayat + Detail Riwayat.
///
/// Endpoint (lihat `src/app/api/history/route.ts`):
/// - `GET    /api/history?language=&limit=`  -> daftar riwayat milik user,
/// - `GET    /api/history?id=`               -> satu entri (404 bila bukan milik
///   user / sudah dihapus),
/// - `DELETE /api/history?id=`               -> hapus satu entri,
/// - `DELETE /api/history?all=1`             -> hapus semua entri,
/// - `GET    /api/history/export?format=`    -> berkas CSV/JSON.
///
/// `userId` TIDAK pernah dikirim: server selalu memakai ID dari cookie sesi
/// (`session.user.id`), jadi mobile tidak bisa membaca riwayat user lain.
class HistoryRepository {
  const HistoryRepository({required this.dio});

  final Dio dio;

  /// Daftar riwayat terbaru milik user yang sedang login.
  ///
  /// [language] `'all'` berarti tanpa filter (server memakai `where` bahasa
  /// hanya bila parameternya dikirim). [limit] default 50 seperti web; server
  /// membatasinya maksimal 200.
  Future<List<ChatHistoryItem>> fetchList({
    String language = 'all',
    int limit = 50,
  }) async {
    try {
      final response = await dio.get<dynamic>(
        ApiConstants.historyEndpoint,
        queryParameters: <String, dynamic>{
          if (language.isNotEmpty && language != 'all') 'language': language,
          'limit': limit,
        },
      );

      return [
        for (final row in _rowsOf(response.data))
          if (row is Map) ChatHistoryItem.fromJson(row),
      ];
    } on DioException catch (error) {
      throw HistoryException(_messageFor(error));
    }
  }

  /// Satu entri riwayat. Melempar [HistoryException] dengan
  /// `notFound: true` bila tidak ada (server menjawab 404).
  Future<ChatHistoryItem> fetchDetail(String id) async {
    try {
      final response = await dio.get<dynamic>(
        ApiConstants.historyEndpoint,
        queryParameters: <String, dynamic>{'id': id},
      );
      final data = response.data;
      final row = data is Map ? data['data'] : null;
      if (row is! Map) {
        throw const HistoryException(
          'Riwayat tidak ditemukan.',
          notFound: true,
        );
      }
      return ChatHistoryItem.fromJson(row);
    } on DioException catch (error) {
      throw _toException(error, notFoundWhen404: true);
    }
  }

  /// Menghapus satu entri.
  Future<void> deleteOne(String id) async {
    try {
      await dio.delete<dynamic>(
        ApiConstants.historyEndpoint,
        queryParameters: <String, dynamic>{'id': id},
      );
    } on DioException catch (error) {
      throw _toException(error, notFoundWhen404: true);
    }
  }

  /// Menghapus SELURUH riwayat milik user.
  Future<void> deleteAll() async {
    try {
      await dio.delete<dynamic>(
        ApiConstants.historyEndpoint,
        queryParameters: <String, dynamic>{'all': 1},
      );
    } on DioException catch (error) {
      throw HistoryException(_messageFor(error));
    }
  }

  /// Mengambil berkas ekspor riwayat dari server (CSV/JSON).
  ///
  /// Isi berkas diambil apa adanya sebagai teks (`ResponseType.plain`) supaya
  /// tidak diparse Dio; nama berkas mengikuti header `Content-Disposition`
  /// yang dikirim server (`codementor-riwayat-<waktu>.<format>`).
  Future<ExportFile> exportHistory({
    String format = 'csv',
    String language = 'all',
    String query = '',
  }) async {
    try {
      final response = await dio.get<dynamic>(
        ApiConstants.historyExportEndpoint,
        queryParameters: <String, dynamic>{
          'format': format,
          'language': language,
          'q': query,
        },
        options: Options(responseType: ResponseType.plain),
      );

      final content = response.data;
      if (content is! String) {
        throw const HistoryException('Format ekspor tidak dikenali.');
      }

      final isJson = format == 'json';
      return ExportFile(
        fileName: _fileNameFrom(
          response.headers,
          'codementor-riwayat-${_stamp()}.$format',
        ),
        content: content,
        mimeType: isJson
            ? 'application/json'
            : 'text/csv',
        description: 'Ekspor riwayat CodeMentor AI',
      );
    } on DioException catch (error) {
      throw HistoryException(_messageFor(error));
    }
  }

  /// Menerjemahkan error Dio menjadi [HistoryException].
  static HistoryException _toException(
    DioException error, {
    bool notFoundWhen404 = false,
  }) {
    final notFound =
        notFoundWhen404 && error.response?.statusCode == 404;
    return HistoryException(
      notFound ? 'Riwayat tidak ditemukan.' : _messageFor(error),
      notFound: notFound,
    );
  }

  /// Mengambil daftar baris dari respons `{ data: [...] }`.
  static List<dynamic> _rowsOf(Object? data) {
    if (data is Map) {
      final rows = data['data'];
      if (rows is List) return rows;
      return const <dynamic>[];
    }
    if (data is List) return data;
    throw const HistoryException('Format riwayat tidak dikenali.');
  }

  /// Nama berkas dari header `Content-Disposition` (fallback bila kosong).
  static String _fileNameFrom(Headers headers, String fallback) {
    final disposition = headers.value('content-disposition') ?? '';
    final match = RegExp(
      r'filename="?([^";]+)"?',
    ).firstMatch(disposition);
    final name = match?.group(1)?.trim();
    return (name == null || name.isEmpty) ? fallback : name;
  }

  /// Cap waktu untuk nama berkas cadangan
  /// (`2026-10-06-10-30-00`, sama seperti web).
  static String _stamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}'
        '-${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
  }

  static String _messageFor(DioException error) {
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
        if (code == 404) {
          return 'Riwayat tidak ditemukan.';
        }
        return 'Gagal memuat riwayat (kode $code).';
      case DioExceptionType.cancel:
        return 'Permintaan dibatalkan.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return 'Terjadi kesalahan saat memuat riwayat.';
    }
  }
}

/// Repository riwayat (satu instance untuk seluruh aplikasi).
final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(dio: ref.watch(apiDioProvider)),
);
