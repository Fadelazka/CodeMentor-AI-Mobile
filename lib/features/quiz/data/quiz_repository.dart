import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../auth/data/auth_repository.dart';

class QuizRepository {
  QuizRepository({Dio? dio, required this.auth}) : _dio = dio ?? _createDio();

  final Dio _dio;
  final AuthRepository auth;

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeoutMs),
        receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeoutMs),
      ),
    );
  }

  Future<Map<String, dynamic>?> submitQuiz({
    required int score,
    required String preference,
  }) async {
    try {
      final cookies = await auth.sessionCookies();
      print('[QUIZ_REPO] Cookies: $cookies');
      final response = await _dio.post(
        '/api/quiz/submit',
        data: {
          'score': score,
          'preference': preference,
        },
        options: cookies.isNotEmpty
            ? Options(headers: {'Cookie': _formatCookies(cookies)})
            : null,
      );
      print('[QUIZ_REPO] Response: ${response.statusCode} ${response.data}');
      return response.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      print('[QUIZ_REPO] DioError: ${e.response?.statusCode} ${e.response?.data}');
      rethrow;
    } catch (e) {
      print('[QUIZ_REPO] Error: $e');
      rethrow;
    }
  }

  String _formatCookies(Map<String, String> cookies) {
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }
}

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return QuizRepository(auth: auth);
});
