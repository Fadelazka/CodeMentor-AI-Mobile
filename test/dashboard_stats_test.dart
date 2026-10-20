// Unit test pemetaan respons API statistik -> model `DashboardStats`.
//
// Backend punya dua bentuk respons (lihat src/app/api/dashboard/stats/route.ts
// dan src/app/api/admin/stats/route.ts), jadi normalisasinya WAJIB diuji.
import 'package:codementor_mobile/features/dashboard/domain/dashboard_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardStats.fromJson', () {
    test('bentuk admin (bersarang): summary + charts dinormalisasi', () {
      final stats = DashboardStats.fromJson({
        'isAdminView': true,
        'summary': {
          'totalQuestions': 42,
          'aiAccuracy': 87.5,
          'avgResponseTime': 1500,
          'errorsSolved': 7,
        },
        'charts': {
          'daily': [
            {'date': '2026-10-05T00:00:00.000Z', 'count': 3},
            {'date': '2026-10-06T00:00:00.000Z', 'count': 0},
          ],
          'languages': [
            {'language': 'python', 'count': 30},
            {'language': 'java', 'count': 12},
          ],
        },
        'recentActivity': [
          {
            'id': 'a1',
            'language': 'python',
            'errorCode': 'NameError',
            'confidence': 90,
            'createdAt': '2026-10-06T10:30:00.000Z',
          },
        ],
        'topErrors': [
          {'errorType': 'NameError', 'count': 5},
        ],
        'meta': {'totalUsers': 12, 'activeUsers7d': 4},
      });

      expect(stats.isAdminView, isTrue);
      expect(stats.totalQuestions, 42);
      expect(stats.aiAccuracy, 87.5);
      expect(stats.formattedAccuracy, '87,5%');
      expect(stats.formattedResponseTime, '1.5s');
      expect(stats.errorsSolved, 7);
      expect(stats.usageByLanguage, {'python': 30, 'java': 12});
      expect(stats.usagePerDay.length, 2);
      expect(stats.recentActivity.single.errorCode, 'NameError');
      expect(stats.topErrors.single.count, 5);
      expect(stats.meta?.totalUsers, 12);
      expect(stats.meta?.activeUsers7d, 4);
      expect(stats.hasActivity, isTrue);
      expect(stats.usagePerDay.first.shortLabel, isNotEmpty);
    });

    test('bentuk campuran: isAdminView + meta tetapi angka di akar', () {
      // Ini respons NYATA `GET /api/dashboard/stats` saat yang login ADMIN
      // (src/app/api/dashboard/stats/route.ts baris ~125): angka datar,
      // plus isAdminView + meta. Dulu parser membaca `summary` yang tidak ada
      // sehingga semua angka jadi 0 (ditemukan lewat tool/dashboard_probe.dart).
      final stats = DashboardStats.fromJson({
        'dbTersedia': true,
        'isAdminView': true,
        'totalQuestions': 22,
        'aiAccuracy': 88,
        'avgResponseTime': 1234,
        'errorsSolved': 6,
        'usageByLanguage': {'python': 18, 'cpp': 4},
        'usagePerDay': [
          {'date': '2026-10-06', 'count': 5},
        ],
        'recentActivity': [
          {'id': 'h1', 'language': 'cpp', 'errorCode': 'SegmentationFault'},
        ],
        'meta': {'totalUsers': 12, 'activeUsers7d': 4},
      });

      expect(stats.isAdminView, isTrue);
      expect(stats.totalQuestions, 22);
      expect(stats.aiAccuracy, 88);
      expect(stats.formattedResponseTime, '1.2s');
      expect(stats.errorsSolved, 6);
      expect(stats.usageByLanguage, {'python': 18, 'cpp': 4});
      expect(stats.usagePerDay.single.count, 5);
      expect(stats.recentActivity.single.errorCode, 'SegmentationFault');
      expect(stats.meta?.totalUsers, 12);
      expect(stats.hasActivity, isTrue);
    });

    test('bentuk user biasa (datar) dengan map bahasa', () {
      final stats = DashboardStats.fromJson({
        'dbTersedia': true,
        'totalQuestions': 3,
        'aiAccuracy': 88,
        'avgResponseTime': 800,
        'errorsSolved': 2,
        'usageByLanguage': {'php': 2, 'cpp': 1},
        'usagePerDay': [
          {'date': '2026-10-05', 'count': 1},
        ],
        'recentActivity': [
          {'id': 'b1', 'language': 'php', 'errorCode': null},
        ],
      });

      expect(stats.isAdminView, isFalse);
      expect(stats.hasActivity, isTrue);
      expect(stats.formattedAccuracy, '88%');
      expect(stats.formattedResponseTime, '800ms');
      expect(stats.usageByLanguage, {'php': 2, 'cpp': 1});
      expect(stats.recentActivity.single.errorCode, isNull);
      expect(stats.meta, isNull);
    });

    test('tahan terhadap nilai kosong / tipe tak terduga', () {
      final stats = DashboardStats.fromJson(const {
        'totalQuestions': '4',
        'avgResponseTime': 1200.4,
        'usageByLanguage': null,
        'usagePerDay': 'bukan-list',
        'recentActivity': [null, 5],
      });

      expect(stats.totalQuestions, 4);
      expect(stats.avgResponseTimeMs, 1200);
      expect(stats.formattedResponseTime, '1.2s');
      expect(stats.usageByLanguage, isEmpty);
      expect(stats.usagePerDay, isEmpty);
      expect(stats.recentActivity, isEmpty);
      expect(stats.dbTersedia, isTrue);
    });

    test('statistik kosong punya default yang aman', () {
      final stats = DashboardStats.empty(isAdminView: true);

      expect(stats.isAdminView, isTrue);
      expect(stats.hasActivity, isFalse);
      expect(stats.formattedAccuracy, '0%');
      expect(stats.formattedResponseTime, '0ms');
      expect(stats.usagePerDay, isEmpty);
    });
  });
}
