import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/auth_snapshot.dart';
import '../domain/dashboard_stats.dart';

/// Error statistik yang sudah diterjemahkan menjadi pesan siap tampil.
class DashboardException implements Exception {
  const DashboardException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sumber data statistik untuk layar Beranda/Dashboard.
///
/// Memilih endpoint berdasarkan peran user (meniru web):
/// - admin      -> `GET /api/admin/stats`  (statistik GLOBAL)
/// - user biasa -> `GET /api/dashboard/stats` (statistik MILIK SENDIRI)
class DashboardRepository {
  const DashboardRepository({required this.dio});

  final Dio dio;

  Future<DashboardStats> fetchStats({required bool isAdmin}) async {
    final path = isAdmin
        ? ApiConstants.adminStatsEndpoint
        : ApiConstants.userStatsEndpoint;

    try {
      final response = await dio.get<dynamic>(path);
      final data = response.data;
      if (data is Map) {
        return DashboardStats.fromJson(Map<String, dynamic>.from(data));
      }
      throw const DashboardException('Format statistik tidak dikenali.');
    } on DioException catch (error) {
      throw DashboardException(_messageFor(error));
    }
  }

  static String _messageFor(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return 'Server terlalu lama merespons. Coba lagi.';
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server. Periksa koneksi internetmu.';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == 401 || code == 403) {
          return 'Sesi kamu tidak lagi valid. Silakan masuk ulang.';
        }
        return 'Gagal memuat statistik (kode $code).';
      case DioExceptionType.cancel:
        return 'Permintaan dibatalkan.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return 'Terjadi kesalahan saat memuat statistik.';
    }
  }
}

/// Repository statistik (satu instance untuk seluruh aplikasi).
final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(dio: ref.watch(apiDioProvider)),
);

/// Statistik yang ditampilkan di tab Beranda.
///
/// Refresh manual: `ref.invalidate(dashboardStatsProvider)`.
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final session = ref.watch(authSnapshotProvider).session;
  final repository = ref.watch(dashboardRepositoryProvider);
  return repository.fetchStats(isAdmin: session?.user.isAdmin == true);
});
