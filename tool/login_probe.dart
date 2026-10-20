// PROBE MANUAL (bukan bagian `flutter test` default — dijalankan eksplisit):
//
//   flutter test tool/login_probe.dart
//
// Tujuan: membuktikan AuthRepository benar-benar bisa login ke backend produksi
// (cookie sesi + CSRF) tanpa perlu emulator. Penyimpanan aman diganti versi
// in-memory supaya bisa jalan di Dart VM (flutter test), bukan di HP.
//
// Catatan: file ini memakai kredensial admin dan menembak jaringan sungguhan,
// jadi sengaja diletakkan di `tool/` agar tidak ikut `flutter test` biasa.
import 'dart:io';

import 'package:codementor_mobile/core/constants/api_constants.dart';
import 'package:codementor_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pengganti `flutter_secure_storage` versi in-memory (khusus test).
class InMemorySecureStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _store[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _store[key];

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _store.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _store.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map<String, String>.from(_store);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _store.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Binding milik flutter_test memalsukan HttpClient (semua request -> 400).
  // Probe ini memang menembak server sungguhan, jadi override itu dimatikan.
  HttpOverrides.global = null;
  FlutterSecureStoragePlatform.instance = InMemorySecureStorage();

  test('login admin ke produksi + baca sesi + ambil cookie', () async {
    final auth = AuthRepository();

    final result = await auth.signInWithCredentials(
      email: 'admin@codementor.com',
      password: 'admin123',
    );
    expect(result.ok, isTrue, reason: 'pesan error: ${result.message}');

    final session = await auth.fetchSession();
    expect(session?.user.email, 'admin@codementor.com');
    expect(session?.user.isAdmin, isTrue);

    final cookies = await auth.sessionCookies();
    expect(
      cookies.keys.toList(),
      contains(ApiConstants.sessionCookieName),
      reason: 'cookie sesi harus bisa dibaca untuk request /api/history & /api/quiz/submit',
    );

    final wrong = await auth.signInWithCredentials(
      email: 'admin@codementor.com',
      password: 'kata-sandi-salah',
    );
    expect(wrong.ok, isFalse, reason: 'login dengan sandi salah tidak boleh sukses');
    // ignore: avoid_print
    print('HASIL: login benar = OK | login salah = "${wrong.message}"');
  });
}
