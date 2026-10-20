import 'package:flutter/material.dart';
import 'package:flutter_next_auth_core/next_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_screen.dart';
import '../../features/auth/data/auth_snapshot.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/github_auth_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/history/presentation/history_detail_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/knowledge/presentation/knowledge_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import 'app_nav.dart';
import 'app_routes.dart';

// Supaya pemanggil lama (`login_screen.dart`, `profile_screen.dart`,
// `dashboard_screen.dart`) tetap bisa `import 'app_router.dart'` dan memakai
// `AppRoutes`, meskipun kelasnya kini tinggal di `app_routes.dart`.
export 'app_routes.dart' show AppRoutes;

/// Router aplikasi (go_router) dengan aturan BERBASIS PERAN.
///
/// Aturan redirect (meniru web):
/// 1. sesi masih diperiksa (`initial`/`loading`) -> bertahan di splash;
/// 2. belum login                               -> `/login`;
/// 3. sudah login & membuka splash/login        -> admin `/dashboard`,
///    user biasa `/chat` (web: `dashboard/page.tsx:87` mengalihkan non-admin
///    ke `/chat`);
/// 4. non-admin membuka `/dashboard` atau `/admin` -> dialihkan ke `/chat`.
///
/// Area setelah login memakai [StatefulShellRoute.indexedStack] supaya setiap
/// tab punya STACK navigasinya sendiri (posisi scroll & sub-halaman tidak
/// hilang saat berpindah tab) — padanan layout `(app)` di web.
///
/// Urutan branch diambil dari [shellNavItems] (`app_nav.dart`) agar daftar
/// menu dan daftar route tidak pernah berbeda.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Pemicu perpindahan halaman: status sesi (dibaca ulang di `redirect`).
  final status = ValueNotifier<SessionStatus>(
    ref.read(authSnapshotProvider).status,
  );
  ref.listen<AuthSnapshot>(authSnapshotProvider, (_, next) {
    status.value = next.status;
  });
  ref.onDispose(status.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: status,
    redirect: (context, state) {
      final snapshot = ref.read(authSnapshotProvider);
      final statusSesi = snapshot.status;
      final isAdmin = snapshot.session?.user.isAdmin == true;
      final location = state.matchedLocation;

      // 1. Sesi sedang diperiksa.
      if (statusSesi == SessionStatus.initial ||
          statusSesi == SessionStatus.loading) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // 2. Belum login.
      if (statusSesi != SessionStatus.authenticated) {
        if (location == AppRoutes.login ||
            location == AppRoutes.register ||
            location == AppRoutes.forgotPassword ||
            location == AppRoutes.githubAuth) {
          return null;
        }
        return AppRoutes.login;
      }

      // 3. Sudah login: halaman tamu tidak boleh dibuka lagi.
      if (location == AppRoutes.login ||
          location == AppRoutes.register ||
          location == AppRoutes.forgotPassword ||
          location == AppRoutes.githubAuth ||
          location == AppRoutes.splash) {
        return _homeFor(isAdmin: isAdmin);
      }

      // 4. Halaman khusus admin (Dashboard & Admin).
      if (!isAdmin && AppRoutes.adminOnly.contains(location)) {
        return AppRoutes.chat;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.githubAuth,
        builder: (context, state) => const GithubAuthScreen(),
      ),

      // ===== Area setelah login (Drawer + bottom navigation) =====
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          // Dipakai `AppShell` untuk menentukan judul top bar & menu aktif.
          location: state.uri.path,
        ),
        branches: [
          for (final item in shellNavItems)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: item.path,
                  builder: (context, state) => _screenFor(item.path),
                  routes: item.path == AppRoutes.history
                      ? [
                          // Detail riwayat tetap di dalam tab Riwayat supaya
                          // bottom navigation ikut terlihat (seperti web:
                          // /riwayat/[id]).
                          GoRoute(
                            path: AppRoutes.historyDetailSegment,
                            builder: (context, state) => HistoryDetailScreen(
                              id: state.pathParameters['id'] ?? '',
                            ),
                          ),
                        ]
                      : const [],
                ),
              ],
            ),
        ],
      ),
    ],
  );
});

/// Halaman awal setelah login.
String _homeFor({required bool isAdmin}) =>
    isAdmin ? AppRoutes.dashboard : AppRoutes.chat;

/// Layar untuk setiap branch (dipetakan berdasarkan path, bukan index, supaya
/// penambahan menu baru tidak menggeser layar yang salah).
Widget _screenFor(String path) => switch (path) {
  AppRoutes.dashboard => const DashboardScreen(),
  AppRoutes.chat => const ChatScreen(),
  AppRoutes.history => const HistoryScreen(),
  AppRoutes.knowledge => const KnowledgeScreen(),
  AppRoutes.admin => const AdminScreen(),
  AppRoutes.profile => const ProfileScreen(),
  AppRoutes.settings => const SettingsScreen(),
  _ => const SplashScreen(),
};
