import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/code_meteors_background.dart';
import '../../auth/data/auth_snapshot.dart';

class QuizResultScreen extends ConsumerWidget {
  const QuizResultScreen({
    super.key,
    required this.score,
    required this.preference,
  });

  final int score;
  final String preference;

  String get _preferenceLabel {
    switch (preference) {
      case 'brief':
        return 'Singkat';
      case 'detailed':
        return 'Detail';
      default:
        return 'Sedang';
    }
  }

  String get _preferenceDesc {
    switch (preference) {
      case 'brief':
        return 'Berdasarkan hasil kuis, AI akan memberikan jawaban yang lebih singkat dan langsung ke inti solusi untukmu.';
      case 'detailed':
        return 'Berdasarkan hasil kuis, AI akan memberikan jawaban yang lebih detail dengan penjelasan, konsep, dan contoh terkait untukmu.';
      default:
        return 'Berdasarkan hasil kuis, AI akan memberikan jawaban yang seimbang sesuai kebutuhan belajarmu.';
    }
  }

  void _goToHome(BuildContext context, WidgetRef ref) {
    final snapshot = ref.read(authSnapshotProvider);
    final isAdmin = snapshot.session?.user.isAdmin == true;
    context.go(isAdmin ? AppRoutes.dashboard : AppRoutes.chat);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final correct = (score / 100 * 7).round();

    return Scaffold(
      body: CodeMeteorsBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogo(),
                      const SizedBox(height: 24),
                      Icon(Icons.emoji_events, size: 64, color: Colors.amber.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Kuis Selesai!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Skor Akhir',
                        style: TextStyle(color: AppColors.mutedForeground),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$correct dari 7 jawaban benar',
                        style: TextStyle(color: AppColors.mutedForeground),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Kategori Preferensi AI: $_preferenceLabel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.foreground,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _preferenceDesc,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.mutedForeground),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: AppTheme.paperButtonStyle,
                          onPressed: () => _goToHome(context, ref),
                          child: const Text('Mulai Belajar'),
                        ),
                      ),
                    ],
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
