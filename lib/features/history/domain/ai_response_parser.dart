/// Pengurai jawaban AI untuk layar Detail Riwayat.
///
/// Salinan `parseAIResponse()` + `isCodeCorrectResponse()` di web
/// (`src/app/(app)/riwayat/[id]/page.tsx:42-69`) supaya tampilan mobile sama:
/// - bagian `## Kode yang Sudah Dibenarkan` DIKELUARKAN dari penjelasan lalu
///   ditampilkan sebagai blok kode tersendiri (hijau),
/// - bagian `## Kode yang Bermasalah` hanya diambil kodenya (tetap ada di
///   penjelasan, seperti web).
library;

/// Hasil penguraian satu jawaban AI.
class AiResponseView {
  const AiResponseView({
    required this.explanation,
    this.brokenCode,
    this.fixedCode,
    this.language,
  });

  /// Penjelasan AI tanpa bagian "Kode yang Sudah Dibenarkan".
  final String explanation;

  /// Kode yang bermasalah (bila AI menuliskannya di bagian terpisah).
  final String? brokenCode;

  /// Kode perbaikan dari bagian "Kode yang Sudah Dibenarkan".
  final String? fixedCode;

  /// Bahasa pada info-string blok kode perbaikan (mis. `python`), bila ada.
  final String? language;
}

/// `(?:^|\n)#{1,6}\s*Kode yang Sudah Dibenarkan\s*\n+```(\w+)?\n([\s\S]*?)````
final RegExp _fixedCodePattern = RegExp(
  r'(?:^|\n)#{1,6}\s*Kode yang Sudah Dibenarkan\s*\n+```(\w+)?\n([\s\S]*?)```',
  caseSensitive: false,
);

/// Sama seperti di atas, untuk judul "Kode yang Bermasalah".
final RegExp _brokenCodePattern = RegExp(
  r'(?:^|\n)#{1,6}\s*Kode yang Bermasalah\s*\n+```(\w+)?\n([\s\S]*?)```',
  caseSensitive: false,
);

/// Frasa yang menandakan AI menganggap kode sudah benar.
final RegExp _correctPattern = RegExp(
  r'sudah benar|100%|kode benar|tidak ada error',
  caseSensitive: false,
);

/// Memecah [raw] menjadi penjelasan + kode-kode yang bisa ditampilkan terpisah.
AiResponseView parseAiResponse(String raw) {
  var remaining = raw;
  String? fixedCode;
  String? language;

  final fixed = _fixedCodePattern.firstMatch(remaining);
  if (fixed != null) {
    final info = (fixed.group(1) ?? '').trim();
    language = info.isEmpty ? null : info;
    fixedCode = (fixed.group(2) ?? '').trim();
    remaining = remaining.replaceRange(fixed.start, fixed.end, '\n');
  }

  final broken = _brokenCodePattern.firstMatch(remaining);
  final brokenCode = broken == null ? null : (broken.group(2) ?? '').trim();

  return AiResponseView(
    explanation: remaining.trim(),
    brokenCode: brokenCode,
    fixedCode: fixedCode,
    language: language,
  );
}

/// true bila jawaban AI menyatakan kode sudah benar.
///
/// Web punya DUA pemeriksaan yang sedikit berbeda: fungsi
/// `isCodeCorrectResponse()` membatasi 200 huruf pertama, sedangkan panel yang
/// benar-benar tampil memindai SELURUH teks. Di mobile dipakai pemindaian
/// seluruh teks supaya hasil yang dilihat user sama dengan web.
bool isCodeCorrectResponse(String raw) => _correctPattern.hasMatch(raw);
