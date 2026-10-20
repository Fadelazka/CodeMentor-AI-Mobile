// Test UI layar Pengaturan
// (`lib/features/settings/presentation/settings_screen.dart`).
//
// Yang dijaga:
//   - semua seksi & nilai default tampil,
//   - preferensi AI/editor benar-benar tersimpan ke penyimpanan lokal,
//   - "Kembalikan Default" mengembalikan semuanya,
//   - aksi Akun: unduh data (lewat `ExportSaver` palsu) & ubah password
//     (validasi lokal + pemanggilan server palsu).
import 'package:codementor_mobile/core/router/app_routes.dart';
import 'package:codementor_mobile/features/settings/data/account_repository.dart';
import 'package:codementor_mobile/features/settings/data/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_test_harness.dart';
import 'support/fake_account_repository.dart';
import 'support/fake_export_saver.dart';

/// Layar tinggi supaya seluruh isi ListView terbangun.
void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Menyalakan aplikasi lalu membuka halaman Pengaturan.
Future<void> _openSettings(
  WidgetTester tester, {
  FakeAccountRepository? accountRepository,
  FakeExportSaver? saver,
}) async {
  _useTallView(tester);
  await pumpApp(
    tester,
    session: studentSession(),
    accountRepository: accountRepository,
    exportSaver: saver,
  );
  routerOf(tester).go(AppRoutes.settings);
  await pumpSteps(tester, steps: 8);
}

/// Mengisi ketiga kolom dialog ubah password.
///
/// `pump()` di antara penulisan penting: fokus & koneksi input Flutter baru
/// aktif setelah satu frame, kalau tidak teks bisa masuk ke kolom sebelumnya.
Future<void> _isiKataSandi(
  WidgetTester tester, {
  required String lama,
  required String baru,
  required String konfirmasi,
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), lama);
  await tester.pump();
  await tester.enterText(fields.at(1), baru);
  await tester.pump();
  await tester.enterText(fields.at(2), konfirmasi);
  await tester.pump();
}

