import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Satu berkas hasil ekspor yang siap diberikan ke user.
///
/// Di web ekspor diunduh lewat `<a download>`; di mobile "unduhan" itu tidak
/// ada, jadi padanannya adalah berkas yang dibagikan lewat share sheet
/// (user bisa menyimpannya ke Files/Drive atau mengirimnya ke aplikasi lain).
@immutable
class ExportFile {
  const ExportFile({
    required this.fileName,
    required this.content,
    this.mimeType = 'text/plain',
    this.description,
  });

  /// Nama berkas yang dilihat user (mis. `codementor-riwayat-....csv`).
  final String fileName;

  /// Isi berkas apa adanya dari server (CSV/JSON sebagai teks).
  final String content;

  /// MIME type untuk share sheet (mis. `text/csv`).
  final String mimeType;

  /// Keterangan opsional yang ikut dikirim (mis. judul di share sheet).
  final String? description;
}

/// Gagal menyiapkan berkas ekspor; [message] siap ditampilkan.
class ExportException implements Exception {
  const ExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Penyimpan/pembagi berkas ekspor.
///
/// Dipisahkan sebagai antarmuka supaya:
/// - test UI tidak perlu plugin native (`share_plus`) — cukup memakai fake,
/// - cara berbagai berkas bisa diganti (mis. simpan ke folder Download) tanpa
///   menyentuh layar Riwayat/Pengaturan.
abstract class ExportSaver {
  /// Menyimpan/membagikan [file] dan mengembalikan pesan siap tampil.
  ///
  /// Melempar [ExportException] bila gagal.
  Future<String> save(ExportFile file);
}

/// Implementasi di perangkat: membuka share sheet Android/iOS.
///
/// Isi berkas ditulis ke file sementara oleh `share_plus`
/// (`XFile.fromData` + `fileNameOverrides`), lalu sistem yang menentukan
/// aplikasi tujuan.
class ShareExportSaver implements ExportSaver {
  const ShareExportSaver();

  @override
  Future<String> save(ExportFile file) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(file.content),
              mimeType: file.mimeType,
            ),
          ],
          // `name` pada XFile.fromData diabaikan sebagian platform, jadi nama
          // berkas ditentukan lewat `fileNameOverrides` (cara resmi plugin).
          fileNameOverrides: [file.fileName],
          subject: file.fileName,
          text: file.description,
        ),
      );

      if (result.status == ShareResultStatus.dismissed) {
        return 'Ekspor dibatalkan.';
      }
      return 'Berkas ${file.fileName} siap dibagikan.';
    } catch (error) {
      throw ExportException('Gagal menyiapkan berkas ekspor: $error');
    }
  }
}

/// Penyimpan berkas ekspor (satu instance untuk seluruh aplikasi).
final exportSaverProvider = Provider<ExportSaver>(
  (ref) => const ShareExportSaver(),
);
