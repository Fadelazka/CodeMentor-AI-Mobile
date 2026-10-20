/// Model statistik dashboard mobile.
///
/// Backend punya DUA bentuk respons (keduanya dinormalisasi ke model ini):
///
/// 1. `GET /api/dashboard/stats` (user biasa / belum login) — datar:
///    `{ totalQuestions, aiAccuracy, avgResponseTime, errorsSolved,
///       usageByLanguage, usagePerDay, recentActivity, topErrors? }`
/// 2. `GET /api/admin/stats` (admin) — bersarang:
///    `{ isAdminView: true, summary: {...}, charts: { daily, languages },
///       topErrors, recentActivity, meta: { totalUsers, activeUsers7d } }`
///
/// Catatan: route `/api/dashboard/stats` memeriksa ROLE sesi. Bila yang login
/// adalah ADMIN, route itu ikut mengembalikan bentuk BERSATU (isAdminView:
/// true) — perilaku server yang sudah terverifikasi lewat
/// `tool/dashboard_probe.dart`.
///
/// Lihat `src/app/api/dashboard/stats/route.ts` dan
/// `src/app/api/admin/stats/route.ts`.
library;

/// Satu titik data pemakaian harian (untuk grafik batang).
class DailyUsage {
  const DailyUsage({required this.date, required this.count});

  /// Tanggal (null bila string dari server tidak bisa diparse).
  final DateTime? date;
  final int count;

  /// Label pendek ala web: `05 Okt`.
  String get shortLabel {
    final d = date;
    if (d == null) return '-';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final day = d.day.toString().padLeft(2, '0');
    return '$day ${months[d.month - 1]}';
  }
}

/// Satu baris "Aktivitas Terakhir".
class RecentActivity {
  const RecentActivity({
    required this.id,
    required this.language,
    this.errorCode,
    this.confidence,
    this.responseTimeMs,
    this.createdAt,
  });

  final String id;
  final String language;
  final String? errorCode;
  final int? confidence;
  final int? responseTimeMs;
  final DateTime? createdAt;

  /// Label tanggal ala web: `05 Okt 2026, 14.30`.
  String get formattedDate {
    final d = createdAt;
    if (d == null) return '-';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final day = d.day.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day ${months[d.month - 1]} ${d.year}, $hour.$minute';
  }
}

/// Error yang paling sering dikonsultasikan.
class TopError {
  const TopError({required this.errorType, required this.count});

  final String errorType;
  final int count;
}

/// Info tambahan khusus tampilan admin.
class DashboardMeta {
  const DashboardMeta({required this.totalUsers, required this.activeUsers7d});

  final int totalUsers;
  final int activeUsers7d;
}

/// Statistik yang ditampilkan di layar Beranda/Dashboard.
class DashboardStats {
  const DashboardStats({
    this.dbTersedia = true,
    this.isAdminView = false,
    this.totalQuestions = 0,
    this.aiAccuracy = 0,
    this.avgResponseTimeMs = 0,
    this.errorsSolved = 0,
    this.usageByLanguage = const {},
    this.usagePerDay = const [],
    this.recentActivity = const [],
    this.topErrors = const [],
    this.meta,
  });

  /// Statistik kosong (dipakai sebagai fallback bila API gagal/menolak).
  factory DashboardStats.empty({bool isAdminView = false}) =>
      DashboardStats(isAdminView: isAdminView);

  final bool dbTersedia;
  final bool isAdminView;
  final int totalQuestions;

  /// Akurasi AI dalam persen (bisa desimal, mis. 87.5).
  final double aiAccuracy;

  /// Rata-rata waktu respons (milidetik).
  final int avgResponseTimeMs;

  final int errorsSolved;
  final Map<String, int> usageByLanguage;
  final List<DailyUsage> usagePerDay;
  final List<RecentActivity> recentActivity;
  final List<TopError> topErrors;
  final DashboardMeta? meta;

  bool get hasActivity => totalQuestions > 0;

  /// "1,2s" / "840ms" — mirip `formatResponseTime` di web.
  String get formattedResponseTime {
    if (avgResponseTimeMs <= 0) return '0ms';
    if (avgResponseTimeMs < 1000) return '${avgResponseTimeMs}ms';
    return '${(avgResponseTimeMs / 1000).toStringAsFixed(1)}s';
  }

