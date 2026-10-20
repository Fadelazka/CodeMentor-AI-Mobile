import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/code_meteors_background.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;
  const ResetPasswordScreen({super.key, this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeoutMs),
      receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeoutMs),
    ),
  );

  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _success = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (widget.token == null || widget.token!.isEmpty) {
      _showMessage('Token reset tidak valid');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await _dio.post(
        '/api/auth/reset-password',
        data: {
          'token': widget.token,
          'password': _passwordController.text,
        },
      );
      if (!mounted) return;
      setState(() => _success = true);
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? (e.response?.data['error'] ??
              e.response?.data['message'] ??
              'Gagal mengatur ulang kata sandi')
          : 'Gagal mengatur ulang kata sandi';
      if (!mounted) return;
      _showMessage(message);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Terjadi kesalahan. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Kata sandi wajib diisi';
    if (password.length < 6) return 'Kata sandi minimal 6 karakter';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value != _passwordController.text) return 'Konfirmasi kata sandi tidak cocok';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.token == null || widget.token!.isEmpty) {
      return Scaffold(
        body: CodeMeteorsBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Tautan tidak valid',
                    style: TextStyle(color: AppColors.foreground, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tautan reset password tidak valid atau tidak lengkap.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: AppTheme.paperButtonStyle,
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('Kembali ke Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_success) {
      return Scaffold(
        body: CodeMeteorsBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green.shade400, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'Kata sandi berhasil diatur ulang',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.foreground, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Silakan masuk dengan kata sandi baru Anda',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: AppTheme.paperButtonStyle,
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('Masuk Sekarang'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: CodeMeteorsBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AppLogo()),
                        const SizedBox(height: 18),
                        Text(
                          'Atur Ulang Kata Sandi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Masukkan kata sandi baru untuk akun Anda',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: 22),
                        TextFormField(
                          controller: _passwordController,
                          validator: _validatePassword,
                          obscureText: !_showPassword,
                          decoration: InputDecoration(
                            labelText: 'Kata Sandi Baru',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmPasswordController,
                          validator: _validateConfirm,
                          obscureText: !_showConfirm,
                          decoration: InputDecoration(
                            labelText: 'Konfirmasi Kata Sandi',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _showConfirm = !_showConfirm),
                              icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          style: AppTheme.paperButtonStyle,
                          onPressed: _isLoading ? null : _handleSubmit,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                                )
                              : const Text('Atur Ulang Kata Sandi'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
