import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../data/auth_repository.dart';

/// Layar pembuka.
///
/// Bukan sekadar animasi loading: paket next-auth mengembalikan status
/// `initial` bila belum ada token tersimpan di perangkat, dan status itu TIDAK
/// berubah dengan sendirinya. Karena itu di sini kita paksa pengecekan sesi
/// (`fetchSession()`), agar status menjadi `authenticated` atau
/// `unauthenticated` sehingga router bisa menentukan arah halaman.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  Future<void> _checkSession() async {
    if (!mounted) return;
    await ref.read(authRepositoryProvider).fetchSession();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 56, showText: true),
            SizedBox(height: 32),
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 16),
            Text(
              'Memeriksa sesi...',
              style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}
