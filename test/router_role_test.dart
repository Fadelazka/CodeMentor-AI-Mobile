// Test aturan routing BERBASIS PERAN (`lib/core/router/app_router.dart`).
//
// Yang dijaga di sini adalah aturan yang sama dengan web:
//   - admin      -> halaman awal `/dashboard`, boleh membuka `/admin`;
//   - user biasa -> halaman awal `/chat`, `/dashboard` & `/admin` DITOLAK;
//   - belum login-> selalu diarahkan ke `/login`;
//   - sesi masih diperiksa -> bertahan di splash.
import 'package:codementor_mobile/core/router/app_nav.dart';
import 'package:codementor_mobile/core/router/app_router.dart';
import 'package:codementor_mobile/core/router/app_routes.dart';
import 'package:codementor_mobile/features/auth/data/auth_repository.dart';
import 'package:codementor_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:codementor_mobile/features/dashboard/domain/dashboard_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_next_auth_core/next_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_test_harness.dart';
import 'support/fake_history_repository.dart';

/// Teks khas layar Chat (keadaan kosong).
const String _chatMarker = 'Tempel kode & pesan errornya';

/// Teks khas layar Dashboard.
const String _dashboardMarker = 'DASHBOARD';

void main() {
  setUpAll(configureAppTests);
  setUp(configureAppTests);

  test(
    'shellNavItems: urutan branch tetap (indeks dipakai go_router)',
    () {
      expect(AppRoutes.splash, '/');
      expect(AppRoutes.login, '/login');
      // Urutan WAJIB sama dengan urutan `StatefulShellBranch` di app_router.dart
      // (branch dibuat dari daftar ini, jadi perubahan urutan aman — test ini
      // mengunci urutannya supaya tidak berubah tanpa sadar).
      expect(
        shellNavItems.map((item) => item.path).toList(),
        <String>[
          '/dashboard',
          '/chat',
          '/riwayat',
          '/pengetahuan',
          '/admin',
          '/profil',
          '/pengaturan',
        ],
      );
    },
  );

  testWidgets('admin: halaman awal = Dashboard', (tester) async {
    await pumpApp(
      tester,
      session: adminSession(),
      overrides: [
        dashboardStatsProvider.overrideWith(
          (ref) async => DashboardStats.empty(),
        ),
      ],
    );

    expect(find.text(_dashboardMarker), findsOneWidget);
    expect(find.text(_chatMarker), findsNothing);
  });

  testWidgets('user biasa: halaman awal = Chat (bukan Dashboard)', (
    tester,
  ) async {
    await pumpApp(tester, session: studentSession());

    expect(find.text(_chatMarker), findsOneWidget);
    expect(find.text(_dashboardMarker), findsNothing);
  });

  testWidgets('user biasa: /dashboard & /admin dialihkan ke /chat', (
    tester,
  ) async {
    await pumpApp(tester, session: studentSession());
    final router = routerOf(tester);

    // Paksa buka halaman khusus admin.
    router.go(AppRoutes.admin);
    await pumpSteps(tester, steps: 8);
    expect(find.text('Panel Admin'), findsNothing);
    expect(find.text(_chatMarker), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.chat);

    router.go(AppRoutes.dashboard);
    await pumpSteps(tester, steps: 8);
    expect(find.text(_dashboardMarker), findsNothing);
    expect(router.state.uri.path, AppRoutes.chat);
  });

  testWidgets('admin: /admin & /pengetahuan boleh dibuka', (tester) async {
    await pumpApp(
      tester,
      session: adminSession(),
      overrides: [
        dashboardStatsProvider.overrideWith(
          (ref) async => DashboardStats.empty(),
        ),
      ],
    );
    final router = routerOf(tester);

    router.go(AppRoutes.admin);
    await pumpSteps(tester, steps: 8);
    // Layar Admin kini nyata (bukan placeholder "Segera Hadir"):
    // header + tab Dashboard/Knowledge Base tampil.
    expect(find.text('Dashboard Admin'), findsOneWidget);
    expect(find.text('Mode Administrator Aktif'), findsOneWidget);
    expect(find.text('KNOWLEDGE BASE'), findsOneWidget);
    expect(find.text('SEGERA HADIR'), findsNothing);

    router.go(AppRoutes.knowledge);
    await pumpSteps(tester, steps: 8);
    expect(find.text('Base Pengetahuan'), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.knowledge);
  });

  testWidgets('detail riwayat: sub-route /riwayat/:id memakai ID dari URL', (
    tester,
  ) async {
    // Repository palsu hanya mengenal ID `abc123`: bila router tidak memakai
    // ID dari URL, `fetchDetail` melempar notFound dan layar menampilkan
    // "Riwayat Tidak Ditemukan".
    final repository = FakeHistoryRepository(
      items: [
        fakeHistoryItem(id: 'abc123', errorMessage: 'Kesalahan dari ID abc123'),
      ],
    );

    await pumpApp(
      tester,
      session: studentSession(),
      historyRepository: repository,
    );
    final router = routerOf(tester);

    router.go('${AppRoutes.history}/abc123');
    await pumpSteps(tester, steps: 8);
    expect(find.text('Detail Analisis'), findsOneWidget);
    expect(find.text('Kesalahan dari ID abc123'), findsOneWidget);
    expect(find.text('Riwayat Tidak Ditemukan'), findsNothing);
    // Masih di dalam tab Riwayat -> bottom navigation tetap terlihat.
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('belum login: selalu diarahkan ke halaman Masuk', (
    tester,
  ) async {
    await pumpApp(
      tester,
      session: studentSession(),
      status: SessionStatus.unauthenticated,
    );

    expect(find.text('Masuk'), findsWidgets);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text(_chatMarker), findsNothing);
  });

  testWidgets('sesi masih diperiksa: bertahan di splash', (tester) async {
    await pumpApp(
      tester,
      session: studentSession(),
      status: SessionStatus.initial,
      overrides: [
        // Splash memanggil fetchSession(): jangan sampai menyentuh jaringan.
        authRepositoryProvider.overrideWithValue(NoNetworkAuthRepository()),
      ],
    );

    expect(find.text('Memeriksa sesi...'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
