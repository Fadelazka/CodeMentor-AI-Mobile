import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/code_meteors_background.dart';
import '../data/auth_repository.dart';

/// Halaman login mobile — meniru desain `src/app/(public)/masuk/page.tsx` di web.
///
/// - Login memakai CredentialsProvider (email + kata sandi).
/// - Tombol GitHub mengarahkan ke alur OAuth GitHub.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

    final result = await ref
        .read(authRepositoryProvider)
        .signInWithCredentials(
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.ok) {
      // Pesan dari AuthResult (mis. "Email atau kata sandi salah.").
      _showMessage(result.message ?? 'Login gagal. Coba lagi.');
      return;
    }

    // Status sesi sudah menjadi `authenticated` di titik ini. Splash dipakai
    // sebagai "titik netral": redirect router yang menentukan halaman awal
    // sesuai peran (admin -> /dashboard, user biasa -> /chat).
    _showMessage('Berhasil masuk! Selamat belajar debugging.');
    context.go(AppRoutes.splash);
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Email wajib diisi';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  String? _validatePassword(String? value) =>
      (value ?? '').isEmpty ? 'Kata sandi wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CodeMeteorsBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 28,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _buildCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: AppLogo(size: 40, showText: true)),
            const SizedBox(height: 22),
            const Text(
              'Selamat Datang Kembali',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Masuk untuk melanjutkan sesi belajar debugging Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 26),

            // ===== Email =====
            const _FieldLabel('Email'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'email@example.com',
                prefixIcon: Icon(Icons.mail_outline, size: 18),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),

            // ===== Kata sandi =====
            const _FieldLabel('Kata sandi'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline, size: 18),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  tooltip: _showPassword
                      ? 'Sembunyikan kata sandi'
                      : 'Tampilkan kata sandi',
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                ),
              ),
              validator: _validatePassword,
              onFieldSubmitted: (_) => _handleSubmit(),
            ),
            const SizedBox(height: 10),

            // ===== Ingat saya & lupa kata sandi (mirip web) =====
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (value) =>
                      setState(() => _rememberMe = value ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Ingat saya',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.forgotPassword),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.foreground,
                    minimumSize: const Size(0, 32),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Lupa kata sandi?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ===== Tombol masuk (putih ala web: dark:bg-paper dark:text-ink) ====
            FilledButton(
              style: AppTheme.paperButtonStyle,
              onPressed: _isLoading ? null : _handleSubmit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.ink,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login, size: 18),
                        SizedBox(width: 8),
                        Text('Masuk'),
                      ],
                    ),
            ),
            const SizedBox(height: 22),

            // ===== Pembatas =====
            Row(
              children: [
                const Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ATAU LANJUTKAN DENGAN',
                    style: _dividerTextStyle,
                  ),
                ),
                const Expanded(child: Divider(color: AppColors.border)),
              ],
            ),
            const SizedBox(height: 16),

            // ===== Tombol GitHub (OAuth) =====
            OutlinedButton.icon(
              onPressed: _isLoading ? null : () => context.push(AppRoutes.githubAuth),
              icon: const Icon(Icons.code, size: 18),
              label: const Text('Masuk dengan GitHub'),
            ),
            const SizedBox(height: 22),

            // ===== Footer =====
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Belum punya akun? ',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go(AppRoutes.register),
                  child: const Text(
                    'Daftar gratis',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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

final TextStyle _dividerTextStyle = AppTheme.mono(
  fontSize: 10,
  letterSpacing: 1.1,
  color: AppColors.mutedForeground,
);

/// Label kecil bergaya font-mono uppercase, seperti di form web.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: AppTheme.monoLabel);
}

/// Latar dekoratif: gradien gelap + pendar warna aksen (pengganti

