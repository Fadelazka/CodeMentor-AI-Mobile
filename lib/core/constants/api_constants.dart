/// Konstanta penghubung aplikasi mobile ke backend CodeMentor-AI (Next.js).
///
/// Base URL bisa dioverride tanpa mengubah kode — berguna untuk uji ke server
/// lokal, contoh:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
class ApiConstants {
  ApiConstants._();

  /// Alamat backend. Default: deployment produksi (Vercel).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://code-mentor-ai-zeta-three.vercel.app',
  );

  /// Base path API NextAuth (dipakai flutter_next_auth_core).
  static const String authBasePath = '/api/auth';

  /// true bila backend memakai HTTPS.
  ///
  /// NextAuth v4 memakai NAMA COOKIE BERBEDA sesuai protokol:
  /// - HTTPS: `__Secure-next-auth.session-token` / `__Host-next-auth.csrf-token`
  /// - HTTP : `next-auth.session-token`        / `next-auth.csrf-token`
  ///
  /// Nama untuk produksi sudah diverifikasi langsung ke server Vercel
  /// (lihat header `set-cookie` pada respons login /api/auth/callback/credentials).
  static bool get usesHttps => baseUrl.startsWith('https://');

  /// Nama cookie sesi di server (harus sama persis, kalau tidak sesi tak terbaca).
  static String get sessionCookieName =>
      usesHttps ? '__Secure-next-auth.session-token' : 'next-auth.session-token';

  /// Nama cookie CSRF di server (wajib sama, kalau tidak login ditolak `csrf=true`).
  static String get csrfCookieName =>
      usesHttps ? '__Host-next-auth.csrf-token' : 'next-auth.csrf-token';

  /// Timeout koneksi (ms) untuk semua request.
  static const int connectTimeoutMs = 15000;

  /// Timeout baca (ms). Longgar, karena POST /api/chat memanggil model AI Groq.
  static const int receiveTimeoutMs = 60000;

  /// Bahasa yang didukung POST /api/chat (harus salah satu dari daftar ini).
  static const List<String> supportedLanguages = [
    'python',
    'javascript',
    'java',
    'cpp',
    'php',
  ];

  /// Label bahasa untuk dropdown di UI chat.
  static const Map<String, String> languageLabels = {
    'python': 'Python',
    'javascript': 'JavaScript',
    'java': 'Java',
    'cpp': 'C++',
    'php': 'PHP',
  };

  /// Tingkat detail penjelasan AI yang diterima POST /api/chat.
  static const List<String> detailLevels = ['brief', 'medium', 'detailed'];

  // ===== Endpoint yang dipakai aplikasi mobile =====
  /// GET — statistik dashboard untuk user biasa (tanpa login tetap 200, isinya
  /// nol). Lihat src/app/api/dashboard/stats/route.ts.
  static const String userStatsEndpoint = '/api/dashboard/stats';

  /// GET — statistik global; HANYA untuk admin (403 bila bukan admin).
  /// Lihat src/app/api/admin/stats/route.ts.
  static const String adminStatsEndpoint = '/api/admin/stats';

  /// POST — penjelasan kode/error (bisa dipakai tanpa login; riwayat hanya
  /// tersimpan bila user login). Lihat src/app/api/chat/route.ts.
  static const String chatEndpoint = '/api/chat';

  /// POST — umpan balik (thumbs up/down) untuk satu jawaban AI.
  /// Lihat src/app/api/chat/feedback/route.ts.
  static const String chatFeedbackEndpoint = '/api/chat/feedback';

  /// GET/DELETE — riwayat chat milik user. WAJIB login (401 bila belum).
  ///
  /// Query GET: `language` (opsional), `limit` (default 50, maks 200), atau
  /// `id` untuk satu entri. Query DELETE: `id` (satu) atau `all=1` (semua).
  static const String historyEndpoint = '/api/history';

  /// GET — ekspor riwayat sebagai berkas. Query: `format=csv|json`,
  /// `language`, `q`. Lihat src/app/api/history/export/route.ts.
  static const String historyExportEndpoint = '/api/history/export';

  /// POST — simpan hasil kuis onboarding. WAJIB login (401 bila belum).
  static const String quizSubmitEndpoint = '/api/quiz/submit';

  /// POST — ubah kata sandi akun yang sedang login. Body: `currentPassword`,
  /// `newPassword`. Lihat src/app/api/auth/change-password/route.ts.
  static const String changePasswordEndpoint = '/api/auth/change-password';

  /// GET — unduh seluruh data milik user sebagai JSON.
  /// Lihat src/app/api/user/export/route.ts.
  static const String userExportEndpoint = '/api/user/export';

  /// Kelola Knowledge Base; HANYA untuk admin (403 bila bukan admin).
  ///
  /// - `GET    ?language=&active=` -> `{ data, count }`,
  /// - `POST`                      -> 201 `{ data, message }`,
  /// - `PUT    ?id=`               -> `{ data, message }` (body penuh, atau
  ///   hanya `{ isActive }` untuk toggle status),
  /// - `DELETE ?id=`               -> `{ success, message }`.
  ///
  /// Lihat src/app/api/admin/knowledge-base/route.ts.
  static const String adminKbEndpoint = '/api/admin/knowledge-base';

  /// Kelola user; HANYA untuk admin (403 bila bukan admin).
  ///
  /// - `GET    ?q=`     -> `{ users, count }` (filter server `q` pada name/email),
  /// - `POST`           -> 201 `{ user, message }`,
  /// - `PATCH  /{id}`    -> `{ user, message }`,
  /// - `DELETE /{id}`   -> `{ success, message }` (dicegah menghapus diri sendiri).
  ///
  /// Lihat src/app/api/admin/users/route.ts dan src/app/api/admin/users/[id]/route.ts.
  static const String adminUsersEndpoint = '/api/admin/users';

  /// Profil user yang sedang login.
  ///
  /// - `PATCH` -> `{ user: { id, name, email, nim, favoriteLanguage, role, createdAt } }`
  ///
  /// Lihat src/app/api/user/profile/route.ts.
  static const String userProfileEndpoint = '/api/user/profile';

  /// Upload avatar user (multipart).
  ///
  /// - `POST` field `avatar` (image/jpeg|png|webp|gif, maks 2MB) -> `{ success: true, imageUrl: "/uploads/avatars/..." }`
  ///
  /// Lihat src/app/api/user/avatar/route.ts.
  static const String userAvatarEndpoint = '/api/user/avatar';
}
