import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// Pengganti `flutter_secure_storage` berbasis memori, khusus untuk test/probe.
///
/// Di dalam `flutter test` tidak ada plugin native (Android/iOS/desktop), jadi
/// penyimpanan aman wajib diganti implementasi ini agar `TokenCache` milik
/// flutter_next_auth_core tetap bisa membaca/menulis token.
class InMemorySecureStorage extends FlutterSecureStoragePlatform {
  InMemorySecureStorage();

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
