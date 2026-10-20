import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kb_entry.dart';
import 'kb_repository.dart';

/// Daftar rekaman Knowledge Base untuk tab admin.
///
/// Dimuat otomatis saat provider pertama dibaca (meniru `fetchRows()` yang
/// dipanggil di `useEffect` halaman admin web), lalu disegarkan lokal oleh
/// tiap mutasi — tidak perlu request ulang setelah tambah/edit/hapus.
final kbListProvider = AsyncNotifierProvider<KbListNotifier, List<KbEntry>>(
  KbListNotifier.new,
);

class KbListNotifier extends AsyncNotifier<List<KbEntry>> {
  @override
  Future<List<KbEntry>> build() => ref.watch(kbRepositoryProvider).fetchEntries();

  KnowledgeBaseRepository get _repository => ref.read(kbRepositoryProvider);

  /// Tambah rekaman; daftar lokal langsung dimasukkan entri baru di depan
  /// (server mengurut `updatedAt` desc, jadi urutannya tetap benar).
  Future<KbMutationResult> create(KbEntryDraft draft) async {
    final result = await _repository.createEntry(draft);
    state = AsyncData([
      result.entry,
      for (final entry in state.value ?? const <KbEntry>[]) entry,
    ]);
    return result;
  }

  /// Edit rekaman; entri lama ditimpa di tempat (tidak berpindah posisi).
  ///
  /// Namanya `updateEntry` (bukan `update`) karena `AsyncNotifier` sudah
  /// punya method bawaan `update`.
  Future<KbMutationResult> updateEntry(String id, KbEntryDraft draft) async {
    final result = await _repository.updateEntry(id, draft);
    _replace(result.entry);
    return result;
  }

  /// Nyalakan/matikan status Aktif dari kartu daftar (tombol status).
  Future<KbMutationResult> toggleActive(KbEntry entry) async {
    final result = await _repository.toggleActive(
      id: entry.id,
      isActive: !entry.isActive,
    );
    _replace(result.entry);
    return result;
  }

  /// Hapus rekaman; entri dibuang dari daftar lokal dan pesan server
  /// dikembalikan untuk ditampilkan sebagai SnackBar.
  Future<String> remove(String id) async {
    final message = await _repository.deleteEntry(id);
    state = AsyncData([
      for (final entry in state.value ?? const <KbEntry>[])
        if (entry.id != id) entry,
    ]);
    return message;
  }

  void _replace(KbEntry updated) {
    state = AsyncData([
      for (final entry in state.value ?? const <KbEntry>[])
        entry.id == updated.id ? updated : entry,
    ]);
  }
}

/// Kata kunci pencarian lokal di tab Knowledge Base.
///
/// Meniru state `search` di `src/app/(app)/admin/page.tsx:105` + filter
/// `filteredKb` (baris 154) — pencarian dilakukan di client, bukan di server.
class KbSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void change(String value) => state = value;

  void clear() => state = '';
}

final kbSearchProvider = NotifierProvider<KbSearchNotifier, String>(
  KbSearchNotifier.new,
);
