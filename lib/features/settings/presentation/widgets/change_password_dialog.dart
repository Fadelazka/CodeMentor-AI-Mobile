import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/account_repository.dart';

/// Dialog "Ubah Password" — padanan
/// `src/components/settings/change-password-modal.tsx`.
///
/// Alur:
/// 1. validasi lokal (sama persis dengan web),
/// 2. `POST /api/auth/change-password`,
/// 3. bila berhasil: tampilkan konfirmasi, lalu user menekan "Masuk Ulang"
///    (sesi lama tidak valid lagi karena kata sandi berubah).
class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isLoading = false;
  bool _success = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentController.text;
    final next = _newController.text;
    final confirm = _confirmController.text;

    // Validasi sama seperti web (server memvalidasi ulang).
    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Semua field wajib diisi');
      return;
    }
    if (next.length < 6) {
      setState(() => _error = 'Password baru minimal 6 karakter');
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'Konfirmasi password tidak cocok');
      return;
    }
    if (current == next) {
      setState(() => _error = 'Password baru harus berbeda dengan yang lama');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref
          .read(accountRepositoryProvider)
          .changePassword(currentPassword: current, newPassword: next);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _success = true;
      });
    } on AccountException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Terjadi kesalahan. Coba lagi.';
      });
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    if (!mounted) return;
    Navigator.of(context).pop();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface2,
      title: const Text('Ubah Password'),
      content: SingleChildScrollView(
        child: _success ? _SuccessBody(onSignOut: _signOut) : _buildForm(),
      ),
      actions: _success
          ? null
          : [
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
              FilledButton(
                style: AppTheme.paperButtonStyle.copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 42)),
                ),
                onPressed: _isLoading ? null : _submit,
                child: Text(_isLoading ? 'Menyimpan...' : 'Simpan Password'),
              ),
            ],
    );
  }

  Widget _buildForm() {
    final newLength = _newController.text.length;
    final mismatch =
        _confirmController.text.isNotEmpty &&
        _newController.text != _confirmController.text;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ganti password akun Anda',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentPink.withValues(alpha: 0.1),
              border: Border.all(
                color: AppColors.accentPink.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 16,
                  color: AppColors.accentPink,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.accentPink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _PasswordField(
          label: 'Password Lama',
          controller: _currentController,
          hint: 'Masukkan password lama',
          visible: _showCurrent,
          enabled: !_isLoading,
          onToggle: () => setState(() => _showCurrent = !_showCurrent),
        ),
        const SizedBox(height: 4),
        _PasswordField(
          label: 'Password Baru',
          controller: _newController,
          hint: 'Minimal 6 karakter',
          visible: _showNew,
          enabled: !_isLoading,
          onChanged: (_) => setState(() {}),
          onToggle: () => setState(() => _showNew = !_showNew),
        ),
        if (newLength > 0 && newLength < 6)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Minimal 6 karakter ($newLength/6)',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.neonAmber,
              ),
            ),
          ),
        const SizedBox(height: 4),
        _PasswordField(
          label: 'Konfirmasi Password Baru',
          controller: _confirmController,
          hint: 'Ulangi password baru',
          visible: _showConfirm,
          enabled: !_isLoading,
          onChanged: (_) => setState(() {}),
          onToggle: () => setState(() => _showConfirm = !_showConfirm),
        ),
        if (mismatch)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Konfirmasi tidak cocok',
              style: TextStyle(fontSize: 11.5, color: AppColors.accentPink),
            ),
          ),
      ],
    );
  }
}

/// Isi dialog setelah kata sandi berhasil diubah.
class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: AppColors.neonGreen.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline,
            size: 32,
            color: AppColors.neonGreen,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Password Berhasil Diubah',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sesi lama akan diakhiri karena kata sandi sudah berubah. '
          'Silakan masuk kembali dengan kata sandi baru Anda.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: AppTheme.paperButtonStyle.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size.fromHeight(46)),
            ),
            onPressed: onSignOut,
            child: const Text('Masuk Ulang'),
          ),
        ),
      ],
    );
  }
}

/// Satu kolom kata sandi dengan tombol lihat/sembunyikan.
class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.visible,
    required this.enabled,
    required this.onToggle,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool visible;
  final bool enabled;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(label.toUpperCase(), style: AppTheme.monoLabel),
        ),
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: !visible,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            fillColor: AppColors.inputBg,
            isDense: true,
            suffixIcon: IconButton(
              onPressed: onToggle,
              tooltip: visible ? 'Sembunyikan' : 'Tampilkan',
              iconSize: 18,
              color: AppColors.textMuted,
              icon: Icon(
                visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
