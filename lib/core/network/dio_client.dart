import 'package:dio/dio.dart';
import 'package:flutter_next_auth_core/next_auth.dart';

import '../constants/api_constants.dart';

/// Adapter `HttpClient` milik flutter_next_auth_core -> Dio.
///
/// Paket flutter_next_auth_core hanya MENDEFINISIKAN interface `HttpClient`
/// (lihat README paket: "this package only defines an abstract HttpClient.
/// You must implement it in your app"), jadi implementasinya kita tulis di sini.
/// Struktur mengikuti contoh resmi `simple_dio_httpclient.dart`.
class DioHttpClient implements HttpClient {
  DioHttpClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: Duration(
                milliseconds: ApiConstants.connectTimeoutMs,
              ),
              receiveTimeout: Duration(
                milliseconds: ApiConstants.receiveTimeoutMs,
              ),
              headers: const {'Accept': 'application/json'},
            ),
          );

  final Dio _dio;

  ResponseType? _toDioResponseType(HttpClientResponseType? type) =>
      switch (type) {
        HttpClientResponseType.json => ResponseType.json,
        HttpClientResponseType.stream => ResponseType.stream,
        HttpClientResponseType.plain => ResponseType.plain,
        HttpClientResponseType.bytes => ResponseType.bytes,
        null => null,
      };

  /// Menerjemahkan [HttpClientOptions] menjadi [Options] Dio, termasuk
  /// menempelkan cookie (NextAuth mengirim CSRF & sesi lewat cookie).
  Options? _toDioOptions(String method, HttpClientOptions? options) {
    if (options == null) return null;

    final opts = Options(
      method: method,
      headers: options.headers,
      preserveHeaderCase: options.preserveHeaderCase,
      contentType: options.contentType,
      validateStatus: options.validateStatus as ValidateStatus?,
      followRedirects: options.followRedirects,
      maxRedirects: options.maxRedirects,
      responseType: _toDioResponseType(options.responseType),
      sendTimeout: options.sendTimeout == null
          ? null
          : Duration(milliseconds: options.sendTimeout!),
      receiveTimeout: options.receiveTimeout == null
          ? null
          : Duration(milliseconds: options.receiveTimeout!),
    );

    final cookies = options.cookies;
    if (cookies == null || cookies.isEmpty) return opts;

    // Gabungkan cookie yang sudah ada di header dengan cookie dari paket auth.
    final merged = <String, String>{};
    final existing = opts.headers?['cookie'] ?? opts.headers?['Cookie'];
    if (existing is String && existing.isNotEmpty) {
      for (final part in existing.split(';')) {
        final trimmed = part.trim();
        final separator = trimmed.indexOf('=');
        if (separator <= 0) continue;
        merged[trimmed.substring(0, separator)] = trimmed.substring(
          separator + 1,
        );
      }
    }
    merged.addAll(options.cookies!);
    if (merged.isEmpty) return opts;

    opts.headers = {
      ...?opts.headers,
      'cookie': merged.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; '),
    };
    return opts;
  }

  @override
  Future<HttpResponse> get(String url, {HttpClientOptions? options}) async {
    final response = await _dio.get(url, options: _toDioOptions('GET', options));
    return HttpResponse(
      statusCode: response.statusCode,
      body: response.data,
      headers: response.headers.map,
    );
  }

  @override
  Future<HttpResponse> post(
    String url, {
    HttpClientOptions? options,
    Object? body,
  }) async {
    final response = await _dio.post(
      url,
      data: body ?? options?.body,
      options: _toDioOptions('POST', options),
    );
    return HttpResponse(
      statusCode: response.statusCode,
      body: response.data,
      headers: response.headers.map,
    );
  }
}

/// Pembaca cookie sesi NextAuth.
///
/// Sengaja berupa fungsi yang di-inject dari layer auth supaya file `core/`
/// ini tidak perlu tahu apa-apa soal fitur autentikasi (menghindari
/// ketergantungan melingkar).
typedef SessionCookieReader = Future<Map<String, String>> Function();

/// Membuat [Dio] untuk memanggil API aplikasi (chat, history, quiz).
///
/// PENTING: backend memakai NextAuth v4 dengan session strategy JWT, sehingga
/// identitas user dikirim lewat COOKIE `next-auth.session-token`,
/// BUKAN header `Authorization`. Interceptor di bawah menempelkan cookie itu
/// secara otomatis bila [readSessionCookies] diberikan dan user sudah login.
Dio createApiDio({
  SessionCookieReader? readSessionCookies,
  String? baseUrl,
  List<Interceptor>? extraInterceptors,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? ApiConstants.baseUrl,
      connectTimeout: Duration(milliseconds: ApiConstants.connectTimeoutMs),
      receiveTimeout: Duration(milliseconds: ApiConstants.receiveTimeoutMs),
      headers: const {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final readCookies = readSessionCookies;
        if (readCookies != null) {
          try {
            final cookies = await readCookies();
            if (cookies.isNotEmpty) {
              final cookieHeader = cookies.entries
                  .map((e) => '${e.key}=${e.value}')
                  .join('; ');
              final existing = options.headers['cookie'];
              options.headers['cookie'] =
                  existing is String && existing.isNotEmpty
                  ? '$existing; $cookieHeader'
                  : cookieHeader;
            }
          } catch (_) {
            // Diabaikan: request tetap dikirim tanpa cookie. Endpoint publik
            // seperti POST /api/chat tetap berfungsi.
          }
        }
        handler.next(options);
      },
    ),
  );

  return dio;
}
