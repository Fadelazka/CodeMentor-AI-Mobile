import 'package:flutter/material.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/code_block_view.dart';
import '../../domain/chat_answer.dart';
import 'assistant_markdown.dart';

/// Label bahasa (mis. `python` -> `Python`).
String _languageLabel(String code) =>
    ApiConstants.languageLabels[code] ?? code.toUpperCase();

// =============================================================================
// Pesan user (kanan, aksen gradien brand)
// =============================================================================
class ChatUserBubble extends StatelessWidget {
  const ChatUserBubble({super.key, required this.exchange});

  final ChatExchange exchange;

  @override
  Widget build(BuildContext context) {
    return _BubbleFrame(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 13, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'KAMU',
                style: AppTheme.mono(
                  fontSize: 9.5,
                  letterSpacing: 1.1,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              _LanguageChip(language: exchange.language),
            ],
          ),
          const SizedBox(height: 10),
          CodeBlockView(
            code: exchange.sourceCode,
            language: _languageLabel(exchange.language),
          ),
          if (exchange.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      exchange.errorMessage!,
                      style: AppTheme.mono(
                        fontSize: 11.5,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cincin gradien + isi bubble (dipakai untuk pesan user).
class _BubbleFrame extends StatelessWidget {
  const _BubbleFrame({required this.child, required this.alignment});

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.92,
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      _languageLabel(language),
      style: AppTheme.mono(
        fontSize: 9,
        letterSpacing: 0.6,
        color: Colors.white,
      ),
    ),
  );
}

// =============================================================================
// Jawaban AI (kiri, permukaan app shell)
// =============================================================================
class ChatAssistantBubble extends StatelessWidget {
  const ChatAssistantBubble({
    super.key,
    required this.exchange,
    this.onFeedback,
  });

  final ChatExchange exchange;

  /// Dipanggil saat user menekan tombol umpan balik.
  final ValueChanged<ChatFeedback>? onFeedback;

  @override
  Widget build(BuildContext context) {
    final answer = exchange.answer!;
    final confidence = answer.confidence;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.panelDecoration(color: AppColors.surface2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 22,
                    width: 22,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CODEMENTOR AI',
                    style: AppTheme.mono(
                      fontSize: 9.5,
                      letterSpacing: 1.1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (answer.mock) const _Pill(text: 'CONTOH', tone: AppColors.neonAmber),
                  if (answer.detectedErrorCode != null) ...[
                    _Pill(
                      text: answer.detectedErrorCode!,
                      tone: AppColors.neonCyan,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (confidence != null)
                    _Pill(
                      text: '$confidence%',
                      tone: confidence >= 85
                          ? AppColors.neonGreen
                          : AppColors.neonAmber,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              AssistantMarkdown(text: answer.explanation),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.borderSoft),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (answer.responseTimeMs != null)
                    Text(
                      '${(answer.responseTimeMs! / 1000).toStringAsFixed(1)}s',
                      style: AppTheme.mono(fontSize: 9.5, letterSpacing: 0.4),
                    ),
                  if (answer.ragMatches > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${answer.ragMatches} rujukan KB',
                      style: AppTheme.mono(fontSize: 9.5, letterSpacing: 0.4),
                    ),
                  ],
                  const Spacer(),
                  CopyIconButton(
                    text: answer.explanation,
                    tooltip: 'Salin jawaban',
                    iconSize: 17,
                  ),
                  const SizedBox(width: 4),
                  _ThumbButton(
                    icon: Icons.thumb_up_outlined,
                    tooltip: 'Membantu',
                    active: exchange.feedback == ChatFeedback.helpful,
                    onPressed: onFeedback == null
                        ? null
                        : () => onFeedback!(ChatFeedback.helpful),
                  ),
                  const SizedBox(width: 2),
                  _ThumbButton(
                    icon: Icons.thumb_down_outlined,
                    tooltip: 'Kurang tepat',
                    active: exchange.feedback == ChatFeedback.notHelpful,
                    onPressed: onFeedback == null
                        ? null
                        : () => onFeedback!(ChatFeedback.notHelpful),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: 0.12),
      border: Border.all(color: tone.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: AppTheme.mono(
        fontSize: 9,
        letterSpacing: 0.5,
        color: tone,
      ),
    ),
  );
}

class _ThumbButton extends StatelessWidget {
  const _ThumbButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? AppColors.accentPink.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(
              icon,
              size: 17,
              color: active ? AppColors.accentPink : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Keadaan: sedang dikirim & gagal
// =============================================================================
class ChatPendingBubble extends StatelessWidget {
  const ChatPendingBubble({super.key, required this.language});

  final String language;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppTheme.panelDecoration(color: AppColors.surface2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accentPink,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Menganalisis kode ${_languageLabel(language).toLowerCase()}...',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class ChatFailedBubble extends StatelessWidget {
  const ChatFailedBubble({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: AppColors.accentPink.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 16,
                color: AppColors.accentPink,
              ),
              const SizedBox(width: 8),
              Text(
                'GAGAL MENGIRIM',
                style: AppTheme.mono(
                  fontSize: 9.5,
                  letterSpacing: 1.1,
                  color: AppColors.accentPink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba lagi'),
            ),
          ),
        ],
      ),
    ),
  );
}
