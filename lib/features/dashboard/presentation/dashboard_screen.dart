import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../auth/data/auth_snapshot.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_stats.dart';

/// Layar Dashboard — padanan `src/app/(app)/dashboard/page.tsx`.
///
/// Dashboard HANYA untuk admin (sama seperti web: non-admin dialihkan ke
/// `/chat` — lihat `src/app/(app)/dashboard/page.tsx:87`). Aturan itu dijaga
/// `redirect` di `app_router.dart`, jadi layar ini selalu dirender untuk admin
/// dan memakai `GET /api/admin/stats`.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSnapshotProvider).session?.user;
    final isAdmin = user?.isAdmin == true;
    final statsAsync = ref.watch(dashboardStatsProvider);
    final statsError = statsAsync.error;

    final name = user?.name?.trim() ?? '';
    final firstName = name.isEmpty ? 'Sobat CodeMentor' : name.split(' ').first;

    // Top bar + drawer disediakan `AppShell` (Fase 1); layar ini hanya isi
    // halaman, sesuai pola `(app)/layout.tsx` di web.
    return RefreshIndicator(
        color: AppColors.accentPink,
        backgroundColor: AppColors.surface2,
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          await ref.read(dashboardStatsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            _Header(firstName: firstName, isAdmin: isAdmin),

            if (isAdmin) ...[
              const SizedBox(height: 14),
              _AdminMetaRow(stats: statsAsync.asData?.value),
            ],

            const SizedBox(height: 20),

            // ==== Isi statistik: loading / error / data ====
            //
            // CATATAN (Riverpod 3): provider yang gagal akan di-RETRY otomatis
            // (default 10x dengan backoff 200ms..6,4s). Selama retry berjalan
            // state kembali ber-`isLoading` sambil tetap menyimpan error,
            // sehingga `AsyncValue.when` memilih cabang `loading` walau error
            // sudah ada (panel error tidak pernah muncul). Karena itu cabang
            // ditentukan berurutan:
            //   ada error & belum ada data -> panel error (tetap tampil walau
            //                                 retry sedang berjalan),
            //   ada data                   -> konten statistik,
            //   selain itu                 -> skeleton.
            if (statsAsync.hasError && !statsAsync.hasValue)
              _ErrorPanel(
                message: statsError is DashboardException
                    ? statsError.message
                    : 'Terjadi kesalahan saat mengambil statistik.',
                onRetry: () => ref.invalidate(dashboardStatsProvider),
              )
            else if (statsAsync.hasValue)
              _DashboardContent(stats: statsAsync.value!)
            else
              const _DashboardSkeleton(),
          ],
        ),
    );
  }
}

// =============================================================================
// Bagian: header
// =============================================================================
class _Header extends StatelessWidget {
  const _Header({required this.firstName, required this.isAdmin});

  final String firstName;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DASHBOARD', style: AppTheme.monoEyebrow),
        const SizedBox(height: 8),
        Text(
          'Selamat datang kembali, $firstName.',
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isAdmin
              ? 'Pantau aktivitas pengguna CodeMentor AI secara real-time.'
              : 'Begini progres belajar debugging Anda. Semangat terus.',
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        GradientButton(
          label: 'Tanya Error Baru',
          icon: Icons.add_comment_outlined,
          onPressed: () => context.go(AppRoutes.chat),
        ),
      ],
    );
  }
}

/// Chip info khusus admin (total user & user aktif 7 hari).
class _AdminMetaRow extends StatelessWidget {
  const _AdminMetaRow({required this.stats});

  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    final meta = stats?.meta;
    if (meta == null) return const SizedBox.shrink();

    return Wrap(
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

// =============================================================================
// Bagian: konten utama
// =============================================================================
class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        label: stats.isAdminView
            ? 'TOTAL PERTANYAAN (SEMUA USER)'
            : 'TOTAL PERTANYAAN',
        value: '${stats.totalQuestions}',
        icon: stats.isAdminView ? Icons.people_alt : Icons.forum_outlined,
        color: AppColors.neonCyan,
      ),
      (
        label: 'AKURASI AI',
        value: stats.formattedAccuracy,
        icon: Icons.trending_up,
        color: AppColors.neonGreen,
      ),
      (
        label: 'WAKTU RESPONS',
        value: stats.formattedResponseTime,
        icon: Icons.timer_outlined,
        color: AppColors.neonViolet,
      ),
      (
        label: stats.isAdminView
            ? 'ERROR DIPECAHKAN (GLOBAL)'
            : 'ERROR DIPECAHKAN',
        value: '${stats.errorsSolved}',
        icon: Icons.menu_book_outlined,
        color: AppColors.neonPink,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ==== Kartu statistik (2 x 2) ====
        Row(
          children: [
            Expanded(child: _StatCard(data: metrics[0])),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(data: metrics[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(data: metrics[2])),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(data: metrics[3])),
          ],
        ),
        const SizedBox(height: 20),

        if (!stats.hasActivity)
          const _EmptyActivityPanel()
        else ...[
          _UsagePanel(data: stats.usagePerDay),
          const SizedBox(height: 16),
          if (stats.usageByLanguage.isNotEmpty)
            _LanguagePanel(usage: stats.usageByLanguage),
          if (stats.usageByLanguage.isNotEmpty) const SizedBox(height: 16),
          _RecentActivityPanel(items: stats.recentActivity),
        ],
      ],
    );
  }
}

typedef _MetricData = ({
  String label,
  String value,
  IconData icon,
  Color color,
});

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _MetricData data;

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
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Icon(data.icon, size: 17, color: data.color),
          ),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
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

