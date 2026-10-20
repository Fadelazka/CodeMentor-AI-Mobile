// Test UI layar Riwayat (`lib/features/history/presentation/history_screen.dart`).
//
// Semua data datang dari `FakeHistoryRepository` (tanpa jaringan) dan berkas
// ekspor ditangani `FakeExportSaver` (tanpa plugin `share_plus`).
import 'package:codementor_mobile/core/router/app_routes.dart';
import 'package:codementor_mobile/core/services/export_saver.dart';
import 'package:codementor_mobile/features/history/data/history_repository.dart';
import 'package:codementor_mobile/features/history/domain/chat_history_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_test_harness.dart';
import 'support/fake_export_saver.dart';
import 'support/fake_history_repository.dart';

/// Layar tinggi supaya seluruh isi ListView terbangun (bisa diperiksa tanpa
/// perlu menggulir).
void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Dua entri contoh: satu Python, satu Java.
List<ChatHistoryItem> _twoItems() => [
  fakeHistoryItem(
    id: 'h1',
    language: 'python',
    errorCode: 'NameError',
    sourceCode: 'print(x)',
  ),
  fakeHistoryItem(
    id: 'h2',
    language: 'java',
    errorCode: 'NullPointerException',
    sourceCode: 'int a = null;',
    confidence: 60,
  ),
];

/// Menyalakan aplikasi lalu membuka tab Riwayat.
Future<void> _openHistory(
  WidgetTester tester,
  FakeHistoryRepository repository, {
  FakeExportSaver? saver,
}) async {
  _useTallView(tester);
  await pumpApp(
    tester,
    session: studentSession(),
    historyRepository: repository,
    exportSaver: saver,
  );
  routerOf(tester).go(AppRoutes.history);
  await pumpSteps(tester, steps: 8);
}

