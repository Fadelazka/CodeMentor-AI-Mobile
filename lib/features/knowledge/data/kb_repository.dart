import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';

class KnowledgeItem {
  final String id;
  final String title;
  final String description;
  final String language;
  final bool isActive;
  final DateTime? createdAt;

  KnowledgeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.language,
    required this.isActive,
    this.createdAt,
  });

  factory KnowledgeItem.fromJson(Map<String, dynamic> json) {
    return KnowledgeItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? json['errorType'] ?? '-').toString(),
      description: (json['description'] ?? json['solution'] ?? json['explanation'] ?? '').toString(),
      language: (json['language'] ?? '').toString(),
      isActive: json['isActive'] == true || json['active'] == true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }
}

class KnowledgeRepository {
  KnowledgeRepository({Dio? dio}) : _dio = dio ?? _createDio();

  final Dio _dio;

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeoutMs),
        receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeoutMs),
      ),
    );
  }

  Future<List<KnowledgeItem>> fetchKnowledgeItems({String? language, String? search}) async {
    final res = await _dio.get('/api/knowledge-base', queryParameters: {
      if (language != null && language.isNotEmpty && language != 'all') 'language': language,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final data = res.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => KnowledgeItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is List) {
      return data
          .map((e) => KnowledgeItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  return KnowledgeRepository();
});
