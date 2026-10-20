// Test UI layar Admin (`lib/features/admin/presentation/admin_screen.dart`).
//
// Statistik datang dari override `dashboardStatsProvider` (bentuk
// `/api/admin/stats`) dan Knowledge Base dari `FakeKnowledgeBaseRepository`
// — keduanya tanpa jaringan.
import 'package:codementor_mobile/core/router/app_routes.dart';
import 'package:codementor_mobile/features/admin/data/kb_entry.dart';
import 'package:codementor_mobile/features/admin/data/kb_repository.dart';
import 'package:codementor_mobile/features/admin/presentation/kb_form_screen.dart';
import 'package:codementor_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:codementor_mobile/features/dashboard/domain/dashboard_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_test_harness.dart';
import 'support/fake_kb_repository.dart';

/// Layar tinggi supaya seluruh isi ListView terbangun (bisa diperiksa tanpa
/// perlu menggulir).
void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Statistik admin contoh (bentuk respons `GET /api/admin/stats`).
DashboardStats _fakeStats() => const DashboardStats(
  isAdminView: true,
  totalQuestions: 1200,
  aiAccuracy: 87.5,
  avgResponseTimeMs: 840,
  errorsSolved: 932,
  topErrors: [
    TopError(errorType: 'ZeroDivisionError', count: 128),
    TopError(errorType: 'SyntaxError', count: 96),
  ],
  meta: DashboardMeta(totalUsers: 210, activeUsers7d: 32),
);

/// Dua rekaman contoh: satu Python (aktif), satu Java (nonaktif).
List<KbEntry> _twoEntries() => [
  fakeKbEntry(
    id: 'kb-1',
    language: 'python',
    errorCode: 'ZeroDivisionError',
    title: 'Pembagian dengan Nol',
    description: 'Terjadi saat membagi dengan 0.',
  ),
  fakeKbEntry(
    id: 'kb-2',
    language: 'java',
    errorCode: 'NullPointerException',
    title: 'Menunjuk Ke Null',
    description: 'Variabel null diakses propertinya.',
    tags: const <String>[],
    isActive: false,
    updatedAt: DateTime(2026, 10, 5),
  ),
];

/// Menyalakan aplikasi lalu membuka halaman Admin (hanya untuk admin).
Future<void> _openAdmin(
  WidgetTester tester, {
  required FakeKnowledgeBaseRepository repository,
  DashboardStats? stats,
}) async {
  _useTallView(tester);
  await pumpApp(
    tester,
    session: adminSession(),
    knowledgeBaseRepository: repository,
    overrides: [
      dashboardStatsProvider.overrideWith((ref) async => stats ?? _fakeStats()),
    ],
  );
  routerOf(tester).go(AppRoutes.admin);
  await pumpSteps(tester, steps: 8);
}

/// Berpindah ke tab Knowledge Base lewat pengalih tab.
Future<void> _openKnowledgeBase(WidgetTester tester) async {
  await tester.tap(find.text('KNOWLEDGE BASE'));
  await pumpSteps(tester, steps: 8);
}

/// Mengisi form tambah/edit lewat urutan [TextField]-nya.
///
/// URUTAN: 0 Tipe Error, 1 Judul, 2 Deskripsi, 3 Solusi, 4 Contoh Kode,
/// 5 Konsep Terkait (dropdown bahasa bukan TextField).
///
/// Field SELALU di-scope ke [KbFormScreen] — saat transisi push masih
/// berjalan, layar Admin di belakangnya masih ikut terbangun dan punya
/// TextField pencarian sendiri (bisa menggeser urutan indeks).
Future<void> _fillForm(
  WidgetTester tester, {
  required String errorCode,
  required String title,
  required String description,
  required String solution,
  String? tags,
}) async {
  final fields = find.descendant(
    of: find.byType(KbFormScreen),
    matching: find.byType(TextField),
  );
  Future<void> fill(int index, String text) async {
    await tester.enterText(fields.at(index), text);
    await tester.pump();
  }

  await fill(0, errorCode);
  await fill(1, title);
  await fill(2, description);
  await fill(3, solution);
  if (tags != null) await fill(5, tags);
}

