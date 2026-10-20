// Repository akun PALSU untuk test UI layar Pengaturan.
//
// Meniru `AccountRepository` asli tanpa jaringan:
//   - `changePassword` mencatat pasangan password (lama|baru),
//   - `exportData` mengembalikan berkas JSON palsu.
import 'package:codementor_mobile/core/services/export_saver.dart';
import 'package:codementor_mobile/features/settings/data/account_repository.dart';
import 'package:dio/dio.dart';

class FakeAccountRepository extends AccountRepository {
  FakeAccountRepository() : super(dio: Dio());

  /// Pasangan `password lama|password baru` yang dikirim.
  final List<String> passwordChanges = <String>[];

  /// Isi berkas dari `exportData`.
  String exportContent = '{"exportedAt":"2026-10-06T10:30:00.000Z"}';

  /// Bila tidak null, aksi yang bersangkutan gagal.
  AccountException? changePasswordError;
  AccountException? exportError;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final error = changePasswordError;
    if (error != null) throw error;
    passwordChanges.add('$currentPassword|$newPassword');
  }

  @override
  Future<ExportFile> exportData() async {
    final error = exportError;
    if (error != null) throw error;
    return ExportFile(
      fileName: 'codementor-data-saya-2026-10-06.json',
      content: exportContent,
      mimeType: 'application/json',
      description: 'Data akun CodeMentor AI',
    );
  }
}
