import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/admin_user.dart';
import '../data/admin_users_controller.dart';
import '../data/admin_users_repository.dart';
import 'widgets/admin_form_fields.dart';

/// Form tambah/edit user (padanan `UserModal` di web).
class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({super.key, this.user});

  /// `null` = tambah user baru; terisi = edit user lama.
  final AdminUser? user;

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  String _role = 'USER';
  bool _saving = false;
  String? _serverError;
  Map<String, String> _errors = const {};

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _passwordController = TextEditingController();
    _role = user?.role == 'ADMIN' ? 'ADMIN' : 'USER';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validate() {
    final draft = _draft();
    setState(() {
      _errors = draft.validateFields(isNew: !_isEdit);
      _serverError = null;
    });
  }

  AdminUserDraft _draft() {
    return AdminUserDraft(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      role: _role,
    );
  }

  Future<void> _save() async {
    _validate();
    final firstError = _draft().validate(isNew: !_isEdit);
    if (firstError != null) {
      return;
    }

    setState(() {
      _saving = true;
      _serverError = null;
    });

    try {
      final notifier = ref.read(adminUsersProvider.notifier);
      final result = _isEdit
          ? await notifier.updateUser(widget.user!.id, _draft())
          : await notifier.create(_draft());
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on AdminUserException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverError = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit User' : 'Tambah User'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          16,
          AppSpacing.page,
          28,
        ),
        children: [
          const Text(
            'Isi detail akun pengguna CodeMentor AI.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (_serverError != null) ...[
            const SizedBox(height: 14),
            ServerErrorBox(message: _serverError!),
          ],
          const SizedBox(height: 16),
          FieldTextInput(
            label: 'Nama Lengkap',
            hint: 'contoh: Budi Santoso',
            controller: _nameController,
            error: _errors['name'],
            enabled: !_saving,
            onChanged: (_) => _validate(),
          ),
          const SizedBox(height: 14),
          FieldTextInput(
            label: 'Email',
            hint: 'nama@example.com',
            controller: _emailController,
            error: _errors['email'],
            enabled: !_saving,
            onChanged: (_) => _validate(),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          FieldTextInput(
            label: 'Password',
            hint: _isEdit
                ? 'Kosongkan jika tidak ingin ubah'
                : 'Minimal 6 karakter',
            controller: _passwordController,
            error: _errors['password'],
            enabled: !_saving,
            onChanged: (_) => _validate(),
            obscureText: true,
            showRequired: _isEdit ? false : true,
          ),
          const SizedBox(height: 14),
          FieldLabel('Role', error: _errors['role']),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg - 2),
              border: Border.all(
                color: _errors['role'] != null
                    ? AppColors.accentPink
                    : AppColors.borderSoft,
              ),
            ),
            child: DropdownButton<String>(
              value: _role,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: AppColors.surface2,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textPrimary,
              ),
              items: const [
                DropdownMenuItem(value: 'USER', child: Text('USER')),
                DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _role = value);
                      _validate();
                    },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            10,
            AppSpacing.page,
            14,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.inputBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    minimumSize: const Size(0, 46),
                  ),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: AppTheme.paperButtonStyle.copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving
                        ? 'Menyimpan...'
                        : _isEdit
                            ? 'Simpan Perubahan'
                            : 'Simpan',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