/// Kartu seragam ala `GlassCard` web.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          if (title != null) const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Grafik batang 14 hari terakhir (pengganti recharts di web).
class _UsagePanel extends StatelessWidget {
  const _UsagePanel({required this.data});

  final List<DailyUsage> data;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Aktivitas 14 Hari',
      subtitle: 'Jumlah konsultasi error per hari',
      child: data.isEmpty
          ? const _PanelHint('Belum ada data harian.')
          : _UsageBarChart(data: data),
    );
  }
}

class _UsageBarChart extends StatelessWidget {
  const _UsageBarChart({required this.data});

  final List<DailyUsage> data;

  @override
  Widget build(BuildContext context) {
    final maxCount = data.fold<int>(
      0,
      (max, item) => item.count > max ? item.count : max,
    );

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < data.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: maxCount == 0
                          ? 4
                          : 6 + (data[i].count / maxCount) * 100,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Label tanggal hanya untuk batang GANJIL supaya tidak padat.
                    Text(
                      i.isEven ? data[i].shortLabel : '',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: AppTheme.mono(
                        fontSize: 8,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Distribusi bahasa (bar horizontal, mirip pie chart di web).
class _LanguagePanel extends StatelessWidget {
  const _LanguagePanel({required this.usage});

  final Map<String, int> usage;

  @override
  Widget build(BuildContext context) {
    final total = usage.values.fold<int>(0, (sum, value) => sum + value);
    final entries = usage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _Panel(
      title: 'Bahasa yang Digunakan',
      subtitle: 'Distribusi konsultasi per bahasa',
      child: Column(
        children: [
          for (final entry in entries) ...[
            _LanguageBar(
              language: entry.key,
              count: entry.value,
              total: total,
            ),
            if (entry != entries.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _LanguageBar extends StatelessWidget {
  const _LanguageBar({
    required this.language,
    required this.count,
    required this.total,
  });

  final String language;
  final int count;
  final int total;

  /// Warna badge per bahasa — sama dengan `langTone` di web.
  static const Map<String, Color> _tones = {
    'python': AppColors.neonCyan,
    'javascript': AppColors.neonAmber,
    'java': AppColors.neonViolet,
    'cpp': AppColors.neonPink,
    'php': AppColors.neonGreen,
  };

  @override
  Widget build(BuildContext context) {
    final color = _tones[language] ?? AppColors.textSecondary;
    final ratio = total == 0 ? 0.0 : count / total;
    final label = ApiConstants.languageLabels[language] ?? language;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '$count · ${(ratio * 100).round()}%',
              style: AppTheme.mono(
                fontSize: 10,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 6,
            color: AppColors.borderSoft,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio == 0 ? 0.02 : ratio,
              child: Container(color: color),
            ),
          ),
        ),
      ],
    );
  }
}

/// Daftar aktivitas terakhir (versi mobile dari tabel di web).
class _RecentActivityPanel extends StatelessWidget {
  const _RecentActivityPanel({required this.items});

  final List<RecentActivity> items;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Aktivitas Terakhir',
      subtitle: 'Riwayat interaksi terbaru',
      trailing: TextButton(
        onPressed: () => context.go(AppRoutes.history),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentPink,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          children: const [
            Text(
              'Lihat semua',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_outward, size: 14),
          ],
        ),
      ),
      child: items.isEmpty
          ? const _PanelHint('Belum ada aktivitas terbaru.')
          : Column(
              children: [
                for (final item in items) ...[
                  _ActivityRow(item: item),
                  if (item != items.last)
                    const Divider(
                      height: 20,
                      thickness: 1,
                      color: AppColors.borderSoft,
                    ),
                ],
              ],
            ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final RecentActivity item;

  @override
  Widget build(BuildContext context) {
    final confidence = item.confidence;
    final confidenceColor = (confidence ?? 0) >= 85
        ? AppColors.neonGreen
        : AppColors.neonAmber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                ApiConstants.languageLabels[item.language] ?? item.language,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (confidence != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: confidenceColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$confidence%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: confidenceColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          item.errorCode ?? 'Tanpa error code',
          style: AppTheme.mono(
            fontSize: 11,
            letterSpacing: 0.2,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          item.formattedDate,
          style: AppTheme.mono(
            fontSize: 10,
            letterSpacing: 0.2,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _EmptyActivityPanel extends StatelessWidget {
  const _EmptyActivityPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.insights_outlined,
            size: 26,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 10),
          const Text(
            'Belum ada aktivitas',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Mulai konsultasikan error kodemu — statistik akan muncul di sini.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          GradientButton(
            label: 'Mulai Chat',
            icon: Icons.forum_outlined,
            onPressed: () => context.go(AppRoutes.chat),
          ),
        ],
      ),
    );
  }
}

class _PanelHint extends StatelessWidget {
  const _PanelHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
  );
}

// =============================================================================
// Bagian: state loading & error
// =============================================================================
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(child: _SkeletonBox(height: 112)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonBox(height: 112)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: _SkeletonBox(height: 112)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonBox(height: 112)),
          ],
        ),
        const SizedBox(height: 20),
        const _SkeletonBox(height: 190),
        const SizedBox(height: 16),
        const _SkeletonBox(height: 140),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surface2,
      border: Border.all(color: AppColors.borderSoft),
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 26,
            color: AppColors.neonAmber,
          ),
          const SizedBox(height: 10),
          const Text(
            'Gagal memuat statistik',
            style: TextStyle(
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
