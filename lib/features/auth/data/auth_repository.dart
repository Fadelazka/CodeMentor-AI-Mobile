import 'package:dio/dio.dart';
import 'package:flutter_next_auth_core/models/sign_in_error.dart';
import 'package:flutter_next_auth_core/next_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../domain/app_session.dart';

/// Hasil operasi login dalam bentuk yang ramah UI (tidak membocorkan tipe paket).
class AuthResult {
  const AuthResult._({required this.ok, this.message});

  const AuthResult.success() : this._(ok: true);

  const AuthResult.failure(String message) : this._(ok: false, message: message);

  /// true bila login berhasil (sesi sudah tersimpan di flutter_secure_storage).
  final bool ok;

  /// Pesan siap tampil bila [ok] bernilai false.
  final String? message;
}

/// Sumber kebenaran autentikasi aplikasi mobile.
///
/// Backend memakai NextAuth v4 dengan `session: { strategy: "jwt" }`
/// (lihat src/lib/auth.ts), sehingga setelah login berhasil sesi dikirim
/// sebagai COOKIE `__Secure-next-auth.session-token` — BUKAN header
/// `Authorization`. Paket flutter_next_auth_core yang mengurus CSRF token,
/// pengambilan cookie sesi, dan penyimpanannya ke flutter_secure_storage.
class AuthRepository {
  AuthRepository({NextAuthClient<AppSession>? client})
    : _client = client ?? createNextAuthClient();

  final NextAuthClient<AppSession> _client;

  NextAuthClient<AppSession> get client => _client;

  /// Sesi user saat ini (null bila belum login).
  AppSession? get session => _client.session;

  bool get isAuthenticated => _client.session != null;

  /// Membuat NextAuthClient dengan konfigurasi backend CodeMentor-AI.
  ///
  /// Nama cookie WAJIB sama dengan yang dipakai server. Untuk deployment HTTPS
  /// di Vercel namanya `__Secure-next-auth.session-token` dan
  /// `__Host-next-auth.csrf-token` (sudah diverifikasi lewat header set-cookie).
  static NextAuthClient<AppSession> createNextAuthClient() {
    return NextAuthClient<AppSession>(
      NextAuthConfig<AppSession>(
        domain: ApiConstants.baseUrl,
        authBasePath: ApiConstants.authBasePath,
        httpClient: DioHttpClient(),
        sessionSerializer: const AppSessionSerializer(),
        serverSessionCookieName: ApiConstants.sessionCookieName,
        serverCSRFTokenCookieName: ApiConstants.csrfCookieName,
      ),
    );
  }

  /// Login dengan email + kata sandi lewat CredentialsProvider
  /// (POST /api/auth/callback/credentials).
  Future<AuthResult> signInWithCredentials({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || password.isEmpty) {
      return const AuthResult.failure('Email dan kata sandi wajib diisi.');
    }

    // Wajib dipanggil lebih dulu: mengisi cache CSRF dari flutter_secure_storage.
    // Tanpa ini getCSRFToken() mengembalikan null dan NextAuth menolak request
    // (respons akan mengarah ke /api/auth/signin?csrf=true, bukan error password).
    await _client.recoverLoginStatusFromCache();

    final response = await _client.signIn(
      'credentials',
      credentialsOptions: CredentialsSignInOptions(
        email: cleanEmail,
        password: password,
      ),
    );

    if (response.ok) return const AuthResult.success();
    return AuthResult.failure(_messageFor(response.error));
  }

  /// Ambil ulang sesi dari server (saat app dibuka, atau setelah aksi tertentu).
  Future<AppSession?> fetchSession() async {
    await _client.recoverLoginStatusFromCache();
    await _client.refetchSession();
    return _client.session;
  }

  /// Logout + hapus token dari penyimpanan aman.
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanName.isEmpty || cleanEmail.isEmpty || password.isEmpty) {
      return const AuthResult.failure('Semua field wajib diisi.');
    }
    if (cleanName.length < 2) {
      return const AuthResult.failure('Nama minimal 2 karakter.');
    }
    if (password.length < 6) {
      return const AuthResult.failure('Kata sandi minimal 6 karakter.');
    }

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeoutMs),
          receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeoutMs),
        ),
      );
      await dio.post(
        '/api/auth/register',
        data: {
          'name': cleanName,
          'email': cleanEmail,
          'password': password,
        },
      );
      return const AuthResult.success();
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? (e.response?.data['error'] ??
              e.response?.data['message'] ??
              'Pendaftaran gagal.')
          : 'Pendaftaran gagal.';
      return AuthResult.failure(message);
    } catch (_) {
      return const AuthResult.failure('Pendaftaran gagal. Coba lagi.');
    }
  }

  Future<void> signOut() => _client.signOut();

  /// Cookie sesi untuk request API yang butuh login
  /// (GET /api/history, POST /api/quiz/submit).
  Future<Map<String, String>> sessionCookies() async {
    final token = await _client.tokenCache.getAccessToken();
    if (token == null || !token.isValid) return const {};
    return {ApiConstants.sessionCookieName: token.token};
  }

  static String _messageFor(SignInError? error) {
    switch (error?.code) {
      case SignInErrorCode.invalidLogin:
        return 'Email atau kata sandi salah.';
      case SignInErrorCode.networkError:
        return 'Tidak dapat terhubung ke server. Periksa koneksi internetmu.';
      case SignInErrorCode.serverError:
        return 'Terjadi kesalahan pada server. Coba lagi sebentar lagi.';
      case null:
        return 'Login gagal. Coba lagi.';
    }
  }
}

/// NextAuthClient tunggal untuk seluruh aplikasi.
///
/// `main.dart` membuat SATU instance lewat provider ini (di-override pada
/// `ProviderScope`), lalu instance yang sama diberikan ke
/// `NextAuthRiverpodScope`. Dengan begitu state sesi reaktif milik paket
/// next-auth dan `authRepositoryProvider` memakai client yang sama.
final nextAuthClientProvider = Provider<NextAuthClient<AppSession>>(
  (ref) => AuthRepository.createNextAuthClient(),
);

/// Repository autentikasi (satu instance untuk seluruh aplikasi).
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(client: ref.watch(nextAuthClientProvider)),
);

/// Dio untuk memanggil API aplikasi (chat, history, quiz).
/// Cookie sesi otomatis ditempelkan bila user sudah login.
final apiDioProvider = Provider<Dio>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return createApiDio(readSessionCookies: auth.sessionCookies);
});
