import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// =============================================================================
/// Token warna — disalin dari web `src/app/globals.css`
/// =============================================================================
///
/// Web memakai DUA kelompok token:
///
/// 1. Token Tailwind (HSL) — dipakai halaman publik seperti `/masuk`, `/daftar`.
///    Mode gelap adalah default (`theme-provider.tsx`: defaultTheme = "dark").
/// 2. Token "app shell" — dipakai area setelah login (dashboard, chat, kuis,
///    riwayat): permukaan biru gelap (`--surface-1/2/3`) dengan aksen gradien
///    brand `#FF3B6B -> #FF6B35` (lihat `src/components/chat/chat-interface.tsx`).
///
/// Keduanya disediakan di sini supaya seluruh layar mobile bisa konsisten.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // 1. Token Tailwind (HSL) — halaman publik & komponen dasar
  // ---------------------------------------------------------------------------
  static const Color background = Color(0xFF0A0A0A); // hsl(0 0% 4%)
  static const Color card = Color(0xFF121212); // hsl(0 0% 7%)
  static const Color muted = Color(0xFF1F1F1F); // hsl(0 0% 12%)
  static const Color border = Color(0xFF292929); // hsl(0 0% 16%)
  static const Color foreground = Color(0xFFFAF6F5); // hsl(48 33% 97%)
  static const Color mutedForeground = Color(0xFF8F8F8F); // hsl(0 0% 56%)
  static const Color accent = Color(0xFFDD1D4A); // hsl(346 77% 49%)
  static const Color accentForeground = Color(0xFFFAF6F5);
  static const Color destructive = Color(0xFFDD1D4A); // --destructive
  static const Color ring = Color(0xFFFAF6F5); // hsl(48 33% 97%)

  // ---------------------------------------------------------------------------
  // 2. Token "app shell" (dashboard, chat, kuis, riwayat)
  // ---------------------------------------------------------------------------
  static const Color surface1 = Color(0xFF0A0B14); // --surface-1
  static const Color surface2 = Color(0xFF0F1119); // --surface-2
  static const Color surface3 = Color(0xFF141824); // --surface-3
  static const Color sidebar = Color(0xFF05060A); // --sidebar-bg
  static const Color textPrimary = Color(0xFFFFFFFF); // --text-primary
  static const Color textSecondary = Color(0xFFA1A1AA); // --text-secondary
  static const Color textMuted = Color(0xFF71717A); // --text-muted
  static const Color borderSoft = Color(0x0FFFFFFF); // rgba(255,255,255,.06)
  static const Color borderHover = Color(0x1FFFFFFF); // rgba(255,255,255,.12)
  static const Color inputBg = Color(0x05FFFFFF); // rgba(255,255,255,.02)
  static const Color inputBorder = Color(0x14FFFFFF); // rgba(255,255,255,.08)

  // ---------------------------------------------------------------------------
  // 3. Brand: tombol/aksen
  // ---------------------------------------------------------------------------
  /// Web memakai istilah `ink` (gelap) & `paper` (terang) untuk tombol utama
  /// (`Button variant="primary"` = latar paper, teks ink).
  static const Color ink = Color(0xFF0A0A0A);
  static const Color paper = Color(0xFFFAF6F5);

  static const Color accentPink = Color(0xFFFF3B6B); // --accent-primary
  static const Color accentOrange = Color(0xFFFF6B35); // --accent-secondary

  // ---------------------------------------------------------------------------
  // Warna aksen "neon" (dipakai badge bahasa & kartu statistik di web:
  // `neon-cyan`, `neon-green`, `neon-violet`, `neon-pink`, `neon-amber`)
  // ---------------------------------------------------------------------------
  static const Color neonCyan = Color(0xFF22D3EE);
  static const Color neonGreen = Color(0xFF22C55E);
  static const Color neonViolet = Color(0xFF8B5CF6);
  static const Color neonPink = Color(0xFFFF3B6B);
  static const Color neonAmber = Color(0xFFF59E0B);

  /// Teks/ikon di atas gradien brand (web memakai #050818).
  static const Color onBrand = Color(0xFF050818);

  /// Gradien brand: `linear-gradient(135deg, #FF3B6B, #FF6B35)`.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentPink, accentOrange],
  );

  /// Pendar lembut untuk latar (pengganti blob blur di web).
  static RadialGradient glow(Color color, {double opacity = 0.18}) =>
      RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: 0),
        ],
      );
}