void main() {
  setUpAll(configureAppTests);
  setUp(configureAppTests);

  testWidgets('pengaturan: seksi dan nilai default tampil', (tester) async {
    await _openSettings(tester);

    expect(find.text('// PENGATURAN'), findsOneWidget);
    // Judul muncul dua kali: top bar `AppShell` + kepala halaman di dalam.
    expect(find.text('Pengaturan'), findsNWidgets(2));
    expect(
      find.text('Kelola preferensi dan tampilan aplikasi Anda'),
      findsOneWidget,
    );
    expect(find.text('Kembalikan Default'), findsOneWidget);

    // Empat seksi seperti web.
    expect(find.text('Preferensi Tampilan'), findsOneWidget);
    expect(find.text('Preferensi AI'), findsOneWidget);
    expect(find.text('Notifikasi'), findsOneWidget);
    expect(find.text('Akun'), findsOneWidget);

    // Bagian yang benar-benar berfungsi di mobile.
    expect(find.text('Ukuran Font Editor'), findsOneWidget);
    expect(find.text('Bahasa Penjelasan'), findsOneWidget);
    expect(find.text('Tingkat Detail Jawaban'), findsOneWidget);
    expect(find.text('Auto-save Chat History'), findsOneWidget);

    // Tema dikunci gelap (bukan tombol palsu).
    expect(find.text('GELAP AKTIF'), findsOneWidget);
    expect(find.textContaining('tema gelap CodeMentor'), findsOneWidget);

    // Nilai default = DEFAULT_SETTINGS web.
    expect(find.text('Bahasa Indonesia'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Sedang'), findsNWidgets(2)); // font editor + detail AI
    expect(find.text('Singkat'), findsOneWidget);
    expect(find.text('Detail'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    // Notifikasi: error penting & update fitur mati, rekomendasi mingguan hidup.
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .map((checkbox) => checkbox.value)
          .toList(),
      <bool>[false, false, true],
    );
    expect(find.text('Error penting'), findsOneWidget);
    expect(find.text('Update fitur baru'), findsOneWidget);
    expect(find.text('Materi rekomendasi mingguan'), findsOneWidget);

    // Hapus akun sengaja belum tersedia (seperti web).
    final hapusAkun = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Hapus Akun'),
    );
    expect(hapusAkun.onPressed, isNull);
  });

  testWidgets('preferensi AI & ukuran font tersimpan ke penyimpanan lokal', (
    tester,
  ) async {
    await _openSettings(tester);

    await tester.tap(find.text('English'));
    await tester.pump();
    await tester.tap(find.text('Singkat'));
    await tester.pump();
    await tester.tap(find.text('Besar'));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text('Error penting'));
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppSettingsController.aiLanguageKey), 'en');
    expect(prefs.getString(AppSettingsController.aiDetailLevelKey), 'brief');
    expect(prefs.getDouble(AppSettingsController.editorFontSizeKey), 16);
    expect(prefs.getBool(AppSettingsController.autoSaveHistoryKey), isFalse);
    expect(
      prefs.getBool(AppSettingsController.emailCriticalErrorsKey),
      isTrue,
    );
  });

  testWidgets('Kembalikan Default: nilai dihapus & kembali ke awal', (
    tester,
  ) async {
    await _openSettings(tester);

    await tester.tap(find.text('English'));
    await tester.pump();
    expect(
      (await SharedPreferences.getInstance()).getString(
        AppSettingsController.aiLanguageKey,
      ),
      'en',
    );

    await tester.tap(find.text('Kembalikan Default'));
    await tester.pumpAndSettle();

    expect(find.text('Direset ke default'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppSettingsController.aiLanguageKey), isNull);
    expect(prefs.getDouble(AppSettingsController.editorFontSizeKey), isNull);
  });

  testWidgets('unduh data saya: berkas JSON dibagikan lewat ExportSaver', (
    tester,
  ) async {
    final saver = FakeExportSaver()..message = 'Data akun siap dibagikan.';

    await _openSettings(tester, saver: saver);

    await tester.tap(find.text('Unduh Data Saya'));
    await tester.pumpAndSettle();

    expect(saver.saved, hasLength(1));
    expect(saver.saved.single.mimeType, 'application/json');
    expect(find.text('Data akun siap dibagikan.'), findsOneWidget);
  });

  testWidgets('unduh data saya gagal: pesan kesalahan ditampilkan', (
    tester,
  ) async {
    final account = FakeAccountRepository()
      ..exportError = const AccountException('Gagal mengunduh data.');

    await _openSettings(tester, accountRepository: account);

    await tester.tap(find.text('Unduh Data Saya'));
    await tester.pumpAndSettle();

    expect(find.text('Gagal mengunduh data.'), findsOneWidget);
    // Tombol kembali aktif (spinner tidak nyangkut).
    expect(find.text('Unduh Data Saya'), findsOneWidget);
  });

  testWidgets('ubah password: validasi lokal, kirim ke server, konfirmasi', (
    tester,
  ) async {
    final account = FakeAccountRepository();

    await _openSettings(tester, accountRepository: account);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Ubah Password'));
    await tester.pumpAndSettle();

    // Judul dialog + tombol memakai teks yang sama.
    expect(find.text('Ubah Password'), findsNWidgets(2));
    expect(find.text('Ganti password akun Anda'), findsOneWidget);

    // 1. Field kosong.
    await tester.tap(find.text('Simpan Password'));
    await tester.pumpAndSettle();
    expect(find.text('Semua field wajib diisi'), findsOneWidget);

    // 2. Password baru kurang dari 6 huruf.
    await _isiKataSandi(tester, lama: 'lama123', baru: 'baru', konfirmasi: 'baru');
    await tester.tap(find.text('Simpan Password'));
    await tester.pumpAndSettle();
    expect(find.text('Password baru minimal 6 karakter'), findsOneWidget);

    // 3. Konfirmasi tidak cocok.
    await tester.enterText(find.byType(TextField).at(1), 'baru1234');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(2), 'beda1234');
    await tester.pump();
    await tester.tap(find.text('Simpan Password'));
    await tester.pumpAndSettle();
    expect(find.text('Konfirmasi password tidak cocok'), findsOneWidget);

    // 4. Berhasil -> server dipanggil, lalu tampil konfirmasi.
    await tester.enterText(find.byType(TextField).at(2), 'baru1234');
    await tester.pump();
    await tester.tap(find.text('Simpan Password'));
    await tester.pumpAndSettle();

    expect(account.passwordChanges, <String>['lama123|baru1234']);
    expect(find.text('Password Berhasil Diubah'), findsOneWidget);
    expect(find.text('Masuk Ulang'), findsOneWidget);
  });

  testWidgets('ubah password: pesan dari server diteruskan apa adanya', (
    tester,
  ) async {
    final account = FakeAccountRepository()
      ..changePasswordError = const AccountException('Password lama salah');

    await _openSettings(tester, accountRepository: account);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Ubah Password'));
    await tester.pumpAndSettle();

    await _isiKataSandi(
      tester,
      lama: 'salah123',
      baru: 'baru1234',
      konfirmasi: 'baru1234',
    );
    await tester.tap(find.text('Simpan Password'));
    await tester.pumpAndSettle();

    expect(find.text('Password lama salah'), findsOneWidget);
    // Masih di form (belum pindah ke tampilan sukses).
    expect(find.text('Password Berhasil Diubah'), findsNothing);
  });
}
