import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tombol CTA dengan gradien brand — meniru `GradientButton` di web
/// (`src/components/ui/gradient-button.tsx`):
/// `bg-[linear-gradient(135deg,#FF3B6B,#FF6B35)]` + teks putih.
///
/// Dipakai untuk aksi utama di area aplikasi (mis. "Tanya Error Baru",
/// "Mulai Kuis", tombol kirim di chat), BUKAN untuk tombol primer halaman
/// publik yang berwarna putih (`AppTheme.paperButtonStyle`).
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expand = false,
    this.height = 46,
    this.radius = AppTheme.radiusLg,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
  });

  /// Teks tombol.
  final String label;

  /// Ikon opsional di kiri label.
  final IconData? icon;

  /// Aksi saat ditekan. `null` membuat tombol nonaktif.
  final VoidCallback? onPressed;

  /// Menampilkan spinner dan menonaktifkan tombol.
  final bool loading;

  /// true bila lebar tombol mengikuti lebar induknya.
  final bool expand;

  final double height;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.accentPink.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(radius),
            child: Container(
              height: height,
              padding: padding,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, size: 18, color: Colors.white),
                  if (icon != null || loading) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
