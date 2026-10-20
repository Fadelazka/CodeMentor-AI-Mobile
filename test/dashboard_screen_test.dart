// Test UI layar Dashboard + kerangka navigasi (bottom navigation & Drawer).
//
// Berbeda dari `tool/dashboard_probe.dart` (jaringan asli), test ini memakai
// DATA PALSU lewat override provider supaya:
//   1. deterministik (tidak bergantung isi database produksi),
//   2. tidak butuh jaringan sama sekali,
//   3. bisa menguji tiga keadaan: data penuh, belum ada aktivitas, dan gagal
//      memuat.
import 'package:codementor_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:codementor_mobile/features/dashboard/domain/dashboard_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_test_harness.dart';

/// Statistik contoh mirip isi produksi.
DashboardStats _fakeStats({bool isAdmin = true}) => DashboardStats.fromJson({
  'isAdminView': isAdmin,
  'summary': {
    'totalQuestions': 42,
    'aiAccuracy': 87.5,
    'avgResponseTime': 1500,
    'errorsSolved': 7,
  },
  'charts': {
    'daily': [
      {'date': '2026-10-05T00:00:00.000Z', 'count': 3},
      {'date': '2026-10-06T00:00:00.000Z', 'count': 9},
    ],
    'languages': [
      {'language': 'python', 'count': 30},
      {'language': 'java', 'count': 12},
    ],
  },
  'recentActivity': [
    {
      'id': 'a1',
      'language': 'python',
      'errorCode': 'NameError',
      'confidence': 90,
      'createdAt': '2026-10-06T10:30:00.000Z',
    },
  ],
  'meta': {'totalUsers': 12, 'activeUsers7d': 4},
});

/// Layar tinggi supaya seluruh isi ListView terbangun (bisa diperiksa tanpa
/// perlu menggulir).
void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() {
    configureAppTests();
  });
  setUp(configureAppTests);

  testWidgets('dashboard admin: header, 4 kartu statistik, dan grafik', (
    tester,
  ) async {
    _useTallView(tester);
    await pumpApp(
      tester,
      session: adminSession(),
      overrides: [
        dashboardStatsProvider.overrideWith((ref) async => _fakeStats()),
      ],
    );

    // Header ala web: eyebrow font-mono + sapaan + CTA gradien.
    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.textContaining('Selamat datang kembali, Admin'), findsOneWidget);
    expect(
      find.text('Pantau aktivitas pengguna CodeMentor AI secara real-time.'),
      findsOneWidget,
    );
    expect(find.text('Tanya Error Baru'), findsOneWidget);

    // Info khusus admin (total user & user aktif 7 hari).
    expect(find.text('12 total user'), findsOneWidget);
    expect(find.text('4 aktif 7 hari'), findsOneWidget);

    // 4 kartu statistik dengan nilai yang sudah diformat.
    expect(find.text('42'), findsOneWidget);
    expect(find.text('87,5%'), findsOneWidget);
    expect(find.text('1.5s'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    for (final label in [
      'TOTAL PERTANYAAN (SEMUA USER)',
      'AKURASI AI',
      'WAKTU RESPONS',
      'ERROR DIPECAHKAN (GLOBAL)',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'label "$label" hilang');
    }

    // Grafik & aktivitas terakhir.
    expect(find.text('Aktivitas 14 Hari'), findsOneWidget);
    expect(find.text('Bahasa yang Digunakan'), findsOneWidget);
    // "Python" muncul 2x: label di grafik bahasa + bahasa baris aktivitas.
    expect(find.text('Python'), findsNWidgets(2));
    expect(find.text('Java'), findsOneWidget);
    expect(find.text('Aktivitas Terakhir'), findsOneWidget);
    expect(find.text('NameError'), findsOneWidget);
  });

  testWidgets('admin: bottom navigation 3 tab inti, Profil lewat Drawer', (
    tester,
  ) async {
    _useTallView(tester);
    await pumpApp(
      tester,
      session: adminSession(),
      overrides: [
        dashboardStatsProvider.overrideWith((ref) async => _fakeStats()),
      ],
    );

    // Admin: Dashboard · Chat AI · Riwayat (Profil & Pengetahuan di Drawer).
    final navigationBar = find.byType(NavigationBar);
    for (final tab in ['Dashboard', 'Chat AI', 'Riwayat']) {
      expect(
        find.descendant(of: navigationBar, matching: find.text(tab)),
        findsOneWidget,
        reason: 'tab "$tab" hilang',
      );
    }
    expect(
      find.descendant(of: navigationBar, matching: find.text('Profil')),
      findsNothing,
    );

    // Pindah ke tab Chat AI: layar chat asli (Fase 2), bukan placeholder.
    await tapBottomTab(tester, 'Chat AI');
    expect(find.text('Tempel kode & pesan errornya'), findsOneWidget);
    expect(find.text('DASHBOARD'), findsNothing);

    // Tab Riwayat: layar riwayat asli (Fase 3) dengan repository palsu kosong.
    await tapBottomTab(tester, 'Riwayat');
    expect(find.text('Riwayat Analisis'), findsOneWidget);
    expect(find.text('Belum ada riwayat'), findsOneWidget);

    // Kembali ke Dashboard: datanya tidak dimuat ulang dari nol.
    await tapBottomTab(tester, 'Dashboard');
    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);

    // Drawer memuat seluruh menu sidebar web + menu Admin (khusus admin).
    await openDrawer(tester);
    final drawer = find.byType(Drawer);
    for (final item in [
      'Dashboard',
      'Chat AI',
      'Riwayat',
      'Pengetahuan',
      'Admin',
      'Profil',
      'Pengaturan',
    ]) {
      expect(
        find.descendant(of: drawer, matching: find.text(item)),
        findsOneWidget,
        reason: 'menu Drawer "$item" hilang',
      );
    }

    // Buka Profil lewat Drawer.
    await tester.tap(find.descendant(of: drawer, matching: find.text('Profil')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Keluar dari akun'), findsOneWidget);
    expect(find.text('admin@codementor.com'), findsOneWidget);
    expect(find.text('NIM'), findsOneWidget);
    expect(find.text('V3925005'), findsOneWidget);
  });

  testWidgets('statistik kosong: tampil ajakan mulai chat', (tester) async {
    _useTallView(tester);
    await pumpApp(
      tester,
      session: adminSession(),
      overrides: [
        dashboardStatsProvider.overrideWith(
          (ref) async => DashboardStats.empty(),
        ),
      ],
    );

    expect(find.text('Belum ada aktivitas'), findsOneWidget);
    expect(find.text('Mulai Chat'), findsOneWidget);
    expect(find.text('Aktivitas 14 Hari'), findsNothing);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('gagal memuat: tampil pesan error + tombol coba lagi', (
    tester,
  ) async {
    _useTallView(tester);
    await pumpApp(
      tester,
      session: adminSession(),
      overrides: [
        dashboardStatsProvider.overrideWith(
          (ref) async => throw const DashboardException(
            'Server tidak terjangkau.',
          ),
        ),
      ],
    );

    expect(find.text('Gagal memuat statistik'), findsOneWidget);
    expect(find.text('Server tidak terjangkau.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });
}
