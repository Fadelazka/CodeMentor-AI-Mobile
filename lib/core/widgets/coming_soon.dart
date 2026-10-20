import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Placeholder untuk tab/fitur yang belum diimplementasikan.
///
/// Dipakai Step 2 untuk tab "Chat AI" dan "Riwayat" yang UI-nya menyusul
/// (Step 3 dan Step 5), supaya bottom navigation sudah bisa dinavigasi.
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.auto_awesome,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.panelDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'SEGERA HADIR',
                style: AppTheme.mono(
                  fontSize: 10,
                  letterSpacing: 1.6,
                  color: AppColors.accentPink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
