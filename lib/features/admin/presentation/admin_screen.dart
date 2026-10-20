import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/badge_pill.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/domain/dashboard_stats.dart';
import '../data/admin_user.dart';
import '../data/admin_users_controller.dart';
import '../data/admin_users_repository.dart';
import '../data/kb_controller.dart';
import '../data/kb_entry.dart';
import '../data/kb_repository.dart';
import 'kb_form_screen.dart';
import 'user_form_screen.dart';

/// Layar Admin — padanan `src/app/(app)/admin/page.tsx`.
///
/// HANYA untuk role ADMIN (dijaga `redirect` di `app_router.dart` + guard
/// server di `/api/admin/*`). Halaman web menggabungkan statistik dan tabel
/// Knowledge Base dalam satu gulir; di mobile keduanya dipisah jadi DUA TAB:
///
/// - **Dashboard** — statistik global dari `GET /api/admin/stats`
///   (kartu KPI, chip jumlah user, top error),
/// - **Knowledge Base** — CRUD `GET/POST/PUT/DELETE /api/admin/knowledge-base`
///   (daftar, tambah, edit, hapus, toggle status Aktif/Nonaktif).
///
/// Kelola user (`/api/admin/users`) belum dibawa ke mobile — tersedia di web.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

enum _AdminTab { dashboard, knowledgeBase, users }

class _AdminScreenState extends ConsumerState<AdminScreen> {
  _AdminTab _tab = _AdminTab.dashboard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: _Header(),
        ),
        const SizedBox(height: 16),
        _AdminTabSwitch(
          value: _tab,
          onChanged: (tab) => setState(() => _tab = tab),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: switch (_tab) {
            _AdminTab.dashboard => const _StatsTab(),
            _AdminTab.knowledgeBase => const _KnowledgeBaseTab(),
            _AdminTab.users => const _UsersTab(),
          },
        ),
      ],
    );
  }
}

// =============================================================================
// Bagian: header + pengalih tab
// =============================================================================
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ADMIN', style: AppTheme.monoEyebrow),
        const SizedBox(height: 8),
        const Text(
          'Dashboard Admin',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Monitoring penggunaan, performa AI, dan knowledge base '
          'CodeMentor AI.',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        const BadgePill(
          label: 'Mode Administrator Aktif',
          tone: BadgeTone.green,
          icon: Icons.verified_user_outlined,
        ),
      ],
    );
  }
}

/// Pengalih tab ala segmen — meniru dua bagian utama halaman admin web
/// (KPI/charts di atas, kartu Knowledge Base di bawah).
class _AdminTabSwitch extends StatelessWidget {
  const _AdminTabSwitch({required this.value, required this.onChanged});

