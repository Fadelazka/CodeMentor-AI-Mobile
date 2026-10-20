import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_nav.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../auth/data/auth_snapshot.dart';
import '../../dashboard/data/dashboard_repository.dart';

/// Kerangka area setelah login (padanan layout `(app)` + `Sidebar` di web).
///
/// Struktur:
/// - **satu top bar** (AppBar) berisi judul yang berubah sesuai halaman;
/// - **Drawer** = sidebar web dipindahkan ke sisi kiri (bagian "Utama",
///   "Kelola", lalu footer Profil/Pengaturan — lihat `app_nav.dart`);
/// - **bottom navigation** 3 item inti per peran:
///   admin -> Dashboard · Chat AI · Riwayat,
///   user  -> Chat AI · Riwayat · Pengetahuan.
///
/// Peran dibaca dari `authSnapshotProvider` (bukan dari parameter), jadi begitu
/// admin/user berpindah, menunya ikut berubah tanpa perlu membuat dua router.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.location,
  });

  /// State navigasi antar-tab (disediakan `StatefulShellRoute` go_router).
  final StatefulNavigationShell navigationShell;

  /// Path halaman yang sedang aktif (`GoRouterState.uri.path`).
  final String location;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Tab terakhir yang benar-benar salah satu item bottom navigation.
  ///
  /// Dipakai ketika halaman aktif dibuka dari Drawer (Profil, Pengaturan,
  /// Pengetahuan, Admin) sehingga tidak ada item bottom yang cocok — nilai
  /// `NavigationBar.selectedIndex` tetap harus valid.
  int _lastBottomIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authSnapshotProvider).session?.user.isAdmin == true;
    final bottomItems = bottomNavItemsFor(isAdmin: isAdmin);
    final branchIndex = widget.navigationShell.currentIndex;

    final matched = bottomItems.indexWhere(
      (item) => shellBranchIndexOf(item.path) == branchIndex,
    );
    if (matched >= 0) _lastBottomIndex = matched;
    final selected = matched >= 0 ? matched : _lastBottomIndex;

    return Scaffold(
      backgroundColor: AppColors.surface1,
      appBar: _buildAppBar(isAdmin: isAdmin),
      drawer: _AppDrawer(
        isAdmin: isAdmin,
        currentPath: shellNavItems[branchIndex].path,
        onSelect: _goToPath,
      ),
      body: widget.navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderSoft)),
        ),
        child: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (index) =>
              _goToPath(bottomItems[index].path),
          destinations: [
            for (final item in bottomItems)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }

  /// Pindah tab lewat branch go_router (stack tiap tab tetap tersimpan).
  void _goToPath(String path) {
    final index = shellBranchIndexOf(path);
    if (index >= 0) widget.navigationShell.goBranch(index);
  }

  PreferredSizeWidget _buildAppBar({required bool isAdmin}) {
    final location = widget.location;
    final isDashboard = location == AppRoutes.dashboard;

    return AppBar(
      title: isDashboard ? const AppLogo(size: 26, showText: true) : Text(_titleFor(location)),
      actions: [
        // Tombol muat ulang hanya relevan di Dashboard.
        if (isDashboard)
          IconButton(
            onPressed: () => ref.invalidate(dashboardStatsProvider),
            tooltip: 'Muat ulang statistik',
            icon: const Icon(Icons.refresh, size: 20),
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Judul top bar per halaman (web memakai breadcrumb/judul halaman).
String _titleFor(String location) {
  if (location.startsWith(AppRoutes.chat)) return 'Chat AI';
  if (location.startsWith(AppRoutes.history)) {
    return location == AppRoutes.history ? 'Riwayat' : 'Detail Riwayat';
  }
  if (location.startsWith(AppRoutes.knowledge)) return 'Pengetahuan';
  if (location.startsWith(AppRoutes.admin)) return 'Admin';
  if (location.startsWith(AppRoutes.profile)) return 'Profil';
  if (location.startsWith(AppRoutes.settings)) return 'Pengaturan';
  return 'CodeMentor AI';
}

/// Drawer navigasi: salinan sidebar web
/// (`src/components/layout/sidebar.tsx`, `getNavSections`).
class _AppDrawer extends ConsumerWidget {
  const _AppDrawer({
    required this.isAdmin,
    required this.currentPath,
    required this.onSelect,
  });

  final bool isAdmin;
  final String currentPath;
  final ValueChanged<String> onSelect;

  void _pilih(BuildContext context, String path) {
    Navigator.of(context).pop();
    if (path != currentPath) onSelect(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSnapshotProvider).session?.user;
    final sections = navSectionsFor(isAdmin: isAdmin);

    return Drawer(
      backgroundColor: AppColors.sidebar,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DrawerHeader(
              name: user?.name?.trim().isNotEmpty == true
                  ? user!.name!.trim()
                  : 'Sobat CodeMentor',
              email: user?.email ?? '-',
              isAdmin: isAdmin,
            ),
            const Divider(height: 1, color: AppColors.borderSoft),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                children: [
                  for (final section in sections) ...[
                    _SectionLabel(label: section.label),
                    for (final item in section.items)
                      _DrawerTile(
                        icon: item.icon,
                        label: item.label,
                        badge: item.badge,
                        selected: item.path == currentPath,
                        onTap: () => _pilih(context, item.path),
                      ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in footerNavItems)
                    _DrawerTile(
                      icon: item.icon,
                      label: item.label,
                      selected: item.path == currentPath,
                      onTap: () => _pilih(context, item.path),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.name,
    required this.email,
    required this.isAdmin,
  });

  final String name;
  final String email;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppLogo(size: 28, showText: true),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Text(
                  _initialOf(name),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentPink.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.accentPink.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isAdmin ? 'ADMIN' : 'USER BIASA',
              style: AppTheme.mono(
                fontSize: 9.5,
                letterSpacing: 1,
                color: AppColors.accentPink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _initialOf(String name) =>
    name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Text(label.toUpperCase(), style: AppTheme.monoLabel),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accentPink : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? AppColors.accentPink.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
