// Pengganti `ShareExportSaver` untuk test UI.
//
// `share_plus` adalah plugin native dan tidak tersedia di `flutter test`, jadi
// setiap layar yang menawarkan ekspor/unduh memakai pengganti ini: berkas
// dicatat di memori dan pesan hasil ditentukan test.
import 'package:codementor_mobile/core/services/export_saver.dart';

class FakeExportSaver implements ExportSaver {
  /// Berkas yang "dibagikan" (berurutan).
  final List<ExportFile> saved = <ExportFile>[];

  /// Pesan yang dikembalikan [save] (biasanya ditampilkan sebagai SnackBar).
  String message = 'Berkas siap dibagikan.';

  /// Bila tidak null, [save] melempar ini.
  ExportException? error;

  @override
  Future<String> save(ExportFile file) async {
    final failure = error;
    if (failure != null) throw failure;
    saved.add(file);
    return message;
  }
}