/// =============================================================================
/// Tema global aplikasi mobile
/// =============================================================================
class AppTheme {
  AppTheme._();

  // --- Radius (web: rounded-sm 2px, rounded-lg 8px, rounded-xl 12px) ---------
  static const double radius = 4; // rounded-sm
  static const double radiusLg = 8; // rounded-lg
  static const double radiusXl = 12; // rounded-xl
  static const double radiusXxl = 16; // rounded-2xl

  // ---------------------------------------------------------------------------
  // Font
  // ---------------------------------------------------------------------------
  /// Font sans untuk seluruh teks.
  ///
  /// Web memakai **Inter** (`next/font/google` di `src/app/layout.tsx`).
  static TextTheme interTextTheme(TextTheme base) =>
      GoogleFonts.interTextTheme(base);

  /// Web memakai **JetBrains Mono** untuk `font-mono` (label kecil, eyebrow,
  /// kode, timestamp).
  static TextStyle mono({
    double fontSize = 11,
    double letterSpacing = 1.2,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.mutedForeground,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: fontSize,
    letterSpacing: letterSpacing,
    fontWeight: fontWeight,
    color: color,
  );

  /// Web memakai **Space Grotesk** untuk `font-display` (judul/wordmark).
  static TextStyle display({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = -0.4,
    Color color = AppColors.foreground,
  }) => GoogleFonts.spaceGrotesk(
    fontSize: fontSize,
    letterSpacing: letterSpacing,
    fontWeight: fontWeight,
    color: color,
  );

  /// Label kecil bergaya font-mono uppercase (label form, meta, dsb).
  static final TextStyle monoLabel = mono();

  /// Eyebrow aksen (mis. "LOGIN BERHASIL", "SOAL 3/7").
  static final TextStyle monoEyebrow = mono(color: AppColors.accentPink);

  // ---------------------------------------------------------------------------
  // Gaya komponen siap pakai
  // ---------------------------------------------------------------------------
  /// Tombol utama versi web (`Button variant="primary"`): latar paper, teks ink.
  ///
  /// Dipakai sebagai DEFAULT tema (lihat `filledButtonTheme`), sama seperti web
  /// yang memakai `dark:bg-paper dark:text-ink` untuk tombol primer.
  static ButtonStyle get paperButtonStyle => FilledButton.styleFrom(
    backgroundColor: AppColors.paper,
    foregroundColor: AppColors.ink,
    disabledBackgroundColor: AppColors.paper.withValues(alpha: 0.4),
    disabledForegroundColor: AppColors.ink,
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  );

  /// Tombol aksen crimson (`--destructive`/`--accent` web) — dipakai HANYA
  /// untuk aksi sekunder yang memang butuh warna brand, mis. "Keluar".
  static ButtonStyle get accentButtonStyle => FilledButton.styleFrom(
    backgroundColor: AppColors.accent,
    foregroundColor: AppColors.accentForeground,
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  );

  /// Tombol aksen gradien brand (tombol kirim chat, kartu CTA dashboard).
  ///
  /// Dipasang lewat [Ink] + [BoxDecoration] karena `ButtonStyle` tidak
  /// mendukung gradien secara langsung:
  /// ```dart
  /// Ink(decoration: AppTheme.gradientDecoration(), child: InkWell(...))
  /// ```
  static BoxDecoration gradientDecoration({
    double radius = AppTheme.radiusLg,
  }) => BoxDecoration(
    gradient: AppColors.brandGradient,
    borderRadius: BorderRadius.circular(radius),
  );

  /// Kotak/panel standar ala app shell web (`rounded-xl border border-white/6`).
  static BoxDecoration panelDecoration({
    Color color = AppColors.surface2,
    Color borderColor = AppColors.borderSoft,
    double radius = AppTheme.radiusXl,
  }) => BoxDecoration(
    color: color,
    border: Border.all(color: borderColor),
    borderRadius: BorderRadius.circular(radius),
  );

  /// Pendar aksen untuk latar (pengganti `AuthBackground` di web).
  static BoxDecoration glowDecoration({
    required Color color,
    double opacity = 0.18,
  }) => BoxDecoration(
    shape: BoxShape.circle,
    gradient: AppColors.glow(color, opacity: opacity),
  );

  // ---------------------------------------------------------------------------
  // ThemeData
  // ---------------------------------------------------------------------------
  static ThemeData get dark {
    final base = ThemeData(brightness: Brightness.dark);
    // Seluruh teks memakai Inter (persis web), lalu warnanya diselaraskan
    // dengan token tema gelap.
    final textTheme = interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.foreground,
      displayColor: AppColors.foreground,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        onPrimary: AppColors.accentForeground,
        secondary: AppColors.muted,
        onSecondary: AppColors.foreground,
        surface: AppColors.card,
        onSurface: AppColors.foreground,
        error: AppColors.destructive,
        onError: AppColors.accentForeground,
        outline: AppColors.border,
      ),
      textTheme: textTheme.copyWith(
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: const AppBarTheme(
        // Meniru topbar web (`--topbar-bg: rgba(5,6,10,.8)` + border bawah).
        backgroundColor: AppColors.sidebar,
        foregroundColor: AppColors.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(color: AppColors.borderSoft),
        ),
        titleTextStyle: TextStyle(
          color: AppColors.foreground,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface2,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: const BorderSide(color: AppColors.borderSoft),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        hintStyle: const TextStyle(color: AppColors.mutedForeground),
        prefixIconColor: AppColors.mutedForeground,
        suffixIconColor: AppColors.mutedForeground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.accent),
        errorBorder: _inputBorder(AppColors.accent),
        focusedErrorBorder: _inputBorder(AppColors.accent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        // Default = tombol primer web: PUTIH (paper) dengan teks gelap (ink).
        // Aksen crimson tetap hidup di tempat lain (checkbox, border focus,
        // link, eyebrow) dan bisa dipasang manual lewat
        // `AppTheme.accentButtonStyle`.
        style: paperButtonStyle,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.foreground,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.mutedForeground,
          highlightColor: AppColors.muted,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accent
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.accentForeground),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.muted,
        selectedColor: AppColors.accent,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.foreground,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.accentForeground,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.mutedForeground,
        textColor: AppColors.foreground,
        tileColor: Colors.transparent,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusXl)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.sidebar,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accentPink.withValues(alpha: 0.16),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? AppColors.accentPink
                : AppColors.textMuted,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface2,
        modalBackgroundColor: AppColors.surface2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXxl),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface2,
        surfaceTintColor: Colors.transparent,
        textStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.foreground,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: const BorderSide(color: AppColors.borderSoft),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.foreground,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppColors.mutedForeground,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: const BorderSide(color: AppColors.borderSoft),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surface3,
          borderRadius: BorderRadius.circular(radiusLg),
          border: Border.all(color: AppColors.borderSoft),
        ),
        textStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.foreground,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(radiusLg),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? AppColors.borderHover
              : AppColors.borderSoft,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.card,
        contentTextStyle: TextStyle(
          color: AppColors.foreground,
          fontSize: 13,
        ),
        actionTextColor: AppColors.accentPink,
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.muted,
        circularTrackColor: Colors.transparent,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(color: color),
  );
}
