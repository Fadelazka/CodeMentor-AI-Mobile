import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/auth_snapshot.dart';

/// Tab Profil: identitas user, ringkasan status onboarding, dan tombol keluar.
///
/// Isinya memindahkan fitur yang sebelumnya ada di halaman placeholder
/// (`features/chat/presentation/home_screen.dart`) ke tempat yang benar sesuai
/// struktur navigasi web (Profil ada di bagian bawah sidebar).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Kamu perlu masuk lagi untuk melanjutkan sesi belajar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: AppTheme.accentButtonStyle.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(authRepositoryProvider).signOut();
    if (context.mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSnapshotProvider).session?.user;
    final name = user?.name?.trim().isNotEmpty == true
        ? user!.name!.trim()
        : 'Sobat CodeMentor';
    final initial = name.isEmpty ? 'C' : initialOf(name);

    // Top bar + drawer disediakan `AppShell` (Fase 1).
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
          // ==== Kartu identitas ====
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppTheme.panelDecoration(),
            child: Column(
              children: [
                Container(
                  height: 64,
                  width: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.name ?? 'Pengguna CodeMentor',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '-',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentPink.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppColors.accentPink.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    user?.isAdmin == true ? 'ADMIN' : 'MAHASISWA',
                    style: AppTheme.mono(
                      fontSize: 10,
                      letterSpacing: 1,
                      color: AppColors.accentPink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ==== Ringkasan akun ====
          _SectionCard(
            title: 'Data Akademik & Preferensi',
            children: [
              _InfoRow(label: 'NIM', value: user?.nim ?? 'belum diisi'),
              const Divider(height: 18, color: AppColors.borderSoft),
              _InfoRow(
                label: 'Bahasa favorit',
                value: user?.favoriteLanguage ?? 'belum dipilih',
              ),
              const Divider(height: 18, color: AppColors.borderSoft),
              _InfoRow(
                label: 'Kuis onboarding',
                value: user?.hasCompletedQuiz == true
                    ? 'sudah selesai'
                    : 'belum selesai',
              ),
            ],
          ),
          const SizedBox(height: 16),

          _MenuTile(
            icon: Icons.history,
            label: 'Riwayat konsultasi',
            onTap: () => context.go(AppRoutes.history),
          ),
          const SizedBox(height: 8),
          _MenuTile(
            icon: Icons.tune,
            label: 'Preferensi gaya AI',
            onTap: () => context.go(AppRoutes.settings),
          ),
          const SizedBox(height: 8),
          _MenuTile(
            icon: Icons.help_outline,
            label: 'Bantuan & tentang aplikasi',
            onTap: () => _showMessage(
              context,
              'CodeMentor AI — asisten debugging untuk pelajar dan mahasiswa.',
            ),
          ),
          const SizedBox(height: 24),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentPink,
              side: BorderSide(
                color: AppColors.accentPink.withValues(alpha: 0.5),
              ),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
            ),
            onPressed: () => _handleSignOut(context, ref),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Keluar dari akun'),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'CodeMentor AI · versi mobile',
              style: AppTheme.mono(
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Inisial dari nama user (huruf pertama) untuk avatar.
String initialOf(String name) => name.isEmpty ? '?' : name[0].toUpperCase();

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderSoft),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel berjudul kecil untuk blok info profil.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: AppTheme.panelDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: AppTheme.monoLabel),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}
