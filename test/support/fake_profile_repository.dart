import 'dart:io';
import 'package:codementor_mobile/features/settings/data/profile_repository.dart';
import 'package:dio/dio.dart';

/// Repository palsu untuk test Fase 5.
class FakeProfileRepository extends ProfileRepository {
  FakeProfileRepository() : super(dio: Dio());

  final List<Map<String, String?>> updates = [];
  final List<File> uploads = [];
  String updatedMessage = 'Profil diperbarui';
  String? uploadError;
  String? updateError;

  @override
  Future<ProfileMutationResult> updateProfile({
    required String name,
    required String email,
    String? nim,
    String? favoriteLanguage,
  }) async {
    updates.add({
      'name': name,
      'email': email,
      'nim': nim,
      'favoriteLanguage': favoriteLanguage,
    });
    final error = updateError;
    if (error != null) throw ProfileException(error);
    return ProfileMutationResult(message: updatedMessage);
  }

  @override
  Future<String> uploadAvatar(File file) async {
    uploads.add(file);
    final error = uploadError;
    if (error != null) throw ProfileException(error);
    return '/uploads/avatars/test.png';
  }
}
