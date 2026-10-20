import 'package:flutter/material.dart';
import 'package:flutter_next_auth_riverpod/next_auth_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/domain/app_session.dart';

void main() {
  // SATU instance NextAuthClient untuk seluruh aplikasi, dipakai bersama oleh:
  // - NextAuthRiverpodScope  -> menyediakan status/sesi yang reaktif
  // - authRepositoryProvider -> login, logout, dan pengambilan cookie sesi
  final client = AuthRepository.createNextAuthClient();

  runApp(
    ProviderScope(
      overrides: [nextAuthClientProvider.overrideWithValue(client)],
      child: NextAuthRiverpodScope<AppSession>(
        client: client,
        // Satuan milidetik. Berguna agar sesi di-refresh berkala dan juga saat
        // aplikasi kembali ke layar depan (paket akan refetch saat resume).
        refetchInterval: 900000, // 15 menit
        child: const CodeMentorApp(),
      ),
    ),
  );
}

/// Akar aplikasi: menyiapkan tema dan router.
class CodeMentorApp extends ConsumerWidget {
  const CodeMentorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PENTING: dibaca di dalam widget tree (bukan dari ProviderContainer luar)
    // supaya `statusProvider` yang dipakai router melihat NextAuthClient yang
    // di-override oleh NextAuthRiverpodScope di atasnya.
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'CodeMentor AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