  final _AdminTab value;
  final ValueChanged<_AdminTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          border: Border.all(color: AppColors.borderSoft),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: Row(
          children: [
            for (final tab in _AdminTab.values)
              Expanded(
                child: _SegmentButton(
                  key: ValueKey('admin_tab_${tab.name}'),
                  label: tab == _AdminTab.dashboard
                      ? 'DASHBOARD'
                      : tab == _AdminTab.knowledgeBase
                          ? 'KNOWLEDGE BASE'
                          : 'USER',
                  selected: value == tab,
                  onTap: () => onChanged(tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg - 2),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: AppTheme.mono(
              fontSize: 10,
              letterSpacing: 0.8,
              color: selected ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Bagian: tab Dashboard (statistik global)
// =============================================================================
class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return RefreshIndicator(
      color: AppColors.accentPink,
      backgroundColor: AppColors.surface2,
      onRefresh: () async {
        ref.invalidate(dashboardStatsProvider);
        await ref.read(dashboardStatsProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          // Urutan cabang sama dengan layar Dashboard (lihat catatan di
          // `dashboard_screen.dart`): error tanpa data -> panel error,
          // ada data -> konten, selain itu -> skeleton.
          if (statsAsync.hasError && !statsAsync.hasValue)
            _ErrorPanel(
              title: 'Gagal memuat statistik',
              message: statsAsync.error is DashboardException
                  ? (statsAsync.error! as DashboardException).message
                  : 'Terjadi kesalahan saat mengambil statistik.',
              onRetry: () => ref.invalidate(dashboardStatsProvider),
            )
          else if (statsAsync.hasValue)
            _StatsContent(stats: statsAsync.value!)
          else
            const _StatsSkeleton(),
        ],
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final meta = stats.meta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'TOTAL PERTANYAAN (SEMUA USER)',
                value: '${stats.totalQuestions}',
                icon: Icons.people_alt,
                color: AppColors.neonCyan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'AKURASI AI',
                value: stats.formattedAccuracy,
                icon: Icons.trending_up,
                color: AppColors.neonGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'WAKTU RESPONS',
                value: stats.formattedResponseTime,
                icon: Icons.timer_outlined,
                color: AppColors.neonViolet,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'ERROR DIPECAHKAN (GLOBAL)',
                value: '${stats.errorsSolved}',
                icon: Icons.menu_book_outlined,
                color: AppColors.neonPink,
              ),
            ),
          ],
        ),
        if (meta != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetaChip(
                icon: Icons.people_alt_outlined,
                label: '${meta.totalUsers} total user',
                color: AppColors.textSecondary,
              ),
              _MetaChip(
                icon: Icons.trending_up,
                label: '${meta.activeUsers7d} aktif 7 hari',
                color: AppColors.neonGreen,
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _TopErrorsPanel(stats: stats),
      ],
    );
  }
}

/// Kartu KPI 2x2 — gaya disamakan dengan `_StatCard` di layar Dashboard.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: AppColors.borderSoft),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.mono(
              fontSize: 9,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel "Error Paling Sering Dikonsultasikan" — padanan kartu dengan tabel
/// Rank/Error/Bahasa/Jumlah di web (`admin/page.tsx:304-442`).
class _TopErrorsPanel extends StatelessWidget {
  const _TopErrorsPanel({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final errors = stats.topErrors.take(5).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Error Paling Sering Dikonsultasikan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const BadgePill(label: '5 besar', tone: BadgeTone.violet),
            ],
          ),
          const SizedBox(height: 12),
          if (errors.isEmpty)
            const Text(
              'Belum ada data error.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            )
          else
            for (var i = 0; i < errors.length; i++) ...[
              Row(
                children: [
                  Text(
                    'Rank ${i + 1}',
                    style: AppTheme.mono(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      errors[i].errorType,
                      style: AppTheme.mono(
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${errors[i].count}x',
                    style: AppTheme.mono(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (i != errors.length - 1)
                const Divider(height: 18, color: AppColors.borderSoft),
            ],
        ],
      ),
    );
  }
}

// =============================================================================
// Bagian: tab Kelola User (CRUD)
// =============================================================================
class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(adminUserQueryProvider).keyword,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openForm({AdminUser? user}) async {
    final result = await Navigator.of(context).push<AdminUserMutationResult>(
      MaterialPageRoute(builder: (_) => UserFormScreen(user: user)),
    );
    if (result == null || !mounted) return;
    _showSnack(result.message);
  }

  Future<void> _confirmDelete(AdminUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('Hapus User?'),
        content: Text(
          'Akun "${user.name ?? user.email ?? "user"}" akan dihapus permanen. '
          'Tindakan ini tidak dapat dibatalkan.',
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentPink,
            ),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final message = await ref.read(adminUsersProvider.notifier).remove(user.id);
      if (!mounted) return;
      _showSnack(message);
    } on AdminUserException catch (error) {
      if (!mounted) return;
      _showSnack(error.message);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(adminUsersProvider);
    final users = listAsync.value ?? const <AdminUser>[];
    final query = ref.watch(adminUserQueryProvider);
    final filtered = [
      for (final user in users)
        if (user.matches(query.keyword)) user,
    ];

    const pageSize = 10;
    final pageCount = filtered.isEmpty
        ? 1
        : (filtered.length / pageSize).ceil();
    final pageIndex = query.pageIndex.clamp(0, pageCount - 1);
    final paged = filtered.skip(pageIndex * pageSize).take(pageSize).toList();

    return RefreshIndicator(
      color: AppColors.accentPink,
      backgroundColor: AppColors.surface2,
      onRefresh: () async {
        ref.invalidate(adminUsersProvider);
        await ref.read(adminUsersProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          // ==== Panel judul + pencarian + tombol Tambah ====
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.panelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kelola User',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Kelola akun pengguna CodeMentor AI',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    GradientButton(
                      label: 'Tambah',
                      icon: Icons.add,
                      height: 38,
                      onPressed: () => _openForm(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    ref.read(adminUserQueryProvider.notifier).search(value);
                    if (_searchController.text != value) {
                      _searchController.value = TextEditingValue(
                        text: value,
                        selection: TextSelection.collapsed(offset: value.length),
                      );
                    }
                  },
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Cari nama atau email...',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    fillColor: AppColors.inputBg,
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ==== Isi daftar ====
          if (listAsync.hasError && !listAsync.hasValue)
            _ErrorPanel(
              title: 'Gagal memuat daftar user',
              message: listAsync.error is AdminUserException
                  ? (listAsync.error! as AdminUserException).message
                  : 'Terjadi kesalahan saat mengambil daftar user.',
              onRetry: () => ref.invalidate(adminUsersProvider),
            )
          else if (!listAsync.hasValue)
            const _LoadingHint('Memuat daftar user...')
          else if (users.isEmpty)
            const _EmptyHint('Belum ada user.')
          else if (filtered.isEmpty)
            const _EmptyHint('Tidak ada user yang cocok.')
          else ...[
            for (final user in paged) ...[
              _UserCard(
                user: user,
                dateLabel: 'Terdaftar ${_formatDate(user.createdAt)}',
                onEdit: () => _openForm(user: user),
                onDelete: () => _confirmDelete(user),
              ),
              const SizedBox(height: 10),
            ],
            if (filtered.length > pageSize) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: AppTheme.panelDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menampilkan ${paged.length} dari ${filtered.length} user',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: pageIndex > 0
                                ? () => ref
                                    .read(adminUserQueryProvider.notifier)
                                    .goToPage(pageIndex - 1)
                                : null,
                            child: const Text('Sebelumnya'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: pageIndex < pageCount - 1
                                ? () => ref
                                    .read(adminUserQueryProvider.notifier)
                                    .goToPage(pageIndex + 1)
                                : null,
                            child: const Text('Berikutnya'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.dateLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminUser user;
  final String dateLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == 'ADMIN';
    final name = (user.name != null && user.name!.trim().isNotEmpty)
        ? user.name!.trim()
        : '-';
    final email = (user.email != null && user.email!.trim().isNotEmpty)
        ? user.email!.trim()
        : '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: AppTheme.mono(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              BadgePill(
                label: user.role,
                tone: isAdmin ? BadgeTone.violet : BadgeTone.cyan,
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit user',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.accentPink,
                ),
                tooltip: 'Hapus user',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dateLabel,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Bagian: tab Knowledge Base (CRUD)
// =============================================================================
class _KnowledgeBaseTab extends ConsumerStatefulWidget {
  const _KnowledgeBaseTab();

  @override
  ConsumerState<_KnowledgeBaseTab> createState() => _KnowledgeBaseTabState();
}

class _KnowledgeBaseTabState extends ConsumerState<_KnowledgeBaseTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(kbSearchProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Membuka form tambah/edit; setelah tersimpan, pesan dari server
  /// ditampilkan sebagai SnackBar (meniru `toast.success(json.message)`).
  Future<void> _openForm({KbEntry? record}) async {
    final result = await Navigator.of(context).push<KbMutationResult>(
      MaterialPageRoute(builder: (_) => KbFormScreen(record: record)),
    );
    if (result == null || !mounted) return;
    _showSnack(result.message);
  }

  Future<void> _toggleStatus(KbEntry entry) async {
    try {
      final result = await ref
          .read(kbListProvider.notifier)
          .toggleActive(entry);
      if (!mounted) return;
      _showSnack(result.message);
    } on KbException catch (error) {
      if (!mounted) return;
      _showSnack(error.message);
    }
  }

  Future<void> _confirmDelete(KbEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('Hapus Rekaman Error?'),
        content: const Text(
          'Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentPink,
            ),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final message = await ref.read(kbListProvider.notifier).remove(entry.id);
      if (!mounted) return;
      _showSnack(message);
    } on KbException catch (error) {
      if (!mounted) return;
      _showSnack(error.message);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(kbListProvider);
    final entries = listAsync.value ?? const <KbEntry>[];
    final search = ref.watch(kbSearchProvider);
    final filtered = [
      for (final entry in entries)
        if (entry.matches(search)) entry,
    ];

    return RefreshIndicator(
      color: AppColors.accentPink,
      backgroundColor: AppColors.surface2,
      onRefresh: () async {
        ref.invalidate(kbListProvider);
        await ref.read(kbListProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          // ==== Panel judul + pencarian + tombol Tambah ====
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.panelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kelola Knowledge Base',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Rekaman error yang tersedia untuk RAG retrieval',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    GradientButton(
                      label: 'Tambah',
                      icon: Icons.add,
                      height: 38,
                      onPressed: () => _openForm(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      ref.read(kbSearchProvider.notifier).change(value),
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Cari rekaman...',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    fillColor: AppColors.inputBg,
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ==== Isi daftar: loading / error / kosong / kartu ====
          if (listAsync.hasError && !listAsync.hasValue)
            _ErrorPanel(
              title: 'Gagal memuat rekaman',
              message: listAsync.error is KbException
                  ? (listAsync.error! as KbException).message
                  : 'Terjadi kesalahan saat mengambil knowledge base.',
              onRetry: () => ref.invalidate(kbListProvider),
            )
          else if (!listAsync.hasValue)
            const _LoadingHint('Memuat rekaman knowledge base...')
          else if (entries.isEmpty)
            const _EmptyHint('Belum ada rekaman knowledge base.')
          else if (filtered.isEmpty)
            const _EmptyHint('Tidak ada rekaman yang cocok.')
          else
            for (final entry in filtered) ...[
              _KbCard(
                entry: entry,
                onEdit: () => _openForm(record: entry),
                onToggle: () => _toggleStatus(entry),
                onDelete: () => _confirmDelete(entry),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

/// Satu kartu rekaman Knowledge Base (padanan satu baris tabel di web).
class _KbCard extends StatelessWidget {
  const _KbCard({
    required this.entry,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final KbEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BadgePill(
                label: entry.languageLabel,
                tone: BadgePill.toneForLanguage(entry.language),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                tooltip: 'Edit rekaman',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                color: AppColors.textMuted,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Hapus rekaman',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                color: AppColors.textMuted,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry.errorCode,
            style: AppTheme.mono(fontSize: 13, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 5),
          Text(
            entry.title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            entry.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatusButton(active: entry.isActive, onTap: onToggle),
              const SizedBox(width: 8),
              // `Expanded` (bukan `Spacer` + teks mentah): tanggal panjang
              // membuat baris kelebar di layar sempit -> pakai sisanya saja.
              Expanded(
                child: Text(
                  'Diperbarui ${entry.formattedUpdatedAt}',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.mono(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tombol status Aktif/Nonaktif pada kartu — ketuk untuk langsung toggle
/// (meniru tombol status di baris tabel web, `admin/page.tsx:395-407`).
class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.neonGreen : AppColors.textMuted;

    return Tooltip(
      message: active
          ? 'Status: aktif (ketuk untuk menonaktifkan)'
          : 'Status: nonaktif (ketuk untuk mengaktifkan)',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.28)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 7, color: color),
              const SizedBox(width: 5),
              Text(
                active ? 'AKTIF' : 'NONAKTIF',
                style: AppTheme.mono(
                  fontSize: 9.5,
                  letterSpacing: 0.6,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Bagian: state loading, kosong, dan error (bersama kedua tab)
// =============================================================================
class _LoadingHint extends StatelessWidget {
  const _LoadingHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accentPink,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Text(
          message,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 26,
            color: AppColors.neonAmber,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box({required double height}) => Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: AppColors.borderSoft),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: box(height: 112)),
            const SizedBox(width: 12),
            Expanded(child: box(height: 112)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: box(height: 112)),
            const SizedBox(width: 12),
            Expanded(child: box(height: 112)),
          ],
        ),
        const SizedBox(height: 16),
        box(height: 160),
        const SizedBox(height: 16),
        const _LoadingHint('Memuat statistik...'),
      ],
    );
  }
}
