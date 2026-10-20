import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/chat_history_item.dart';
import 'history_repository.dart';

/// Filter daftar riwayat.
///
/// - [language] dikirim ke SERVER (`GET /api/history?language=`),
/// - [query] disaring LOKAL di layar (sama seperti web: pencarian tidak
///   memanggil API supaya tidak boros permintaan tiap ketukan tombol).
@immutable
class HistoryFilter {
  const HistoryFilter({this.language = 'all', this.query = ''});

  /// `'all'` = semua bahasa.
  final String language;

  /// Kata kunci pencarian (dicocokkan ke error code & kode sumber).
  final String query;

  bool get isActive => language != 'all' || query.trim().isNotEmpty;

  HistoryFilter copyWith({String? language, String? query}) => HistoryFilter(
    language: language ?? this.language,
    query: query ?? this.query,
  );
}

/// State + aksi filter riwayat.
class HistoryFilterController extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() => const HistoryFilter();

  /// Mengganti bahasa; memicu pemuatan ulang daftar dari server.
  void setLanguage(String language) =>
      state = state.copyWith(language: language);

  /// Mengubah kata kunci pencarian lokal.
  void setQuery(String query) => state = state.copyWith(query: query);

  /// Mengembalikan filter ke kondisi awal.
  void reset() => state = const HistoryFilter();
}

/// Filter aktif layar Riwayat.
final historyFilterProvider =
    NotifierProvider<HistoryFilterController, HistoryFilter>(
      HistoryFilterController.new,
    );

/// Daftar riwayat milik user (server memfilter bahasa, `limit` 50 seperti web).
///
/// Refresh: `ref.invalidate(historyListProvider)`.
///
/// Hanya NILAI `language` yang dipantau (`select`), supaya mengetik di kolom
/// pencarian tidak memicu permintaan baru ke server.
final historyListProvider = FutureProvider<List<ChatHistoryItem>>((ref) async {
  final language = ref.watch(
    historyFilterProvider.select((filter) => filter.language),
  );
  final repository = ref.watch(historyRepositoryProvider);
  return repository.fetchList(language: language);
});

/// Detail satu riwayat (`/riwayat/:id`).
///
/// Melempar [HistoryException] dengan `notFound: true` bila entri tidak ada.
final historyDetailProvider = FutureProvider.family<ChatHistoryItem, String>(
  (ref, id) => ref.watch(historyRepositoryProvider).fetchDetail(id),
);
