import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/code_meteors_background.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeoutMs),
      receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeoutMs),
    ),
  );

  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
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

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await _dio.post(
        '/api/auth/forgot-password',
        data: {'email': _emailController.text.trim().toLowerCase()},
      );
      if (!mounted) return;
      setState(() => _sent = true);
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? (e.response?.data['error'] ??
              e.response?.data['message'] ??
              'Gagal mengirim tautan reset')
          : 'Gagal mengirim tautan reset';
      if (!mounted) return;
      _showMessage(message);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Terjadi kesalahan. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Email wajib diisi';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CodeMeteorsBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _sent ? _buildSuccess() : _buildForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AppLogo()),
          const SizedBox(height: 18),
          Icon(Icons.check_circle_outline, size: 56, color: Colors.green.shade400),
          const SizedBox(height: 16),
          Text(
            'Tautan dikirim',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Jika email terdaftar, tautan untuk mengatur ulang kata sandi telah dikirim ke kotak masuk email Anda. Silakan periksa folder Spam jika tidak menemukannya.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.mutedForeground,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            style: AppTheme.paperButtonStyle,
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Kembali ke Halaman Masuk'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
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
              'Lupa Kata Sandi?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Masukkan email Anda dan kami akan mengirimkan tautan untuk mengatur ulang kata sandi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _emailController,
              validator: _validateEmail,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
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
                  : const Text('Kirim Tautan Reset'),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_back, size: 16, color: AppColors.mutedForeground),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => context.go(AppRoutes.login),
                  child: Text(
                    'Kembali ke halaman masuk',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