void main() {
  setUpAll(configureAppTests);
  setUp(configureAppTests);

  testWidgets('tab Dashboard menampilkan KPI, chip user, dan top error', (
    tester,
  ) async {
    final repository = FakeKnowledgeBaseRepository(entries: _twoEntries());

    await _openAdmin(tester, repository: repository);

    // Header + pengalih tab.
    expect(find.text('ADMIN'), findsOneWidget);
    expect(find.text('Dashboard Admin'), findsOneWidget);
    expect(find.text('Mode Administrator Aktif'), findsOneWidget);
    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('KNOWLEDGE BASE'), findsOneWidget);

    // Kartu KPI (data dari /api/admin/stats).
    expect(find.text('TOTAL PERTANYAAN (SEMUA USER)'), findsOneWidget);
    expect(find.text('1200'), findsOneWidget);
    expect(find.text('87,5%'), findsOneWidget);
    expect(find.text('840ms'), findsOneWidget);
    expect(find.text('932'), findsOneWidget);

    // Chip jumlah user.
    expect(find.text('210 total user'), findsOneWidget);
    expect(find.text('32 aktif 7 hari'), findsOneWidget);

    // Top error.
    expect(find.text('Error Paling Sering Dikonsultasikan'), findsOneWidget);
    expect(find.text('Rank 1'), findsOneWidget);
    expect(find.text('ZeroDivisionError'), findsOneWidget);
    expect(find.text('128x'), findsOneWidget);

    // Tab Knowledge Base belum dibuka -> daftar belum dimuat (lazy).
    expect(repository.listFetchCount, 0);
  });

  testWidgets('tab Knowledge Base menampilkan kartu rekaman lengkap', (
    tester,
  ) async {
    final repository = FakeKnowledgeBaseRepository(entries: _twoEntries());

    await _openAdmin(tester, repository: repository);
    await _openKnowledgeBase(tester);

    expect(find.text('Kelola Knowledge Base'), findsOneWidget);
    expect(find.text('Rekaman error yang tersedia untuk RAG retrieval'),
        findsOneWidget);
    expect(find.text('Cari rekaman...'), findsOneWidget);
    expect(find.text('Tambah'), findsOneWidget);

    // Kartu pertama (Python, aktif).
    expect(find.text('Python'), findsOneWidget);
    expect(find.text('ZeroDivisionError'), findsOneWidget);
    expect(find.text('Pembagian dengan Nol'), findsOneWidget);
    expect(find.text('Terjadi saat membagi dengan 0.'), findsOneWidget);
    expect(find.text('AKTIF'), findsOneWidget);
    expect(find.textContaining('Diperbarui 06 Okt 2026'), findsOneWidget);

    // Kartu kedua (Java, nonaktif).
    expect(find.text('Java'), findsOneWidget);
    expect(find.text('NullPointerException'), findsOneWidget);
    expect(find.text('NONAKTIF'), findsOneWidget);

    // Daftar dimuat tepat satu kali saat tab dibuka.
    expect(repository.listFetchCount, 1);
  });

  testWidgets('pencarian menyaring daftar secara lokal', (tester) async {
    final repository = FakeKnowledgeBaseRepository(entries: _twoEntries());

    await _openAdmin(tester, repository: repository);
    await _openKnowledgeBase(tester);

    await tester.enterText(find.byType(TextField), 'nullpointer');
    await tester.pump();

    expect(find.text('NullPointerException'), findsOneWidget);
    expect(find.text('ZeroDivisionError'), findsNothing);

    // Tidak ada rekaman yang cocok.
    await tester.enterText(find.byType(TextField), 'tidak-ada');
    await tester.pump();

    expect(find.text('Tidak ada rekaman yang cocok.'), findsOneWidget);

    // Pencarian lokal tidak memicu request ulang ke server.
    expect(repository.listFetchCount, 1);
  });

  testWidgets('daftar kosong menampilkan pesan "Belum ada rekaman"', (
    tester,
  ) async {
    await _openAdmin(tester, repository: FakeKnowledgeBaseRepository());
    await _openKnowledgeBase(tester);

    expect(find.text('Belum ada rekaman knowledge base.'), findsOneWidget);
  });

  testWidgets('gagal memuat: panel error + tombol Coba lagi', (tester) async {
    final repository = FakeKnowledgeBaseRepository(entries: _twoEntries())
      ..listError = const KbException('Forbidden: admin only');

    await _openAdmin(tester, repository: repository);
    await _openKnowledgeBase(tester);

    expect(find.text('Gagal memuat rekaman'), findsOneWidget);
    expect(find.text('Forbidden: admin only'), findsOneWidget);

    // Server pulih -> muat ulang lewat tombol retry.
    repository.listError = null;
    await tester.tap(find.text('Coba lagi'));
    await pumpSteps(tester, steps: 8);

    expect(find.text('ZeroDivisionError'), findsOneWidget);
    expect(repository.listFetchCount, 2);
  });

  testWidgets('tambah rekaman: validasi lokal lalu tersimpan', (tester) async {
    final repository = FakeKnowledgeBaseRepository(entries: _twoEntries());

    await _openAdmin(tester, repository: repository);
    await _openKnowledgeBase(tester);

    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Rekaman Error'), findsOneWidget);
    expect(find.text('Isi detail rekaman knowledge base yang ingin disimpan.'),
        findsOneWidget);

    // Validasi: field wajib masih kosong (pesan sama persis dengan web).
    await tester.tap(find.text('Simpan'));
    await tester.pump();

    expect(find.text(KbEntryDraft.errErrorCode), findsOneWidget);
    expect(find.text(KbEntryDraft.errTitle), findsOneWidget);
    expect(find.text(KbEntryDraft.errDescription), findsOneWidget);
    expect(find.text(KbEntryDraft.errSolution), findsOneWidget);
    expect(repository.createdDrafts, isEmpty);

    // Isi form lalu simpan.
    await _fillForm(
      tester,
      errorCode: 'IndexError',
      title: 'Index Di Luar Jangkauan',
      description: 'Akses list di luar panjangnya.',
      solution: 'Cek panjang list sebelum diakses.',
      tags: 'Math, Index',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Kembali ke daftar + SnackBar pesan server + kartu baru tampil.
    expect(find.text('Tambah Rekaman Error'), findsNothing);
    expect(find.text('Rekaman knowledge base ditambahkan.'), findsOneWidget);
    expect(find.text('IndexError'), findsOneWidget);
    expect(find.text('Index Di Luar Jangkauan'), findsOneWidget);

    expect(repository.createdDrafts, hasLength(1));
    final draft = repository.createdDrafts.single;
    expect(draft.errorCode, 'IndexError');
    expect(draft.tags, <String>['Math', 'Index']);
    // Bahasa default dropdown = Python.
    expect(draft.language, 'python');
  });

  testWidgets('edit rekaman: form terisi data lama & Simpan Perubahan', (
    tester,
  ) async {
    final repository = FakeKnowledgeBaseRepository(entries: _twoEntries());

    await _openAdmin(tester, repository: repository);
    await _openKnowledgeBase(tester);

    await tester.tap(find.byTooltip('Edit rekaman').first);
    await tester.pumpAndSettle();

    expect(find.text('Edit Rekaman Error'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);
    // Field pertama sudah terisi kode error lama.
    expect(find.widgetWithText(TextField, 'ZeroDivisionError'), findsOneWidget);

    // Scope ke form: layar Admin di belakang masih bisa ikut terbangun.
    final titleField = find
        .descendant(
          of: find.byType(KbFormScreen),
          matching: find.byType(TextField),
        )
        .at(1);
    await tester.enterText(titleField, 'Pembagian Nol (Revisi)');
    await tester.pump();
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(find.text('Rekaman diperbarui.'), findsOneWidget);
    expect(repository.updatedIds, <String>['kb-1']);
    expect(repository.updatedDrafts.single.title, 'Pembagian Nol (Revisi)');
    expect(find.text('Pembagian Nol (Revisi)'), findsOneWidget);
  });

  testWidgets('hapus rekaman: konfirmasi Batal lalu Hapus', (tester) async {
    final repository = FakeKnowledgeBaseRepository(entries: _twoEntries());

    await _openAdmin(tester, repository: repository);
    await _openKnowledgeBase(tester);

    await tester.tap(find.byTooltip('Hapus rekaman').first);
    await tester.pumpAndSettle();

    expect(find.text('Hapus Rekaman Error?'), findsOneWidget);
    expect(find.text('Tindakan ini tidak dapat dibatalkan.'), findsOneWidget);

    // Batal: tidak ada yang dihapus.
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, isEmpty);
    expect(find.text('ZeroDivisionError'), findsOneWidget);

    // Konfirmasi: rekaman terhapus dan SnackBar muncul.
    await tester.tap(find.byTooltip('Hapus rekaman').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, Hapus'));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, <String>['kb-1']);
    expect(find.text('Rekaman dihapus.'), findsOneWidget);
    expect(find.text('ZeroDivisionError'), findsNothing);
    expect(find.text('NullPointerException'), findsOneWidget);
  });

  testWidgets('tombol status: AKTIF -> NONAKTIF lewat toggle', (tester) async {
    final repository = FakeKnowledgeBaseRepository(entries: _twoEntries());

    await _openAdmin(tester, repository: repository);
    await _openKnowledgeBase(tester);

    await tester.tap(find.text('AKTIF'));
    await tester.pumpAndSettle();

    expect(repository.toggledIds, <String>['kb-1|false']);
    expect(find.text('Status rekaman diperbarui.'), findsOneWidget);
    // Kedua rekaman kini nonaktif.
    expect(find.text('NONAKTIF'), findsNWidgets(2));
    expect(find.text('AKTIF'), findsNothing);
  });

  testWidgets('menu Admin di Drawer membuka layar Admin', (tester) async {
    _useTallView(tester);
    await pumpApp(
      tester,
      session: adminSession(),
      knowledgeBaseRepository: FakeKnowledgeBaseRepository(),
      overrides: [
        dashboardStatsProvider.overrideWith((ref) async => _fakeStats()),
      ],
    );

    await openDrawer(tester);
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Admin'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Admin'),
      ),
    );
    await pumpSteps(tester, steps: 8);

    expect(find.text('Dashboard Admin'), findsOneWidget);
  });

  testWidgets('user biasa: menu Admin & Dashboard tidak ada di Drawer', (
    tester,
  ) async {
    _useTallView(tester);
    await pumpApp(
      tester,
      session: studentSession(),
      knowledgeBaseRepository: FakeKnowledgeBaseRepository(),
    );

    await openDrawer(tester);

    // Dibatasi ke Drawer: label yang sama juga muncul di bottom navigation.
    final drawer = find.byType(Drawer);
    expect(
      find.descendant(of: drawer, matching: find.text('Admin')),
      findsNothing,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Dashboard')),
      findsNothing,
    );
    // Menu utama user biasa tetap ada.
    expect(
      find.descendant(of: drawer, matching: find.text('Chat AI')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Riwayat')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Pengetahuan')),
      findsOneWidget,
    );
  });
}
