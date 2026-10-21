import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/export_saver.dart';
import '../../../core/theme/app_theme.dart';
import '../data/account_repository.dart';
import '../data/app_settings.dart';
import 'edit_profile_screen.dart';
import 'widgets/change_password_dialog.dart';

/// Halaman "Pengaturan" — padanan `src/app/(app)/pengaturan/page.tsx`.
///
/// Semua preferensi disimpan LOKAL (padanan `localStorage` web), kecuali dua
/// aksi akun yang memanggil server: Ubah Password
/// (`POST /api/auth/change-password`) dan Unduh Data Saya
/// (`GET /api/user/export`).
///
/// Yang benar-benar mengubah aplikasi mobile:
/// - **Ukuran Font Editor** -> editor chat & semua blok kode,
/// - **Bahasa Penjelasan / Tingkat Detail / Auto-save** -> dipakai
///   `POST /api/chat` (lihat `chat_repository.dart`).
///
/// Yang hanya DISIMPAN (sama seperti web yang memaksa mode gelap lewat
/// `SettingsContext`): mode tema & warna aksen — mobile memakai token warna
/// statis `AppColors`, jadi keduanya ditampilkan sebagai keterangan, bukan
/// tombol palsu.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isDownloading = false;

  void _pesan(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  AppSettingsController get _settings =>
      ref.read(appSettingsProvider.notifier);

  Future<void> _resetAll() async {
    await _settings.resetAll();
    if (!mounted) return;
    _pesan('Direset ke default');
  }

  Future<void> _downloadData() async {
    setState(() => _isDownloading = true);
    try {
      final file = await ref.read(accountRepositoryProvider).exportData();
      final message = await ref.read(exportSaverProvider).save(file);
      if (!mounted) return;
      _pesan(message);
    } on AccountException catch (error) {
      if (!mounted) return;
      _pesan(error.message);
    } on ExportException catch (error) {
      if (!mounted) return;
      _pesan(error.message);
    } catch (error) {
      if (!mounted) return;
      _pesan('Gagal mengunduh data.');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _openChangePassword() => showDialog<void>(
    context: context,
    builder: (_) => const ChangePasswordDialog(),
  );

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        18,
        AppSpacing.page,
        28,
      ),
      children: [
        // ==== Kepala halaman ====
        Text('// PENGATURAN', style: AppTheme.monoEyebrow),
        const SizedBox(height: 6),
        const Text(
          'Pengaturan',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Kelola preferensi dan tampilan aplikasi Anda',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: _resetAll,
            style: _outlineStyle(),
            child: const Text('Kembalikan Default'),
          ),
        ),
        const SizedBox(height: 20),

        // ==== Preferensi Tampilan ====
        _Section(
          icon: Icons.palette_outlined,
          title: 'Preferensi Tampilan',
          subtitle: 'Sesuaikan tema dan tampilan aplikasi',
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                border: Border.all(color: AppColors.borderSoft),
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('MODE TAMPILAN', style: AppTheme.monoLabel),
                      const Spacer(),
                      const BadgeText('GELAP AKTIF'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Aplikasi mobile memakai tema gelap CodeMentor secara '
                    'permanen. Pilihan tema terang/sistem dan warna aksen '
                    'hanya berlaku di versi web.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            _OptionGroup(
              label: 'Ukuran Font Editor',
              hint: 'Berlaku untuk editor chat dan semua blok kode.',
              options: const [
                _Option(label: 'Kecil', value: 12),
                _Option(label: 'Sedang', value: 14),
                _Option(label: 'Besar', value: 16),
              ],
              selected: settings.editorFontSize,
              onSelect: (value) =>
                  _settings.setEditorFontSize((value as num).toDouble()),
            ),
          ],
        ),

        // ==== Preferensi AI ====
        _Section(
          icon: Icons.smart_toy_outlined,
          title: 'Preferensi AI',
          subtitle: 'Atur cara AI menjelaskan error',
          children: [
            _OptionGroup(
              label: 'Bahasa Penjelasan',
              options: const [
                _Option(label: 'Bahasa Indonesia', value: 'id'),
                _Option(label: 'English', value: 'en'),
              ],
              selected: settings.aiLanguage,
              onSelect: (value) =>
                  _settings.setAiLanguage(value.toString()),
            ),
            _OptionGroup(
              label: 'Tingkat Detail Jawaban',
              options: const [
                _Option(label: 'Singkat', value: 'brief'),
                _Option(label: 'Sedang', value: 'medium'),
                _Option(label: 'Detail', value: 'detailed'),
              ],
              selected: settings.aiDetailLevel,
              onSelect: (value) =>
                  _settings.setAiDetailLevel(value.toString()),
            ),
            _SwitchRow(
              title: 'Auto-save Chat History',
              description: 'Simpan otomatis riwayat percakapan Anda.',
              value: settings.autoSaveHistory,
              onChanged: _settings.setAutoSaveHistory,
            ),
          ],
        ),

        // ==== Notifikasi ====
        _Section(
          icon: Icons.notifications_none,
          title: 'Notifikasi',
          subtitle: 'Pilih notifikasi email yang ingin Anda terima',
          children: [
            _CheckRow(
              label: 'Error penting',
              value: settings.emailCriticalErrors,
              onChanged: _settings.setEmailCriticalErrors,
            ),
            _CheckRow(
              label: 'Update fitur baru',
              value: settings.emailFeatureUpdates,
              onChanged: _settings.setEmailFeatureUpdates,
            ),
            _CheckRow(
              label: 'Materi rekomendasi mingguan',
              value: settings.emailWeeklyDigest,
              onChanged: _settings.setEmailWeeklyDigest,
            ),
            const Text(
              'Disimpan sebagai preferensi di perangkat ini, sama seperti web.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),

        // ==== Akun ====
        _Section(
          icon: Icons.person_outline,
          title: 'Akun',
          subtitle: 'Kelola keamanan dan data akun Anda',
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                  style: _outlineStyle(),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Edit Profil'),
                ),
                OutlinedButton.icon(
                  onPressed: _openChangePassword,
                  style: _outlineStyle(),
                  icon: const Icon(Icons.key_outlined, size: 17),
                  label: const Text('Ubah Password'),
                ),
                OutlinedButton.icon(
                  onPressed: _isDownloading ? null : _downloadData,
                  style: _outlineStyle(),
                  icon: _isDownloading
                      ? const SizedBox(
                          height: 15,
                          width: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentPink,
                          ),
                        )
                      : const Icon(Icons.download_outlined, size: 17),
                  label: Text(
                    _isDownloading ? 'Mengunduh...' : 'Unduh Data Saya',
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentPink.withValues(alpha: 0.04),
                border: Border.all(
                  color: AppColors.accentPink.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hapus Akun',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tindakan ini permanen dan tidak dapat dibatalkan.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    // Server belum punya endpoint hapus akun (tombol di web
                    // juga belum berfungsi), jadi sengaja dinonaktifkan.
                    onPressed: null,
                    style: _outlineStyle(color: AppColors.neonPink),
                    icon: const Icon(Icons.delete_outline, size: 17),
                    label: const Text('Hapus Akun'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Belum tersedia — di web tombol ini juga belum aktif.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static ButtonStyle _outlineStyle({Color color = AppColors.textPrimary}) =>
      OutlinedButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
      );
}

// =============================================================================
// Komponen bagian
// =============================================================================
/// Satu kartu bagian (padanan kartu `rounded-xl border` di web).
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.panelDecoration(color: AppColors.surface1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: AppColors.accentPink.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Icon(icon, size: 19, color: AppColors.accentPink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(height: 16),
            children[index],
          ],
        ],
      ),
    );
  }
}

/// Satu pilihan pada grup (nilainya bisa String atau num).
class _Option {
  const _Option({required this.label, required this.value});

  final String label;
  final Object value;
}

class _OptionGroup extends StatelessWidget {
  const _OptionGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.hint,
  });

  final String label;
  final String? hint;
  final List<_Option> options;
  final Object selected;
  final ValueChanged<Object> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(
            hint!,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              _OptionChip(
                label: option.label,
                active: option.value == selected,
                onTap: () => onSelect(option.value),
              ),
          ],
        ),
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? AppColors.accentPink.withValues(alpha: 0.1)
          : AppColors.surface2,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: active ? AppColors.accentPink : AppColors.textPrimary.withValues(alpha: 0.12),
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: active ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.accentPink,
        ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: value,
                onChanged: (next) => onChanged(next ?? false),
                activeColor: AppColors.accentPink,
                checkColor: Colors.white,
                side: const BorderSide(color: AppColors.inputBorder, width: 1.5),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge teks kecil untuk nilai yang dikunci.
class BadgeText extends StatelessWidget {
  const BadgeText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.accentPink.withValues(alpha: 0.12),
      border: Border.all(
        color: AppColors.accentPink.withValues(alpha: 0.28),
      ),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: AppTheme.mono(
        fontSize: 9.5,
        letterSpacing: 0.6,
        color: AppColors.accentPink,
      ),
    ),
  );
}
