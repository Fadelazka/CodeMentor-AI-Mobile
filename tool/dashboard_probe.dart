// PROBE MANUAL (bukan bagian `flutter test` default — dijalankan eksplisit):
//
//   flutter test tool/dashboard_probe.dart
//
// Tujuan STEP 2: membuktikan lapisan data Dashboard benar-benar cocok dengan
// respons backend PRODUKSI:
//   1. login admin (cookie NextAuth asli),
//   2. GET /api/admin/stats      -> bentuk bersarang (summary/charts/meta),
//   3. GET /api/dashboard/stats  -> bentuk datar (statistik pribadi user).
//
// Kenapa TIDAK memompa widget di sini? Di dalam `testWidgets` semua Timer/Future
// berjalan di zona waktu palsu (`AutomatedTestWidgetsFlutterBinding`), sehingga
// permintaan jaringan asli tidak akan pernah selesai kecuali dibungkus
// `tester.runAsync`. Karena itu probe jaringan dipisah:
//   - tool/dashboard_probe.dart          -> jaringan asli (file ini)
//   - test/dashboard_screen_test.dart    -> UI + bottom nav dengan data palsu
//
// Catatan: file ini menembak jaringan sungguhan (dan memakai kredensial admin),
// jadi sengaja diletakkan di `tool/` agar tidak ikut `flutter test` biasa.
import 'dart:io';

import 'package:codementor_mobile/core/network/dio_client.dart';
import 'package:codementor_mobile/features/auth/data/auth_repository.dart';
import 'package:codementor_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/in_memory_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Binding flutter_test memalsukan HttpClient (semua request -> 400).
  // Probe ini memang menembak server sungguhan, jadi override itu dimatikan.
  HttpOverrides.global = null;
  FlutterSecureStoragePlatform.instance = InMemorySecureStorage();

  test('Step 2: statistik dashboard admin & user dari produksi', () async {
    final client = AuthRepository.createNextAuthClient();
    final auth = AuthRepository(client: client);

    final login = await auth.signInWithCredentials(
      email: 'admin@codementor.com',
      password: 'admin123',
    );
    expect(login.ok, isTrue, reason: 'login gagal: ${login.message}');

    final dio = createApiDio(readSessionCookies: auth.sessionCookies);
    final repository = DashboardRepository(dio: dio);

    // ===== 1. Endpoint admin (statistik global, bentuk bersarang) =====
    final adminStats = await repository.fetchStats(isAdmin: true);
    expect(adminStats.isAdminView, isTrue, reason: 'harus terdeteksi respons admin');
    expect(adminStats.dbTersedia, isTrue);
    expect(adminStats.meta, isNotNull, reason: 'meta admin (total user) wajib ada');
    expect(adminStats.meta!.totalUsers, greaterThan(0));
    expect(adminStats.usageByLanguage, isNotEmpty);
    expect(adminStats.usagePerDay, isNotEmpty);

    // ===== 2. Endpoint "user" pada sesi ADMIN: bentuk CAMPURAN =====
    // Route /api/dashboard/stats memeriksa ROLE sesi
    // (src/app/api/dashboard/stats/route.ts). Saat yang login ADMIN, responsnya:
    // angka DATAR + `isAdminView: true` + `meta` (tanpa `summary`/`charts`).
    // Parser harus tahan pada bentuk ini (lihat test/dashboard_stats_test.dart
    // -> "bentuk campuran").
    final userStats = await repository.fetchStats(isAdmin: false);
    expect(
      userStats.isAdminView,
      isTrue,
      reason: 'sesi admin: /api/dashboard/stats ikut menandai isAdminView',
    );
    expect(
      userStats.totalQuestions,
      adminStats.totalQuestions,
      reason: 'angka datar harus terbaca (sebelum diperbaiki selalu 0)',
    );
    expect(userStats.errorsSolved, adminStats.errorsSolved);
    expect(userStats.usageByLanguage, isNotEmpty);
    expect(userStats.usagePerDay, isNotEmpty);
    expect(userStats.meta, isNotNull);

    // ===== 3. Tanpa cookie (belum login): bentuk DATAR =====
    final anonDio = createApiDio();
    final anonStats = await DashboardRepository(
      dio: anonDio,
    ).fetchStats(isAdmin: false);
    expect(anonStats.isAdminView, isFalse);
    expect(anonStats.totalQuestions, 0);
    expect(anonStats.errorsSolved, 0);
    expect(anonStats.usageByLanguage, isEmpty);
    expect(anonStats.usagePerDay, isEmpty);
    expect(anonStats.recentActivity, isEmpty);

    // ignore: avoid_print
    print(
      'HASIL STEP 2 (jaringan asli)\n'
      '  admin  : total=${adminStats.totalQuestions} '
      'akurasi=${adminStats.formattedAccuracy} '
      'respons=${adminStats.formattedResponseTime} '
      'error=${adminStats.errorsSolved} '
      'bahasa=${adminStats.usageByLanguage.keys.join(", ")} '
      'user=${adminStats.meta!.totalUsers} (aktif 7h: ${adminStats.meta!.activeUsers7d})\n'
      '  endpoint /api/dashboard/stats (sesi admin): '
      'isAdminView=${userStats.isAdminView} total=${userStats.totalQuestions}\n'
      '  tanpa cookie (bentuk datar): total=${anonStats.totalQuestions} '
      'bahasa=${anonStats.usageByLanguage.length} '
      'hari=${anonStats.usagePerDay.length} '
      'aktivitas=${anonStats.recentActivity.length}',
    );
  });
}
