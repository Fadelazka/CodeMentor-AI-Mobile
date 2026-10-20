// Repository Knowledge Base PALSU untuk test UI.
//
// Semua permintaan berhenti di sini: test tidak menyentuh jaringan sama sekali.
// Perilaku yang ditiru `KnowledgeBaseRepository` asli:
//   - `fetchEntries` mengembalikan isi daftar [entries],
//   - `createEntry` menambah entri BARU di depan (urut `updatedAt` desc),
//   - `updateEntry` menimpa entri lama di tempat,
//   - `toggleActive` mengganti status tanpa menyentuh field lain,
//   - `deleteEntry` membuang entri dan mengembalikan pesan server.
import 'package:codementor_mobile/features/admin/data/kb_entry.dart';
import 'package:codementor_mobile/features/admin/data/kb_repository.dart';
import 'package:dio/dio.dart';

/// Rekaman Knowledge Base contoh.
KbEntry fakeKbEntry({
  String id = 'kb-1',
  String language = 'python',
  String errorCode = 'ZeroDivisionError',
  String title = 'Pembagian dengan Nol',
  String description = 'Terjadi saat membagi dengan 0.',
  String solution = 'Cek pembilang sebelum dibagi.',
  String? examples,
  List<String> tags = const ['Math'],
  bool isActive = true,
  DateTime? updatedAt,
}) => KbEntry(
  id: id,
  language: language,
  errorCode: errorCode,
  title: title,
  description: description,
  solution: solution,
  examples: examples,
  tags: tags,
  isActive: isActive,
  updatedAt: updatedAt ?? DateTime(2026, 10, 6),
);

/// Repository Knowledge Base tanpa jaringan.
class FakeKnowledgeBaseRepository extends KnowledgeBaseRepository {
  FakeKnowledgeBaseRepository({List<KbEntry>? entries})
    : entries = entries ?? <KbEntry>[],
      super(dio: Dio());

  /// Daftar rekaman yang dianggap tersimpan di "server".
  List<KbEntry> entries;

  /// Berapa kali `fetchEntries` dipanggil.
  int listFetchCount = 0;

  /// Draft yang dikirim lewat `createEntry`.
  final List<KbEntryDraft> createdDrafts = <KbEntryDraft>[];

  /// Id + draft yang dikirim lewat `updateEntry`.
  final List<String> updatedIds = <String>[];
  final List<KbEntryDraft> updatedDrafts = <KbEntryDraft>[];

  /// Id + status hasil `toggleActive` (format `'id|true'` / `'id|false'`).
  final List<String> toggledIds = <String>[];

  /// Id yang dihapus lewat `deleteEntry`.
  final List<String> deletedIds = <String>[];

  /// Pesan sukses yang dikembalikan tiap mutasi (untuk asersi SnackBar).
  String createdMessage = 'Rekaman knowledge base ditambahkan.';
  String updatedMessage = 'Rekaman diperbarui.';
  String toggledMessage = 'Status rekaman diperbarui.';
  String deletedMessage = 'Rekaman dihapus.';

  /// Bila tidak null, permintaan yang bersangkutan selalu gagal.
  KbException? listError;
  KbException? createError;
  KbException? updateError;
  KbException? deleteError;

  @override
  Future<List<KbEntry>> fetchEntries() async {
    listFetchCount++;
    final error = listError;
    if (error != null) throw error;
    return List<KbEntry>.of(entries);
  }

  @override
  Future<KbMutationResult> createEntry(KbEntryDraft draft) async {
    createdDrafts.add(draft);
    final error = createError;
    if (error != null) throw error;

    final created = _fromDraft(draft, id: 'kb-new-${entries.length + 1}');
    entries = [created, ...entries];
    return KbMutationResult(entry: created, message: createdMessage);
  }

  @override
  Future<KbMutationResult> updateEntry(String id, KbEntryDraft draft) async {
    updatedIds.add(id);
    updatedDrafts.add(draft);
    final error = updateError;
    if (error != null) throw error;

    final updated = _fromDraft(draft, id: id);
    entries = [for (final entry in entries) entry.id == id ? updated : entry];
    return KbMutationResult(entry: updated, message: updatedMessage);
  }

  @override
  Future<KbMutationResult> toggleActive({
    required String id,
    required bool isActive,
  }) async {
    toggledIds.add('$id|$isActive');
    final error = updateError;
    if (error != null) throw error;

    final toggled = <KbEntry>[];
    for (final entry in entries) {
      toggled.add(
        entry.id == id
            ? KbEntry(
                id: entry.id,
                language: entry.language,
                errorCode: entry.errorCode,
                title: entry.title,
                description: entry.description,
                solution: entry.solution,
                examples: entry.examples,
                tags: entry.tags,
                isActive: isActive,
                createdAt: entry.createdAt,
                updatedAt: DateTime(2026, 10, 7),
              )
            : entry,
      );
    }
    entries = toggled;

    return KbMutationResult(
      entry: toggled.firstWhere((entry) => entry.id == id),
      message: toggledMessage,
    );
  }

  @override
  Future<String> deleteEntry(String id) async {
    deletedIds.add(id);
    final error = deleteError;
    if (error != null) throw error;

    entries = [for (final entry in entries) if (entry.id != id) entry];
    return deletedMessage;
  }

  KbEntry _fromDraft(KbEntryDraft draft, {required String id}) => KbEntry(
    id: id,
    language: draft.language,
    errorCode: draft.errorCode,
    title: draft.title,
    description: draft.description,
    solution: draft.solution,
    examples: draft.examples.isEmpty ? null : draft.examples,
    tags: draft.tags,
    isActive: draft.isActive,
    updatedAt: DateTime(2026, 10, 7),
  );
}
