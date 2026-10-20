// Perkakas bersama untuk test widget aplikasi mobile.
//
// Semua test UI memakai pola yang sama seperti `dashboard_screen_test.dart`:
// status login dipalsukan lewat override provider (tanpa jaringan), font tidak
// diunduh, dan penyimpanan aman diganti versi in-memory.
import 'package:codementor_mobile/core/services/export_saver.dart';
import 'package:codementor_mobile/features/admin/data/admin_users_repository.dart';
import 'package:codementor_mobile/features/admin/data/kb_repository.dart';
import 'package:codementor_mobile/features/auth/data/auth_repository.dart';
import 'package:codementor_mobile/features/auth/data/auth_snapshot.dart';
import 'package:codementor_mobile/features/auth/domain/app_session.dart';
import 'package:codementor_mobile/features/history/data/history_repository.dart';
import 'package:codementor_mobile/features/settings/data/account_repository.dart';
import 'package:codementor_mobile/features/settings/data/profile_repository.dart';
import 'package:codementor_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_next_auth_core/next_auth.dart';
import 'package:flutter_next_auth_riverpod/next_auth_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_account_repository.dart';
import 'fake_admin_users_repository.dart';
import 'fake_export_saver.dart';
import 'fake_history_repository.dart';
import 'fake_kb_repository.dart';
import 'fake_profile_repository.dart';
import 'in_memory_secure_storage.dart';

/// Notifier pengganti: status login ditentukan test (tanpa jaringan).
class FakeAuthSnapshotNotifier extends AuthSnapshotNotifier {
  FakeAuthSnapshotNotifier(this.snapshot);

  final AuthSnapshot snapshot;

  @override
  AuthSnapshot build() => snapshot;
}

/// Sesi admin contoh (punya akses Dashboard & Admin).
AppSession adminSession() => const AppSession(
  user: AppSessionUser(
    id: 'user-admin',
    name: 'Admin cik',
    email: 'admin@codementor.com',
    role: 'ADMIN',
    nim: 'V3925005',
  ),
);

/// Sesi user biasa contoh (TIDAK punya akses Dashboard/Admin).
AppSession studentSession() => const AppSession(
  user: AppSessionUser(
    id: 'user-mhs',
    name: 'Budi Santoso',
    email: 'budi@example.com',
    nim: 'V3925001',
    favoriteLanguage: 'python',
  ),
);

/// Repository auth TANPA jaringan: `fetchSession()` langsung selesai.
///
/// Dipakai test yang sengaja membiarkan status sesi `initial` (layar splash),
/// karena `SplashScreen` memanggil `fetchSession()` dan tanpa override ini test
/// akan mencoba menghubungi server.
class NoNetworkAuthRepository extends AuthRepository {
  NoNetworkAuthRepository()
    : super(client: AuthRepository.createNextAuthClient());

  @override
  Future<AppSession?> fetchSession() async => null;

  @override
  Future<AuthResult> signInWithCredentials({
    required String email,
    required String password,
  }) async => const AuthResult.failure('Login tidak tersedia di test.');

  @override
  Future<void> signOut() async {}
}

/// Wajib dipanggil di `setUp` (atau `setUpAll`) setiap test UI.
void configureAppTests() {
  // Jangan unduh font dari internet saat test.
  GoogleFonts.config.allowRuntimeFetching = false;
  // Tidak ada plugin native di `flutter test`.
  FlutterSecureStoragePlatform.instance = InMemorySecureStorage();
  // `shared_preferences` juga tanpa plugin native: pakai nilai palsu.
  SharedPreferences.setMockInitialValues(<String, Object>{});
}

/// Menyalakan aplikasi lengkap (router + shell) dengan sesi yang ditentukan.
///
/// [overrides] sengaja TIDAK diberi anotasi tipe (implisit `dynamic`) karena
/// tipe `Override` milik Riverpod 3 tidak diekspor untuk pemakai paket. Dengan
/// tipe konteks `dynamic`, tulisannya boleh tetap `[...]` dan element-nya
/// diinferensi benar (`ProviderScope.overrides` yang menentukan tipenya).
///
/// [historyRepository], [exportSaver], [accountRepository], dan
/// [knowledgeBaseRepository], [adminUsersRepository], [profileRepository] dipakai test Fase 3-5.
/// Semuanya SELALU dioverride (walau tidak diisi) supaya test lama pun tidak
/// pernah menyentuh jaringan.
Future<void> pumpApp(
  WidgetTester tester, {
  required AppSession session,
  SessionStatus status = SessionStatus.authenticated,
  overrides = const <Object?>[],
  HistoryRepository? historyRepository,
  ExportSaver? exportSaver,
  AccountRepository? accountRepository,
  KnowledgeBaseRepository? knowledgeBaseRepository,
  AdminUsersRepository? adminUsersRepository,
  ProfileRepository? profileRepository,
}) async {
  final client = AuthRepository.createNextAuthClient();
  // `const []` bertipe `List<dynamic>`; jangan diteruskan ke `ProviderScope`
  // (field-nya `List<Override>`) kalau memang tidak dipakai.
  final bool hasOverrides = overrides is List && overrides.isNotEmpty;

  await tester.pumpWidget(
    ProviderScope(
      // Riverpod 3 mengulang provider yang gagal sampai 10x; saat test ini bikin
      // `AsyncValue.when` selalu terlihat "loading". Matikan.
      retry: (_, _) => null,
      overrides: [
        nextAuthClientProvider.overrideWithValue(client),
        authSnapshotProvider.overrideWith(
          () => FakeAuthSnapshotNotifier(
            AuthSnapshot(
              status: status,
              session: status == SessionStatus.authenticated ? session : null,
            ),
          ),
        ),
        historyRepositoryProvider.overrideWithValue(
          historyRepository ?? FakeHistoryRepository(),
        ),
        exportSaverProvider.overrideWithValue(exportSaver ?? FakeExportSaver()),
        accountRepositoryProvider.overrideWithValue(
          accountRepository ?? FakeAccountRepository(),
        ),
        kbRepositoryProvider.overrideWithValue(
          knowledgeBaseRepository ?? FakeKnowledgeBaseRepository(),
        ),
        adminUsersRepositoryProvider.overrideWithValue(
          adminUsersRepository ?? FakeAdminUsersRepository(),
        ),
        profileRepositoryProvider.overrideWithValue(
          profileRepository ?? FakeProfileRepository(),
        ),
        if (hasOverrides) ...overrides,
      ],
      child: NextAuthRiverpodScope<AppSession>(
        client: client,
        child: const CodeMentorApp(),
      ),
    ),
  );

  await pumpSteps(tester);
}

/// Beberapa putaran pump supaya transisi router & provider async selesai.
Future<void> pumpSteps(
  WidgetTester tester, {
  int steps = 6,
  Duration step = const Duration(milliseconds: 20),
}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(step);
  }
}

/// `GoRouter` yang sedang dipakai aplikasi (untuk navigasi programatik di test).
GoRouter routerOf(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(NavigationBar).first));

/// Membuka Drawer lewat tombol hamburger di AppBar.
Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

/// Menekan satu item bottom navigation (bukan label di AppBar/Drawer).
Future<void> tapBottomTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}
