import '../../../core/constants/api_constants.dart';
import '../../../core/utils/format.dart';

/// Satu rekaman Knowledge Base (tabel `KnowledgeBase` di Prisma).
///
/// Padanan `KbRecord` di `src/components/admin/kb-modal.tsx:8-19` dan
/// `KnowledgeBaseRow` di `src/app/(app)/admin/page.tsx:29`.
class KbEntry {
  const KbEntry({
    required this.id,
    required this.language,
    required this.errorCode,
    required this.title,
    required this.description,
    required this.solution,
    this.examples,
    this.tags = const [],
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String language;
  final String errorCode;
  final String title;
  final String description;
  final String solution;
  final String? examples;
  final List<String> tags;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory KbEntry.fromJson(Map<String, dynamic> json) {
    return KbEntry(
      id: json['id'] as String? ?? '',
      language: json['language'] as String? ?? '',
      errorCode: json['errorCode'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      solution: json['solution'] as String? ?? '',
      examples: json['examples'] as String?,
      tags: (json['tags'] as List?)?.map((t) => t.toString()).toList() ??
          const [],
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  static DateTime? _parseDate(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;

  /// Label bahasa seperti tampilan web (`getLanguageLabel`).
  String get languageLabel =>
      ApiConstants.languageLabels[language] ?? language.toUpperCase();

  /// Tanggal pembarui terakhir, format `06 Okt 2026`
  /// (padanan `formatDateShort` di `admin/page.tsx:37`).
  String get formattedUpdatedAt => formatDateId(updatedAt);

  /// Filter pencarian lokal — meniru `filteredKb` di
  /// `src/app/(app)/admin/page.tsx:154-162` (kode error, judul, bahasa, id).
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return errorCode.toLowerCase().contains(q) ||
        title.toLowerCase().contains(q) ||
        language.toLowerCase().contains(q) ||
        id.toLowerCase().contains(q);
  }

  /// Salinan field yang bisa diedit lewat form (tanpa id & timestamp).
  KbEntryDraft toDraft() => KbEntryDraft(
        language: language,
        errorCode: errorCode,
        title: title,
        description: description,
        solution: solution,
        examples: examples ?? '',
        tags: tags,
        isActive: isActive,
      );
}

/// Isi form tambah/edit rekaman — dikirim ke POST/PUT
/// `/api/admin/knowledge-base` (lihat `kb-modal.tsx:227-237`).
class KbEntryDraft {
  const KbEntryDraft({
    required this.language,
    required this.errorCode,
    required this.title,
    required this.description,
    required this.solution,
    this.examples = '',
    this.tags = const [],
    this.isActive = true,
  });

  final String language;
  final String errorCode;
  final String title;
  final String description;
  final String solution;
  final String examples;
  final List<String> tags;
  final bool isActive;

  // Pesan validasi — SAMA persis dengan `validate()` di `kb-modal.tsx:160-183`.
  // Dipakai di dua tempat: [validate] (model) dan form tambah/edit di UI.
  static const String errLanguage = 'Pilih bahasa pemrograman.';
  static const String errErrorCode = 'Tipe error wajib diisi.';
  static const String errTitle = 'Judul wajib diisi.';
  static const String errDescription = 'Deskripsi masalah wajib diisi.';
  static const String errSolution = 'Solusi wajib diisi.';

  /// Validasi seluruh field; mengembalikan pesan error PERTAMA yang gagal
  /// (atau `null` bila lolos).
  String? validate() {
    if (language.trim().isEmpty) return errLanguage;
    if (errorCode.trim().isEmpty) return errErrorCode;
    if (title.trim().isEmpty) return errTitle;
    if (description.trim().isEmpty) return errDescription;
    if (solution.trim().isEmpty) return errSolution;
    return null;
  }

  /// Body JSON untuk server. Contoh kode kosong dikirim `null`
  /// (meniru `examples: e.target.value || null` di `kb-modal.tsx:231`).
  Map<String, dynamic> toJson() => {
        'language': language.trim(),
        'errorCode': errorCode.trim(),
        'title': title.trim(),
        'description': description.trim(),
        'solution': solution.trim(),
        'examples': examples.trim().isEmpty ? null : examples,
        'tags': tags,
        'isActive': isActive,
      };

  /// `['Math', 'Division']` -> `'Math, Division'` (isian teks di form).
  static String tagsToText(List<String> tags) => tags.join(', ');

  /// `'Math, Division'` -> `['Math', 'Division']` (diparse ulang saat simpan).
  static List<String> tagsFromText(String text) => text
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList(growable: false);
}
