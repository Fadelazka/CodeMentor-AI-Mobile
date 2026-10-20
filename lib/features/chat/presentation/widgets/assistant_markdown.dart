import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/code_block_view.dart';

/// Penampil Markdown ringan untuk jawaban AI.
///
/// Jawaban AI (Groq) memakai Markdown sederhana: heading `#`, daftar `-`/`1.`,
/// penekanan `**tebal**`, miring `*miring*`, kode inline `` `x` ``, blok kode
/// ber-` ``` `, kutipan `>` dan garis pemisah `---`.
///
/// Ditulis sendiri (tanpa paket Markdown tambahan) supaya tidak menambah risiko
/// ketidakcocokan versi Flutter dan gayanya bisa diselaraskan dengan web.
class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown({super.key, required this.text, this.style});

  final String text;

  /// Gaya dasar; default mengikuti isi panel app shell.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base =
        style ??
        const TextStyle(
          fontSize: 14,
          height: 1.55,
          color: AppColors.textPrimary,
        );
    final blocks = _parse(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          blocks[i].render(base),
        ],
      ],
    );
  }
}

// =============================================================================
// Blok
// =============================================================================
abstract class _Block {
  const _Block();

  Widget render(TextStyle base);
}

class _Paragraph extends _Block {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget render(TextStyle base) =>
      Text.rich(TextSpan(children: _inlineSpans(text, base)));
}

class _Heading extends _Block {
  const _Heading(this.text, this.level);

  final String text;
  final int level;

  @override
  Widget render(TextStyle base) {
    final size = switch (level) {
      1 => 18.0,
      2 => 16.5,
      3 => 15.5,
      _ => 14.5,
    };
    final style = base.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.35,
    );
    return Text.rich(TextSpan(children: _inlineSpans(text, style)));
  }
}

class _Bullet extends _Block {
  const _Bullet(this.text);

  final String text;

  @override
  Widget render(TextStyle base) => _ListRow(
    marker: '•',
    text: text,
    style: base.copyWith(fontWeight: FontWeight.w400),
  );
}

class _Numbered extends _Block {
  const _Numbered(this.number, this.text);

  final String number;
  final String text;

  @override
  Widget render(TextStyle base) =>
      _ListRow(marker: '$number.', text: text, style: base);
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.marker,
    required this.text,
    required this.style,
  });

  final String marker;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          child: Text(
            marker,
            style: style.copyWith(
              color: AppColors.accentPink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text.rich(TextSpan(children: _inlineSpans(text, style))),
        ),
      ],
    );
  }
}

class _QuoteBlock extends _Block {
  const _QuoteBlock(this.text);

  final String text;

  @override
  Widget render(TextStyle base) {
    final style = base.copyWith(color: AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.accentPink, width: 2)),
      ),
      child: Text.rich(TextSpan(children: _inlineSpans(text, style))),
    );
  }
}

class _CodeBlockWidget extends _Block {
  const _CodeBlockWidget({required this.code, this.language});

  final String code;
  final String? language;

  @override
  Widget render(TextStyle base) =>
      CodeBlockView(code: code, language: language);
}

class _HorizontalRule extends _Block {
  const _HorizontalRule();

  @override
  Widget render(TextStyle base) => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(vertical: 2),
    color: AppColors.borderSoft,
  );
}

// =============================================================================
// Pengurai
// =============================================================================
final RegExp _headingPattern = RegExp(r'^(#{1,6})\s+(.*)$');
final RegExp _bulletPattern = RegExp(r'^[-*+]\s+(.*)$');
final RegExp _orderedPattern = RegExp(r'^(\d{1,3})[.)]\s+(.*)$');
final RegExp _quotePattern = RegExp(r'^>\s?(.*)$');
final RegExp _rulePattern = RegExp(r'^([-*_])\1{2,}$');
final RegExp _fencePattern = RegExp(r'^```(.*)$');

