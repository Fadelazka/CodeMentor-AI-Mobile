import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/app_settings.dart';
import '../theme/app_theme.dart';

/// Tombol kecil untuk menyalin teks (dipakai blok kode & jawaban AI).
class CopyIconButton extends StatelessWidget {
  const CopyIconButton({
    super.key,
    required this.text,
    this.tooltip = 'Salin',
    this.iconSize = 16,
  });

  final String text;
  final String tooltip;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Disalin ke clipboard'),
              duration: Duration(seconds: 2),
            ),
          );
      },
      tooltip: tooltip,
      iconSize: iconSize,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
      icon: const Icon(Icons.copy_all_outlined),
    );
  }
}

/// Kotak kode bergaya mono (padanan blok kode di web
/// `src/components/chat/fixed-code-block.tsx`).
///
/// Ukuran huruf mengikuti preferensi **Ukuran Font Editor** di layar Pengaturan
/// (`appSettingsProvider.editorFontSize`); nilai 14 (default "Sedang") memberi
/// 12.5 seperti sebelumnya. Widget ini membaca preferensi langsung supaya semua
/// blok kode di aplikasi (bubble chat, jawaban AI, detail riwayat) serempak
/// berubah — jadi ia bergantung pada satu provider fitur Pengaturan, bukan
/// hanya token tema.
class CodeBlockView extends ConsumerWidget {
  const CodeBlockView({
    super.key,
    required this.code,
    this.language,
    this.showCopy = true,
  });

  final String code;

  /// Label bahasa pada header (mis. `python`).
  final String? language;

  final bool showCopy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = (language ?? '').trim();
    final editorFontSize = ref.watch(
      appSettingsProvider.select((settings) => settings.editorFontSize),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF05060A),
        border: Border.all(color: AppColors.borderSoft),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.isEmpty ? 'KODE' : title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.mono(fontSize: 9.5, letterSpacing: 1),
                  ),
                ),
                if (showCopy) CopyIconButton(text: code),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                code,
                style: AppTheme.mono(
                  fontSize: editorFontSize - 1.5,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
