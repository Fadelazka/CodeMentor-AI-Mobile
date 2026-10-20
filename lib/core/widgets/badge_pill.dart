import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Warna badge — meniru prop `tone` pada
/// `src/components/ui/badge-pill.tsx`.
enum BadgeTone { neutral, pink, cyan, violet, green, amber, red }

/// Badge kecil bergaya web: teks mono uppercase di dalam kapsul dengan latar
/// aksen tipis (mis. label bahasa, error code, confidence).
class BadgePill extends StatelessWidget {
  const BadgePill({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
  });

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  /// Tone badge untuk sebuah bahasa — salinan `langTone` di web
  /// (`src/app/(app)/riwayat/page.tsx:16-22`).
  static BadgeTone toneForLanguage(String language) => switch (language) {
    'python' => BadgeTone.cyan,
    'javascript' => BadgeTone.amber,
    'java' => BadgeTone.violet,
    'cpp' => BadgeTone.pink,
    'php' => BadgeTone.green,
    _ => BadgeTone.neutral,
  };

  /// Tone untuk nilai confidence (web: hijau bila >= 85%, selain itu kuning).
  static BadgeTone toneForConfidence(int confidence) =>
      confidence >= 85 ? BadgeTone.green : BadgeTone.amber;

  static Color colorOf(BadgeTone tone) => switch (tone) {
    BadgeTone.neutral => AppColors.textSecondary,
    BadgeTone.pink => AppColors.neonPink,
    BadgeTone.cyan => AppColors.neonCyan,
    BadgeTone.violet => AppColors.neonViolet,
    BadgeTone.green => AppColors.neonGreen,
    BadgeTone.amber => AppColors.neonAmber,
    BadgeTone.red => AppColors.destructive,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(tone);

    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 9 : 7, 4, 9, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTheme.mono(
              fontSize: 9.5,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
