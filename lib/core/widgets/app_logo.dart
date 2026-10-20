import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Logo CodeMentor AI versi mobile — peniruan `LogoMark` di web
/// (`src/components/brand/logo-mark.tsx`): kotak gelap dengan BORDER gradien
/// brand, tanda `<` `>` bergradien, dan garis miring `/` cyan.
///
/// Tulisan "CodeMentor AI" memakai font display web (Space Grotesk) dengan
/// "Mentor" berwarna aksen crimson, seperti di halaman publik.
///
/// Kalau nanti sudah ada aset logo resmi (SVG/PNG), widget ini bisa diganti
/// `Image.asset` tanpa mengubah pemanggilnya.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40, this.showText = false});

  final double size;

  /// Tampilkan tulisan "CodeMentor AI" di samping ikon.
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final mark = _buildMark();

    if (!showText) return mark;

    // `FittedBox` + `scaleDown`: kalau ruang sempit (top bar layar kecil, atau
    // font fallback yang lebih lebar), seluruh logo diperkecil alih-alih
    // meluber keluar batas.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              style: AppTheme.display(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
              children: const [
                TextSpan(text: 'Code'),
                TextSpan(
                  text: 'Mentor',
                  style: TextStyle(color: AppColors.accent),
                ),
                TextSpan(text: ' AI'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Kotak logo: border gradien + isi gelap + glyph `</>`.
  Widget _buildMark() {
    final border = size * 0.055;
    final outerRadius = size * 0.26;
    final glyphSize = size * 0.40;

    return Container(
      height: size,
      width: size,
      padding: EdgeInsets.all(border),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(outerRadius),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(outerRadius - border),
        ),
        child: Center(
          child: FittedBox(
            // Mengaman-kan ukuran: kalau glyph lebih lebar dari kotak logo
            // (mis. font fallback di test), seluruh glyph diperkecil.
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GradientGlyph('<', glyphSize),
                Text(
                  '/',
                  style: AppTheme.mono(
                    fontSize: glyphSize,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neonCyan,
                  ).copyWith(height: 1.1),
                ),
                _GradientGlyph('>', glyphSize),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu glyph (`<` atau `>`) yang diwarnai gradien brand memakai [ShaderMask].
class _GradientGlyph extends StatelessWidget {
  const _GradientGlyph(this.char, this.fontSize);

  final String char;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppColors.brandGradient.createShader(bounds),
      child: Text(
        char,
        style: AppTheme.mono(
          fontSize: fontSize,
          letterSpacing: 0,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ).copyWith(height: 1.1),
      ),
    );
  }
}
