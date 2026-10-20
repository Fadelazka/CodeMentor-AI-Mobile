// Repository Riwayat PALSU untuk test UI.
//
// Semua permintaan berhenti di sini: test tidak menyentuh jaringan sama sekali.
// Perilaku yang ditiru `HistoryRepository` asli:
//   - `fetchList` menyaring bahasa di "server" (seperti
//     `src/app/api/history/route.ts` yang memakai `where.language`),
//   - `fetchDetail` melempar `HistoryException(notFound: true)` bila tidak ada,
//   - `deleteOne`/`deleteAll` mengubah daftar,
//   - `exportHistory` mengembalikan berkas tanpa memanggil `share_plus`.
import 'package:codementor_mobile/core/services/export_saver.dart';
import 'package:codementor_mobile/features/history/data/history_repository.dart';
import 'package:codementor_mobile/features/history/domain/chat_history_item.dart';
import 'package:dio/dio.dart';

/// Entri riwayat contoh.
ChatHistoryItem fakeHistoryItem({
  String id = 'hist-1',
  String language = 'python',
  String? errorCode = 'NameError',
  String? errorMessage = "name 'x' is not defined",
  String sourceCode = 'print(x)',
  String? aiResponse,
  int? confidence = 88,
  DateTime? createdAt,
}) => ChatHistoryItem(
  id: id,
  language: language,
  errorCode: errorCode,
  errorMessage: errorMessage,
  sourceCode: sourceCode,
  aiResponse:
      aiResponse ??
      '## Penyebab\n\nVariabel `x` belum didefinisikan.\n\n'
          '## Kode yang Sudah Dibenarkan\n\n```python\nx = 1\nprint(x)\n```\n',
  confidence: confidence,
  createdAt: createdAt ?? DateTime(2026, 10, 6, 10, 30),
);

/// Repository riwayat tanpa jaringan.
class FakeHistoryRepository extends HistoryRepository {
  FakeHistoryRepository({List<ChatHistoryItem>? items, this.detail})
    : items = items ?? <ChatHistoryItem>[],
      super(dio: Dio());

  /// Entri yang dianggap dimiliki user.
  List<ChatHistoryItem> items;

  /// Bila diisi, `fetchDetail` selalu mengembalikan ini.
  ChatHistoryItem? detail;

  /// Bahasa yang dikirim ke "server" pada setiap `fetchList`.
  final List<String> listLanguages = <String>[];

  /// ID yang dihapus lewat `deleteOne`.
  final List<String> deletedIds = <String>[];

  /// Berapa kali `deleteAll` dipanggil.
  int deleteAllCount = 0;

  /// Panggilan ekspor: `format|language|q`.
  final List<String> exportCalls = <String>[];

  /// Isi berkas yang dikembalikan `exportHistory`.
  String exportContent = 'ID,Tanggal\n1,"06 Okt 2026"\n';

  /// Bila tidak null, permintaan yang bersangkutan gagal.
  HistoryException? listError;
  HistoryException? detailError;
  HistoryException? deleteError;
  HistoryException? exportError;

  @override
  Future<List<ChatHistoryItem>> fetchList({
    String language = 'all',
    int limit = 50,
  }) async {
    listLanguages.add(language);
    final error = listError;
    if (error != null) throw error;
    if (language == 'all') return List<ChatHistoryItem>.of(items);
    return [
      for (final item in items)
        if (item.language == language) item,
    ];
  }

  @override
  Future<ChatHistoryItem> fetchDetail(String id) async {
    final error = detailError;
    if (error != null) throw error;
    final single = detail;
    if (single != null) return single;
    for (final item in items) {
      if (item.id == id) return item;
    }
    throw const HistoryException('Riwayat tidak ditemukan.', notFound: true);
  }

  @override
  Future<void> deleteOne(String id) async {
    final error = deleteError;
    if (error != null) throw error;
    deletedIds.add(id);
    items = [
      for (final item in items)
        if (item.id != id) item,
    ];
  }

  @override
  Future<void> deleteAll() async {
    final error = deleteError;
    if (error != null) throw error;
    deleteAllCount++;
    items = <ChatHistoryItem>[];
  }

  @override
  Future<ExportFile> exportHistory({
    String format = 'csv',
    String language = 'all',
    String query = '',
  }) async {
    exportCalls.add('$format|$language|$query');
    final error = exportError;
    if (error != null) throw error;

    final isJson = format == 'json';
    return ExportFile(
      fileName: 'codementor-riwayat-2026-10-06-10-30-00.$format',
      content: exportContent,
      mimeType: isJson ? 'application/json' : 'text/csv',
      description: 'Ekspor riwayat CodeMentor AI',
    );
  }
}
