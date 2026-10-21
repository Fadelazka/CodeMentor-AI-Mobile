import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/badge_pill.dart';
import '../../../core/widgets/code_block_view.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../chat/presentation/widgets/assistant_markdown.dart';
import '../data/history_controller.dart';
import '../data/history_repository.dart';
import '../domain/ai_response_parser.dart';
import '../domain/chat_history_item.dart';

/// Detail satu riwayat konsultasi (`/riwayat/:id`) — padanan
/// `src/app/(app)/riwayat/[id]/page.tsx`.
///
/// Isinya:
/// - kode sumber (read-only) + pesan error (bila ada),
/// - jawaban AI: bagian "Kode yang Sudah Dibenarkan" dipisah menjadi blok
///   kode tersendiri lewat `parseAiResponse` (persis web),
/// - panel khusus bila AI menyatakan kode sudah benar,
/// - tombol Kembali & Hapus.
class HistoryDetailScreen extends ConsumerWidget {
  const HistoryDetailScreen({super.key, required this.id});

  /// ID entri riwayat (`state.pathParameters['id']`).
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(historyDetailProvider(id));
    final item = detailAsync.value;

    // Gagal memuat & belum ada data lama -> panel error / tidak ditemukan.
    if (detailAsync.hasError && item == null) {
      final error = detailAsync.error;
      if (error is HistoryException && error.notFound) {
        return const _NotFoundView();
      }
      return _LoadErrorView(
        message: error is HistoryException
            ? error.message
            : 'Terjadi kesalahan tak terduga.',
        onRetry: () => ref.invalidate(historyDetailProvider(id)),
      );
    }

    if (item == null) return const _LoadingView();

    return _DetailView(item: item);
  }
}

// =============================================================================
// Kepala halaman (dipakai semua keadaan)
// =============================================================================
class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.description,
    this.actions,
  });

  final String title;
  final String description;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RIWAYAT', style: AppTheme.monoEyebrow),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        if (actions != null) ...[const SizedBox(height: 14), actions!],
      ],
    );
  }
}

/// Panel dasar bergaya `GlassCard` web.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: AppTheme.panelDecoration(),
    child: child,
  );
}

