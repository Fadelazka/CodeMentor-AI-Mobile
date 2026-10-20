import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../auth/data/auth_repository.dart';
import 'admin_user.dart';

/// Error kelola User dengan pesan siap tampil.
class AdminUserException implements Exception {
  const AdminUserException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Hasil mutasi user (tambah/edit): user hasil server + pesan singkatnya.
class AdminUserMutationResult {
  const AdminUserMutationResult({required this.user, required this.message});

  final AdminUser user;
  final String message;
}

/// Sumber data tab **Kelola User** di layar Admin.
///
/// Endpoint `GET/POST /api/admin/users`, `PATCH/DELETE /api/admin/users/{id}`
/// — dijaga role ADMIN di server (403 "Forbidden" bila bukan admin).
class AdminUsersRepository {
  const AdminUsersRepository({required this.dio});

  final Dio dio;

  /// `GET /api/admin/users` -> daftar user (server juga mendukung `?q=`,
  /// tapi web memakai filter client-side; mobile mengikuti pola web).
  Future<List<AdminUser>> fetchUsers() async {
    try {
      final response = await dio.get<dynamic>(
        ApiConstants.adminUsersEndpoint,
      );

      final data = response.data;
      if (data is! Map || data['users'] is! List) {
        throw const AdminUserException('Format data tidak dikenali.');
      }

      return [
        for (final item in data['users'] as List)
          if (item is Map<String, dynamic>) AdminUser.fromJson(item),
      ];
    } on DioException catch (error) {
      throw AdminUserException(
        _serverMessage(error) ?? _messageFor(error, 'Gagal memuat daftar user.'),
      );
    }
  }

  /// `POST /api/admin/users` -> user baru (201).
  Future<AdminUserMutationResult> createUser(AdminUserDraft draft) async {
    try {
      final response = await dio.post<dynamic>(
        ApiConstants.adminUsersEndpoint,
        data: draft.toJson(isNew: true),
      );
      return _resultFrom(
        response.data,
        fallbackMessage: 'User berhasil ditambahkan.',
      );
    } on DioException catch (error) {
      throw AdminUserException(
        _serverMessage(error) ?? _messageFor(error, 'Gagal menyimpan user.'),
      );
    }
  }

  /// `PATCH /api/admin/users/{id}` -> user hasil edit.
  Future<AdminUserMutationResult> updateUser(
    String id,
    AdminUserDraft draft,
  ) async {
    try {
      final response = await dio.patch<dynamic>(
        '${ApiConstants.adminUsersEndpoint}/$id',
        data: draft.toJson(isNew: false),
      );
      return _resultFrom(
        response.data,
        fallbackMessage: 'User berhasil diperbarui.',
      );
    } on DioException catch (error) {
      throw AdminUserException(
        _serverMessage(error) ?? _messageFor(error, 'Gagal memperbarui user.'),
      );
    }
  }

  /// `DELETE /api/admin/users/{id}` -> pesan konfirmasi server.
  Future<String> deleteUser(String id) async {
    try {
      final response = await dio.delete<dynamic>(
        '${ApiConstants.adminUsersEndpoint}/$id',
      );

      final data = response.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      return 'User berhasil dihapus.';
    } on DioException catch (error) {
      throw AdminUserException(
        _serverMessage(error) ?? _messageFor(error, 'Gagal menghapus user.'),
      );
    }
  }

  static AdminUserMutationResult _resultFrom(
    Object? data, {
    required String fallbackMessage,
  }) {
    if (data is! Map || data['user'] is! Map) {
      throw const AdminUserException('Format data tidak dikenali.');
    }

    final message = data['message'];
    return AdminUserMutationResult(
      user: AdminUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
      message: (message is String && message.trim().isNotEmpty)
          ? message.trim()
          : fallbackMessage,
    );
  }

  /// Pesan `{ "error": "..." }` dari server.
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

/// Repository User Management (satu instance untuk seluruh aplikasi).
final adminUsersRepositoryProvider = Provider<AdminUsersRepository>(
  (ref) => AdminUsersRepository(dio: ref.watch(apiDioProvider)),
);