void main() {
  setUpAll(configureAppTests);
  setUp(configureAppTests);

  testWidgets('daftar riwayat: badge, cuplikan kode, dan footer jumlah', (
    tester,
  ) async {
    final repository = FakeHistoryRepository(
      items: _twoItems(),
    );

    await _openHistory(tester, repository);

    expect(find.text('RIWAYAT'), findsOneWidget);
    expect(find.text('Riwayat Analisis'), findsOneWidget);
    expect(find.text('NameError'), findsOneWidget);
    expect(find.text('NullPointerException'), findsOneWidget);
    expect(find.text('print(x)'), findsOneWidget);
    // Badge confidence dari entri Java (60% -> kuning, tetap teks yang sama).
    expect(find.text('Confidence 88%'), findsOneWidget);
    expect(find.text('Confidence 60%'), findsOneWidget);
    // Tanggal lokal + zona waktu perangkat.
    expect(find.textContaining('06 Okt 2026'), findsWidgets);
    // Footer hitungan (2 dari 2 karena belum ada filter).
    expect(find.text('Menampilkan 2 dari 2 riwayat'), findsOneWidget);
    // Filter bahasa awal tidak dikirim ke server.
    expect(repository.listLanguages, <String>['all']);
  });

  testWidgets('filter bahasa memanggil server & menyaring daftar', (
    tester,
  ) async {
    final repository = FakeHistoryRepository(
      items: _twoItems(),
    );

    await _openHistory(tester, repository);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Java').last);
    await tester.pumpAndSettle();

    expect(repository.listLanguages, <String>['all', 'java']);
    expect(find.text('NullPointerException'), findsOneWidget);
    expect(find.text('NameError'), findsNothing);
    expect(find.text('Menampilkan 1 dari 1 riwayat'), findsOneWidget);
  });

  testWidgets('pencarian disaring lokal, tanpa permintaan baru ke server', (
    tester,
  ) async {
    final repository = FakeHistoryRepository(
      items: _twoItems(),
    );

    await _openHistory(tester, repository);

    await tester.enterText(find.byType(TextField), 'nullpointer');
    await tester.pump();

    expect(find.text('NullPointerException'), findsOneWidget);
    expect(find.text('NameError'), findsNothing);
    expect(find.text('Menampilkan 1 dari 2 riwayat'), findsOneWidget);
    expect(
      repository.listLanguages,
      <String>['all'],
      reason: 'mengetik tidak boleh memanggil GET /api/history lagi',
    );

    // Tombol "Reset filter" mengembalikan pencarian & bahasa.
    await tester.tap(find.text('Reset filter'));
    await tester.pump();
    expect(find.text('NameError'), findsOneWidget);
    expect(find.text('Menampilkan 2 dari 2 riwayat'), findsOneWidget);
  });

  testWidgets('belum ada riwayat: ajakan mulai bertanya menuju Chat AI', (
    tester,
  ) async {
    final repository = FakeHistoryRepository();

    await _openHistory(tester, repository);

    expect(find.text('Belum ada riwayat'), findsOneWidget);
    expect(
      find.text('Coba tanyakan error pertama Anda di halaman Chat AI.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Mulai Bertanya'));
    await pumpSteps(tester, steps: 8);
    expect(routerOf(tester).state.uri.path, AppRoutes.chat);
  });

  testWidgets('tidak ada hasil filter: pesan khusus', (tester) async {
    final repository = FakeHistoryRepository(
      items: _twoItems(),
    );

    await _openHistory(tester, repository);

    await tester.enterText(find.byType(TextField), 'zzz-tidak-ada');
    await tester.pump();

    expect(find.text('Tidak ada hasil filter'), findsOneWidget);
    expect(
      find.text('Coba ubah kata kunci atau filter bahasa.'),
      findsOneWidget,
    );
  });

  testWidgets('gagal memuat: panel error lalu "Coba lagi" memulihkan', (
    tester,
  ) async {
    final repository = FakeHistoryRepository(
      items: _twoItems(),
    )..listError = const HistoryException(
      'Tidak dapat terhubung ke server. Periksa koneksi internetmu.',
    );

    await _openHistory(tester, repository);

    expect(find.text('Gagal memuat riwayat'), findsOneWidget);
    expect(
      find.text('Tidak dapat terhubung ke server. Periksa koneksi internetmu.'),
      findsOneWidget,
    );

    repository.listError = null;
    await tester.tap(find.text('Coba lagi'));
    await pumpSteps(tester, steps: 8);

    expect(find.text('Gagal memuat riwayat'), findsNothing);
    expect(find.text('NameError'), findsOneWidget);
  });

  testWidgets('hapus satu entri: konfirmasi dulu, lalu daftar diperbarui', (
    tester,
  ) async {
    final repository = FakeHistoryRepository(
      items: _twoItems(),
    );

    await _openHistory(tester, repository);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Hapus').first);
    await tester.pumpAndSettle();
    expect(find.text('Hapus riwayat ini?'), findsOneWidget);

    // Batal: tidak ada yang terhapus.
    await tester.tap(find.widgetWithText(TextButton, 'Batal'));
    await tester.pumpAndSettle();
    expect(repository.deletedIds, isEmpty);
    expect(find.text('NameError'), findsOneWidget);

    // Setujui: entri pertama hilang.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Hapus').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, <String>['h1']);
    expect(find.text('NameError'), findsNothing);
    expect(find.text('NullPointerException'), findsOneWidget);
    expect(find.text('Riwayat dihapus.'), findsOneWidget);
  });

  testWidgets('hapus semua: konfirmasi lalu daftar menjadi kosong', (
    tester,
  ) async {
    final repository = FakeHistoryRepository(
      items: _twoItems(),
    );

    await _openHistory(tester, repository);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Hapus Semua'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus SEMUA riwayat?'), findsOneWidget);
    expect(find.text('Tindakan ini tidak dapat dibatalkan.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();

    expect(repository.deleteAllCount, 1);
    expect(find.text('Semua riwayat dihapus.'), findsOneWidget);
    expect(find.text('Belum ada riwayat'), findsOneWidget);
  });

  testWidgets('ekspor CSV memakai filter aktif & membagikan berkas', (
    tester,
  ) async {
    final saver = FakeExportSaver()
      ..message = 'Berkas codementor-riwayat.csv siap dibagikan.';
    final repository = FakeHistoryRepository(
      items: _twoItems(),
    );

    await _openHistory(tester, repository, saver: saver);

    // Filter bahasa Python + kata kunci "Name".
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Python').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Name');
    await tester.pump();

    await tester.tap(find.text('Ekspor'));
    await tester.pumpAndSettle();
    expect(find.text('EKSPOR RIWAYAT'), findsOneWidget);
    expect(find.text('Buka di Excel / Google Sheets'), findsOneWidget);

    await tester.tap(find.text('Export CSV'));
    await tester.pumpAndSettle();

    expect(repository.exportCalls, <String>['csv|python|Name']);
    expect(saver.saved, hasLength(1));
    expect(saver.saved.single.mimeType, 'text/csv');
    expect(
      saver.saved.single.fileName,
      'codementor-riwayat-2026-10-06-10-30-00.csv',
    );
    expect(
      find.text('Berkas codementor-riwayat.csv siap dibagikan.'),
      findsOneWidget,
    );
  });

  testWidgets('ekspor JSON: tipe berkas application/json', (tester) async {
    final saver = FakeExportSaver();
    final repository = FakeHistoryRepository(
      items: _twoItems(),
    );

    await _openHistory(tester, repository, saver: saver);

    await tester.tap(find.text('Ekspor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export JSON'));
    await tester.pumpAndSettle();

    expect(repository.exportCalls, <String>['json|all|']);
    expect(saver.saved.single.mimeType, 'application/json');
    expect(saver.saved.single.fileName, endsWith('.json'));
  });

  testWidgets('ekspor gagal: pesan kesalahan tampil, berkas tidak dikirim', (
    tester,
  ) async {
    final saver = FakeExportSaver()
      ..error = const ExportException('Ekspor dibatalkan.');
    final repository = FakeHistoryRepository(
      items: _twoItems(),
    );

    await _openHistory(tester, repository, saver: saver);

    await tester.tap(find.text('Ekspor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export CSV'));
    await tester.pumpAndSettle();

    expect(find.text('Ekspor dibatalkan.'), findsOneWidget);
    expect(saver.saved, isEmpty);
    // Tombol kembali aktif (spinner tidak nyangkut).
    expect(find.text('Ekspor'), findsOneWidget);
  });
}
