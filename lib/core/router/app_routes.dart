/// Kumpulan path route aplikasi (dipisah dari `app_router.dart` supaya
/// `app_nav.dart` bisa memakainya tanpa impor melingkar).
///
/// Penamaannya disamakan dengan web supaya mudah dibandingkan:
/// - `/dashboard`   (web: khusus ADMIN, lihat src/app/(app)/dashboard/page.tsx)
/// - `/chat`        (web: src/app/(app)/chat)
/// - `/riwayat`     (web: src/app/(app)/riwayat) + `/riwayat/:id` (detail)
/// - `/pengetahuan` (web: src/app/(app)/pengetahuan)
/// - `/admin`       (web: src/app/(app)/admin)
/// - `/profil`      (web: src/app/(app)/profil)
/// - `/pengaturan`  (web: src/app/(app)/pengaturan)
///
/// Halaman web `/masuk` di mobile tetap bernama `/login` (perbedaan kosmetik
/// internal; UX-nya sama).
class AppRoutes {
  AppRoutes._();

  /// Layar splash (sedang memeriksa sesi).
  static const String splash = '/';

  /// Halaman masuk.
  static const String login = '/login';

  /// Halaman daftar akun.
  static const String register = '/register';

  /// Halaman lupa kata sandi.
  static const String forgotPassword = '/forgot-password';

  /// Halaman GitHub OAuth redirect.
  static const String githubAuth = '/auth/github';

  // ===== Area setelah login =====
  /// Dashboard statistik. HANYA ADMIN (user biasa dialihkan ke [chat]).
  static const String dashboard = '/dashboard';

  /// Chat AI (tanya error kode).
  static const String chat = '/chat';

  /// Riwayat konsultasi.
  static const String history = '/riwayat';

  /// Base pengetahuan (knowledge base) — di web bisa dibaca semua user.
  static const String knowledge = '/pengetahuan';

  /// Panel admin: kelola knowledge base & user. HANYA ADMIN.
  static const String admin = '/admin';

  /// Profil user.
  static const String profile = '/profil';

  /// Pengaturan aplikasi.
  static const String settings = '/pengaturan';

  /// Segmen sub-route untuk detail riwayat (`/riwayat/:id`).
  static const String historyDetailSegment = ':id';

  /// Path lengkap detail riwayat.
  static String historyDetail(String id) => '$history/$id';

  /// Path yang hanya boleh dibuka ADMIN (dipakai `redirect` pada router).
  static const Set<String> adminOnly = {dashboard, admin};
}