// =============================================================================
// Keadaan: memuat, gagal, tidak ditemukan
// =============================================================================
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        18,
        AppSpacing.page,
        28,
      ),
      children: const [
        _PageHeader(
          title: 'Memuat...',
          description: 'Memuat detail riwayat analisis',
        ),
        SizedBox(height: 20),
        _Panel(child: SizedBox(height: 220)),
      ],
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        18,
        AppSpacing.page,
        28,
      ),
      children: [
        const _PageHeader(
          title: 'Riwayat Tidak Ditemukan',
          description:
              'Riwayat yang Anda cari tidak ditemukan atau telah dihapus.',
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: GradientButton(
            label: 'Kembali ke Riwayat',
            icon: Icons.arrow_back,
            onPressed: () => context.go(AppRoutes.history),
          ),
        ),
      ],
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        18,
        AppSpacing.page,
        28,
      ),
      children: [
        const _PageHeader(
          title: 'Gagal Memuat Riwayat',
          description: 'Terjadi masalah saat mengambil detail riwayat.',
        ),
        const SizedBox(height: 20),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 26,
                color: AppColors.neonAmber,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    style: _buttonStyle(),
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const Text('Coba lagi'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.history),
                    style: _buttonStyle(),
                    icon: const Icon(Icons.arrow_back, size: 17),
                    label: const Text('Kembali'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Isi detail
// =============================================================================
class _DetailView extends ConsumerWidget {
  const _DetailView({required this.item});

  final ChatHistoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsed = parseAiResponse(item.aiResponse);
    final isCorrect = isCodeCorrectResponse(item.aiResponse);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        18,
        AppSpacing.page,
        28,
      ),
      children: [
        _PageHeader(
          title: 'Detail Analisis',
          description:
              'Analisis ${item.languageLabel} • ${item.formattedDate}',
          actions: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.history),
                style: _buttonStyle(),
                icon: const Icon(Icons.arrow_back, size: 17),
                label: const Text('Kembali'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => _delete(context, ref),
                style: _buttonStyle(color: AppColors.neonPink),
                icon: const Icon(Icons.delete_outline, size: 17),
                label: const Text('Hapus'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ---- Kode sumber -----------------------------------------------------
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  BadgePill(
                    label: item.languageLabel,
                    tone: BadgePill.toneForLanguage(item.language),
                  ),
                  if (item.errorCode != null)
                    BadgePill(label: item.errorCode!, tone: BadgeTone.pink),
                  Text(
                    item.formattedDate,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CodeBlockView(
                code: item.sourceCode,
                language: item.languageLabel,
              ),
              if (item.errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.neonAmber.withValues(alpha: 0.08),
                    border: Border.all(
                      color: AppColors.neonAmber.withValues(alpha: 0.4),
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PESAN ERROR',
                        style: AppTheme.mono(
                          fontSize: 9.5,
                          letterSpacing: 1,
                          color: AppColors.neonAmber,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.errorMessage!,
                        style: AppTheme.mono(
                          fontSize: 12,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w400,
                          color: AppColors.neonAmber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---- Jawaban AI ------------------------------------------------------
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OUTPUT',
                          style: AppTheme.mono(
                            fontSize: 10,
                            letterSpacing: 1.1,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Respons dalam Bahasa Indonesia',
                          style: AppTheme.mono(fontSize: 9.5, letterSpacing: 0.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.borderSoft),
              const SizedBox(height: 14),
              if (isCorrect)
                _CorrectCodePanel(explanation: parsed.explanation)
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: AppTheme.panelDecoration(
                    color: AppColors.inputBg,
                    radius: AppTheme.radiusXl,
                  ),
                  child: AssistantMarkdown(text: parsed.explanation),
                ),
                if (parsed.fixedCode != null) ...[
                  const SizedBox(height: 16),
                  _FixedCodeBlock(
                    code: parsed.fixedCode!,
                    language: parsed.language ?? item.language,
                  ),
                ],
              ],
              if (item.confidence != null) ...[
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.borderSoft),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    BadgePill(
                      label: 'Confidence ${item.confidence}%',
                      tone: BadgePill.toneForConfidence(item.confidence!),
                    ),
                    if (item.errorCode != null)
                      BadgePill(label: item.errorCode!, tone: BadgeTone.pink),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus riwayat ini?'),
        content: const Text('Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: AppTheme.accentButtonStyle.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(historyRepositoryProvider).deleteOne(item.id);
      ref.invalidate(historyListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Riwayat dihapus.')));
      context.go(AppRoutes.history);
    } on HistoryException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

/// Panel hijau untuk jawaban "kode sudah benar" (padanan blok emerald di web).
class _CorrectCodePanel extends StatelessWidget {
  const _CorrectCodePanel({required this.explanation});

  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.neonGreen.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.neonGreen.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: AppColors.neonGreen.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 20,
              color: AppColors.neonGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✓ Kode ini sudah benar 100%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neonGreen,
                  ),
                ),
                if (explanation.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    explanation,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: AppColors.neonGreen.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Blok kode perbaikan — padanan `FixedCodeBlock` di web (header hijau).
class _FixedCodeBlock extends StatelessWidget {
  const _FixedCodeBlock({required this.code, required this.language});

  final String code;
  final String language;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.neonGreen.withValues(alpha: 0.05),
        border: Border.all(color: AppColors.neonGreen.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: AppColors.neonGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'KODE YANG SUDAH DIBENARKAN',
                    style: AppTheme.mono(
                      fontSize: 9.5,
                      letterSpacing: 1,
                      color: AppColors.neonGreen,
                    ),
                  ),
                ),
                CopyIconButton(
                  text: code,
                  tooltip: 'Salin kode perbaikan',
                  iconSize: 16,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                code,
                style: AppTheme.mono(
                  fontSize: 12,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w400,
                  color: AppColors.neonGreen,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gaya tombol garis (padanan `GradientButton variant="outline"` di web).
ButtonStyle _buttonStyle({Color color = AppColors.textSecondary}) =>
    OutlinedButton.styleFrom(
      foregroundColor: color,
      minimumSize: const Size(0, 42),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
    );
