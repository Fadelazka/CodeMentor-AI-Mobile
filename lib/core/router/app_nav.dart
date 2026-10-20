import 'package:flutter/material.dart';

import 'app_routes.dart';

/// =============================================================================
/// Sumber kebenaran navigasi area setelah login
/// =============================================================================
///
/// Meniru `getNavSections()` di web
/// (`src/components/layout/sidebar.tsx:39-59`):
///
/// - **Utama** : admin -> Dashboard, Chat AI, Riwayat
///               user  -> Chat AI, Riwayat
/// - **Kelola** : Pengetahuan (semua user), Admin (khusus admin)
/// - footer    : Profil, Pengaturan
///
/// Di mobile, sidebar web dipadatkan menjadi:
/// - **bottom navigation** 3 tab inti per peran (lihat [bottomNavItems]),
/// - **Drawer** berisi seluruh menu web ([navSectionsFor]) — jadi tidak ada
///   fitur web yang hilang, hanya berbeda cara membukanya.
///
/// URUTAN [shellNavItems] = urutan `StatefulShellBranch` di `app_router.dart`.
/// itulah sebabnya `branchIndex` dihitung dari indeks daftar ini.
class AppNavItem {
  const AppNavItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badge,
    this.adminOnly = false,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Badge kecil di samping label (web memakai badge "AI" pada Chat AI).
  final String? badge;

  /// Hanya boleh dibuka admin (dipagari `redirect` di router).
  final bool adminOnly;
}

const AppNavItem _dashboard = AppNavItem(
  path: AppRoutes.dashboard,
  label: 'Dashboard',
  icon: Icons.dashboard_outlined,
  selectedIcon: Icons.dashboard,
  adminOnly: true,
);

const AppNavItem _chat = AppNavItem(
  path: AppRoutes.chat,
  label: 'Chat AI',
  icon: Icons.forum_outlined,
  selectedIcon: Icons.forum,
  badge: 'AI',
);

const AppNavItem _history = AppNavItem(
  path: AppRoutes.history,
  label: 'Riwayat',
  icon: Icons.history_outlined,
  selectedIcon: Icons.history,
);

const AppNavItem _knowledge = AppNavItem(
  path: AppRoutes.knowledge,
  label: 'Pengetahuan',
  icon: Icons.menu_book_outlined,
  selectedIcon: Icons.menu_book,
);

const AppNavItem _admin = AppNavItem(
  path: AppRoutes.admin,
  label: 'Admin',
  icon: Icons.shield_outlined,
  selectedIcon: Icons.shield,
  adminOnly: true,
);

const AppNavItem _profile = AppNavItem(
  path: AppRoutes.profile,
  label: 'Profil',
  icon: Icons.person_outline,
  selectedIcon: Icons.person,
);

const AppNavItem _settings = AppNavItem(
  path: AppRoutes.settings,
  label: 'Pengaturan',
  icon: Icons.settings_outlined,
  selectedIcon: Icons.settings,
);

/// Urutan branch `StatefulShellRoute.indexedStack` (indeks = indeks branch).
///
/// PENTING: urutan di sini harus sama dengan urutan pembuatan branch di
/// `app_router.dart` — dijaga oleh test `test/router_role_test.dart`.
const List<AppNavItem> shellNavItems = [
  _dashboard,
  _chat,
  _history,
  _knowledge,
  _admin,
  _profile,
  _settings,
];

/// Indeks branch go_router untuk sebuah path.
int shellBranchIndexOf(String path) {
  final index = shellNavItems.indexWhere((item) => item.path == path);
  assert(index >= 0, 'Path $path tidak terdaftar di shellNavItems');
  return index;
}

/// Satu bagian menu pada Drawer (padanan `NavSection` web).
class AppNavSection {
  const AppNavSection({required this.label, required this.items});

  final String label;
  final List<AppNavItem> items;
}

/// Isi Drawer — menyalin struktur sidebar web `getNavSections(isAdmin)`.
List<AppNavSection> navSectionsFor({required bool isAdmin}) => [
  AppNavSection(
    label: 'Utama',
    items: [
      if (isAdmin) _dashboard,
      _chat,
      _history,
    ],
  ),
  AppNavSection(
    label: 'Kelola',
    items: [
      _knowledge,
      if (isAdmin) _admin,
    ],
  ),
];

/// Menu footer sidebar web (Profil & Pengaturan).
List<AppNavItem> get footerNavItems => const [_profile, _settings];

/// Item bottom navigation (3 peran ditampilkan, sisanya lewat Drawer).
///
/// - Admin: Dashboard · Chat AI · Riwayat (sama dengan bagian "Utama" web).
/// - User biasa: Chat AI · Riwayat · Pengetahuan (Pengetahuan di web ada di
///   bagian "Kelola"; di sini dipakai sebagai tab ketiga supaya bottom
///   navigation tetap seimbang dan fitur itu tetap mudah dijangkau).
List<AppNavItem> bottomNavItemsFor({required bool isAdmin}) => isAdmin
    ? const [_dashboard, _chat, _history]
    : const [_chat, _history, _knowledge];