/// Memecah Markdown menjadi blok-blok yang bisa dirender.
List<_Block> _parse(String raw) {
  final blocks = <_Block>[];
  final lines = raw.replaceAll('\r\n', '\n').split('\n');
  var index = 0;

  bool isBlockStart(String line) =>
      line.isEmpty ||
      line.startsWith('```') ||
      _headingPattern.hasMatch(line) ||
      _rulePattern.hasMatch(line) ||
      _bulletPattern.hasMatch(line) ||
      _orderedPattern.hasMatch(line) ||
      _quotePattern.hasMatch(line);

  while (index < lines.length) {
    final line = lines[index].trim();

    // --- blok kode ---------------------------------------------------------
    final fence = _fencePattern.firstMatch(line);
    if (fence != null) {
      final language = (fence.group(1) ?? '').trim();
      index++;
      final buffer = <String>[];
      while (index < lines.length && !lines[index].trim().startsWith('```')) {
        buffer.add(lines[index]);
        index++;
      }
      if (index < lines.length) index++; // lewati ``` penutup
      blocks.add(
        _CodeBlockWidget(
          code: buffer.join('\n'),
          language: language.isEmpty ? null : language,
        ),
      );
      continue;
    }

    if (line.isEmpty) {
      index++;
      continue;
    }

    if (_rulePattern.hasMatch(line)) {
      blocks.add(const _HorizontalRule());
      index++;
      continue;
    }

    final heading = _headingPattern.firstMatch(line);
    if (heading != null) {
      blocks.add(_Heading(heading.group(2)!.trim(), heading.group(1)!.length));
      index++;
      continue;
    }

    final ordered = _orderedPattern.firstMatch(line);
    if (ordered != null) {
      blocks.add(_Numbered(ordered.group(1)!, ordered.group(2)!.trim()));
      index++;
      continue;
    }

    final bullet = _bulletPattern.firstMatch(line);
    if (bullet != null) {
      blocks.add(_Bullet(bullet.group(1)!.trim()));
      index++;
      continue;
    }

    final quote = _quotePattern.firstMatch(line);
    if (quote != null) {
      blocks.add(_QuoteBlock(quote.group(1)!.trim()));
      index++;
      continue;
    }

    // --- paragraf (kumpulkan baris sampai penanda berikutnya) --------------
    final paragraph = <String>[];
    while (index < lines.length) {
      final current = lines[index].trim();
      if (paragraph.isNotEmpty && isBlockStart(current)) break;
      if (current.isEmpty) break;
      paragraph.add(current);
      index++;
    }
    blocks.add(_Paragraph(paragraph.join(' ')));
  }

  return blocks;
}

// =============================================================================
// Format inline
// =============================================================================
final RegExp _inlinePattern = RegExp(
  r'(\*\*[^*]+\*\*|__[^_]+__|`[^`]+`|\*[^*\n]+\*|\[[^\]]+\]\([^)]*\))',
);

List<InlineSpan> _inlineSpans(String source, TextStyle base) {
  final spans = <InlineSpan>[];
  var cursor = 0;

  for (final match in _inlinePattern.allMatches(source)) {
    if (match.start > cursor) {
      spans.add(
        TextSpan(text: source.substring(cursor, match.start), style: base),
      );
    }

    final token = match.group(0)!;
    if (token.startsWith('**') || token.startsWith('__')) {
      spans.add(
        TextSpan(
          text: token.substring(2, token.length - 2),
          style: base.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    } else if (token.startsWith('`')) {
      spans.add(
        TextSpan(
          text: token.substring(1, token.length - 1),
          style: AppTheme.mono(
            fontSize: (base.fontSize ?? 14) - 1.5,
            letterSpacing: 0,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      );
    } else if (token.startsWith('[')) {
      // Tautan: cukup tampilkan labelnya (tidak bisa diklik dari sini).
      final label = RegExp(r'^\[([^\]]+)\]').firstMatch(token)?.group(1);
      spans.add(TextSpan(text: label ?? token, style: base));
    } else {
      spans.add(
        TextSpan(
          text: token.substring(1, token.length - 1),
          style: base.copyWith(fontStyle: FontStyle.italic),
        ),
      );
    }

    cursor = match.end;
  }

  if (cursor < source.length) {
    spans.add(TextSpan(text: source.substring(cursor), style: base));
  }
  return spans.isEmpty ? [TextSpan(text: source, style: base)] : spans;
}
