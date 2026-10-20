import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../auth/data/auth_repository.dart';

/// Error saat mengelola profil.
class ProfileException implements Exception {
  const ProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Hasil update profil: user (tanpa field lengkap di sini, cukup pesan).
class ProfileMutationResult {
  const ProfileMutationResult({required this.message});

  final String message;
}

/// Repository untuk edit profil & upload avatar (padanan web).
class ProfileRepository {
  const ProfileRepository({required this.dio});

  final Dio dio;

  /// PATCH /api/user/profile -> pesan sukses.
  Future<ProfileMutationResult> updateProfile({
    required String name,
    required String email,
    String? nim,
    String? favoriteLanguage,
  }) async {
    try {
      final response = await dio.patch<dynamic>(
        ApiConstants.userProfileEndpoint,
        data: <String, dynamic>{
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          if (nim != null && nim.trim().isNotEmpty) 'nim': nim.trim(),
          if (favoriteLanguage != null && favoriteLanguage.trim().isNotEmpty)
            'favoriteLanguage': favoriteLanguage.trim(),
        },
      );
      final data = response.data;
      final message = (data is Map && data['message'] is String)
          ? data['message'] as String
          : (data is Map && data['user'] != null)
              ? 'Profil diperbarui'
              : 'Profil diperbarui';
      return ProfileMutationResult(message: message);
    } on DioException catch (error) {
      throw ProfileException(_serverMessage(error) ?? _messageFor(error, 'Gagal update profil'));
    }
  }

  /// POST /api/user/avatar -> kembalikan imageUrl.
  Future<String> uploadAvatar(File file) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(file.path),
      });
      final response = await dio.post<dynamic>(
        ApiConstants.userAvatarEndpoint,
        data: formData,
      );
      final data = response.data;
      if (data is Map && data['imageUrl'] is String) {
        return data['imageUrl'] as String;
      }
      return '';
    } on DioException catch (error) {
      throw ProfileException(_serverMessage(error) ?? _messageFor(error, 'Gagal upload foto'));
    }
  }

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

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(dio: ref.watch(apiDioProvider)),
);
