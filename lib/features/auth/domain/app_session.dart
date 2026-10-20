import 'package:flutter_next_auth_core/next_auth.dart';

/// Data user dari `GET /api/auth/session`.
///
/// Bentuk JSON-nya mengikuti backend CodeMentor-AI, contoh nyata dari produksi:
/// ```json
/// {
///   "user": {
///     "name": "Admin cik", "email": "admin@codementor.com", "image": null,
///     "id": "cmv...", "role": "ADMIN", "nim": "V3925005",
///     "favoriteLanguage": "cpp", "quizCompletedAt": null
///   },
///   "expires": "2026-11-17T19:20:44.726Z"
/// }
/// ```
class AppSessionUser {
  const AppSessionUser({
    required this.id,
    this.name,
    this.email,
    this.image,
    this.role = 'USER',
    this.nim,
    this.favoriteLanguage,
    this.quizCompletedAt,
  });

  final String id;
  final String? name;
  final String? email;
  final String? image;

  /// "ADMIN" atau "USER" (lihat enum Role di prisma/schema.prisma).
  final String role;

  final String? nim;
  final String? favoriteLanguage;

  /// Terisi hanya bila user sudah menyelesaikan kuis onboarding.
  final DateTime? quizCompletedAt;

  bool get isAdmin => role == 'ADMIN';

  bool get hasCompletedQuiz => quizCompletedAt != null;

  factory AppSessionUser.fromJson(Map<String, dynamic> json) {
    return AppSessionUser(
      id: (json['id'] ?? '').toString(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      image: json['image']?.toString(),
      role: (json['role'] ?? 'USER').toString(),
      nim: json['nim']?.toString(),
      favoriteLanguage: json['favoriteLanguage']?.toString(),
      quizCompletedAt: DateTime.tryParse(
        (json['quizCompletedAt'] ?? '').toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'image': image,
    'role': role,
    'nim': nim,
    'favoriteLanguage': favoriteLanguage,
    'quizCompletedAt': quizCompletedAt?.toIso8601String(),
  };
}

/// Sesi user seperti yang dikembalikan `GET /api/auth/session`.
class AppSession {
  const AppSession({required this.user, this.expires});

  final AppSessionUser user;
  final DateTime? expires;

  factory AppSession.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return AppSession(
      user: AppSessionUser.fromJson(
        userJson is Map ? Map<String, dynamic>.from(userJson) : const {},
      ),
      expires: DateTime.tryParse((json['expires'] ?? '').toString()),
    );
  }
}

/// Serializer yang diwajibkan `NextAuthConfig.sessionSerializer`.
///
/// Dipakai paket untuk mengubah JSON `/api/auth/session` menjadi [AppSession]
/// dan sebaliknya saat memanggil `updateSession`.
class AppSessionSerializer implements SessionSerializer<AppSession> {
  const AppSessionSerializer();

  @override
  AppSession? fromJson(dynamic json) {
    if (json is! Map) return null;
    // Sesi kosong (belum login) dikirim sebagai {} oleh NextAuth -> null.
    if (json.isEmpty || json['user'] == null) return null;
    return AppSession.fromJson(Map<String, dynamic>.from(json));
  }

  @override
  Map<String, dynamic> toJson(AppSession session) => {
    'user': session.user.toJson(),
    if (session.expires != null) 'expires': session.expires!.toIso8601String(),
  };
}
