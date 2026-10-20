import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/code_meteors_background.dart';
import '../data/auth_repository.dart';

class GithubAuthScreen extends ConsumerStatefulWidget {
  const GithubAuthScreen({super.key});

  @override
  ConsumerState<GithubAuthScreen> createState() => _GithubAuthScreenState();
}

class _GithubAuthScreenState extends ConsumerState<GithubAuthScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startGithubAuth();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startGithubAuth() async {
    try {
      final base = ApiConstants.baseUrl;
      final url =
          '$base/api/auth/signin/github?callbackUrl=codementor://auth-callback';

      await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: 'codementor',
        options: const FlutterWebAuth2Options(
          preferEphemeral: true,
        ),
      );

      await ref.read(authRepositoryProvider).fetchSession();
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('canceled') || errorStr.contains('cancelled') || errorStr.contains('user_cancelled')) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = 'Login GitHub dibatalkan';
        });
        context.go(AppRoutes.login);
        return;
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      _showMessage('Terjadi kesalahan saat GitHub OAuth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CodeMeteorsBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(),
              const SizedBox(height: 20),
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Memproses login GitHub...',
                  style: TextStyle(color: AppColors.mutedForeground),
                ),
              ] else ...[
                Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
                const SizedBox(height: 16),
                Text(
                  'GitHub OAuth gagal',
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  style: AppTheme.paperButtonStyle,
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Kembali ke Login'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