  /// Persen akurasi tanpa desimal bila bulat (mis. "88%" / "87,5%").
  String get formattedAccuracy {
    if (aiAccuracy == aiAccuracy.roundToDouble()) {
      return '${aiAccuracy.round()}%';
    }
    return '${aiAccuracy.toStringAsFixed(1).replaceAll('.', ',')}%';
  }

  /// Mem-parse respons API (datar maupun bersarang) menjadi model ini.
  ///
  /// Tiga bentuk yang harus tahan:
  ///   - datar (user biasa / belum login),
  ///   - bersarang `summary` + `charts` (`/api/admin/stats`),
  ///   - campuran: `isAdminView: true` + `meta` tetapi angka tetap di akar
  ///     (`/api/dashboard/stats` saat yang login ADMIN).
  /// Karena itu setiap angka dibaca dari `summary` bila ada, kalau tidak dari
  /// akar JSON.
  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final isAdminView = json['isAdminView'] == true;

    // Bentuk admin: ambil angka dari `summary`, grafik dari `charts`.
    final summary = json['summary'];
    final summaryMap = summary is Map ? summary : const {};
    final charts = json['charts'];
    final chartsMap = charts is Map ? charts : const {};

    final totalQuestions = _int(
      summaryMap['totalQuestions'] ?? json['totalQuestions'],
    );
    final aiAccuracy = _double(
      summaryMap['aiAccuracy'] ?? json['aiAccuracy'],
    );
    final avgResponseTime = _int(
      summaryMap['avgResponseTime'] ?? json['avgResponseTime'],
    );
    final errorsSolved = _int(
      summaryMap['errorsSolved'] ?? json['errorsSolved'],
    );

    final languagesRaw =
        chartsMap['languages'] ?? json['usageByLanguage'] ?? const [];
    final dailyRaw =
        chartsMap['daily'] ?? json['usagePerDay'] ?? const [];

    final metaRaw = json['meta'];
    final topErrorsRaw = json['topErrors'];

    return DashboardStats(
      dbTersedia: json['dbTersedia'] != false,
      isAdminView: isAdminView,
      totalQuestions: totalQuestions,
      aiAccuracy: aiAccuracy,
      avgResponseTimeMs: avgResponseTime,
      errorsSolved: errorsSolved,
      usageByLanguage: _languageMap(languagesRaw),
      usagePerDay: _dailyList(dailyRaw),
      recentActivity: _activityList(json['recentActivity']),
      topErrors: _topErrorList(topErrorsRaw),
      meta: metaRaw is Map
          ? DashboardMeta(
              totalUsers: _int(metaRaw['totalUsers']),
              activeUsers7d: _int(metaRaw['activeUsers7d']),
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Parser defensif (tipe dari JSON bisa int/double/String/null)
  // ---------------------------------------------------------------------------

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _double(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _date(Object? value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  /// Bisa berupa `{ python: 3, java: 1 }` ATAU `[{language, count}, ...]`.
  static Map<String, int> _languageMap(Object? raw) {
    if (raw is Map) {
      return {
        for (final entry in raw.entries)
          entry.key.toString(): _int(entry.value),
      };
    }
    if (raw is List) {
      final result = <String, int>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final language = item['language']?.toString();
        if (language == null) continue;
        result[language] = _int(item['count']);
      }
      return result;
    }
    return const {};
  }

  static List<DailyUsage> _dailyList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          DailyUsage(
            date: _date(item['date']),
            count: _int(item['count']),
          ),
    ];
  }

  static List<RecentActivity> _activityList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          RecentActivity(
            id: item['id']?.toString() ?? '',
            language: item['language']?.toString() ?? 'python',
            errorCode: item['errorCode']?.toString(),
            confidence: item['confidence'] == null
                ? null
                : _int(item['confidence']),
            responseTimeMs: item['responseTimeMs'] == null
                ? null
                : _int(item['responseTimeMs']),
            createdAt: _date(item['createdAt']),
          ),
    ];
  }

  static List<TopError> _topErrorList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          TopError(
            errorType: item['errorType']?.toString() ?? '-',
            count: _int(item['count']),
          ),
    ];
  }
}
