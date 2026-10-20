import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/services/export_saver.dart';
import '../../auth/data/auth_repository.dart';

/// Error akun (ubah kata sandi / unduh data) dengan pesan siap tampil.
class AccountException implements Exception {
  const AccountException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sumber data bagian "Akun" di layar Pengaturan.
///
/// Endpoint:
/// - `POST /api/auth/change-password` (src/app/api/auth/change-password/route.ts)
/// - `GET  /api/user/export`          (src/app/api/user/export/route.ts)
class AccountRepository {
  const AccountRepository({required this.dio});

  final Dio dio;

  /// Mengubah kata sandi user yang sedang login.
  ///
  /// Server memvalidasi ulang (minimal 6 huruf, password lama harus benar),
  /// dan pesan errornya diteruskan apa adanya ke user (mis. "Password lama
  /// salah"), sama seperti web.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await dio.post<dynamic>(
        ApiConstants.changePasswordEndpoint,
        data: <String, dynamic>{
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (error) {
      throw AccountException(
        _serverMessage(error) ?? _messageFor(error, 'Gagal mengubah kata sandi.'),
      );
    }
  }

  /// Mengambil seluruh data milik user sebagai berkas JSON.
  Future<ExportFile> exportData() async {
    try {
      final response = await dio.get<dynamic>(
        ApiConstants.userExportEndpoint,
        options: Options(responseType: ResponseType.plain),
      );

      final content = response.data;
      if (content is! String) {
        throw const AccountException('Format data tidak dikenali.');
      }

      return ExportFile(
        fileName: _fileNameFrom(
          response.headers,
          'codementor-data-saya-${_stamp()}.json',
        ),
        content: content,
        mimeType: 'application/json',
        description: 'Data akun CodeMentor AI',
      );
    } on DioException catch (error) {
      throw AccountException(
        _serverMessage(error) ?? _messageFor(error, 'Gagal mengunduh data.'),
      );
    }
  }

  /// Pesan `{ "error": "..." }` dari server, bila ada.
  static String? _serverMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['error'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
    }
    return null;
  }

  static String _fileNameFrom(Headers headers, String fallback) {
    final disposition = headers.value('content-disposition') ?? '';
    final match = RegExp(
      r'filename="?([^";]+)"?',
    ).firstMatch(disposition);
    final name = match?.group(1)?.trim();
    return (name == null || name.isEmpty) ? fallback : name;
  }

  static String _stamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}'
        '-${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
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
        if (code == 401) {
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

/// Repository akun (satu instance untuk seluruh aplikasi).
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(dio: ref.watch(apiDioProvider)),
);
