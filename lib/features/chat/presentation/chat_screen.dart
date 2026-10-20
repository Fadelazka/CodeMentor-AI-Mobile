import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../settings/data/app_settings.dart';
import '../data/chat_controller.dart';
import '../data/chat_repository.dart';
import '../domain/chat_answer.dart';
import 'widgets/chat_bubble.dart';

/// Layar Chat AI — padanan `src/app/(app)/chat/page.tsx` +
/// `src/components/chat/chat-interface.tsx`.
///
/// Alur (sama dengan web):
/// 1. user memilih bahasa, menempelkan kode, (opsional) pesan error;
/// 2. kirim -> `POST /api/chat` -> jawaban Markdown ditampilkan sebagai bubble;
/// 3. jawaban bisa disalin dan diberi umpan balik (thumbs up/down).
///
/// API-nya SATU TANYA-SATU JAWAB (tidak ada parameter riwayat percakapan),
/// jadi layar ini menampilkan daftar pasangan tanya-jawab seperti web.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _errorController = TextEditingController();
  final ScrollController _listController = ScrollController();

  String _language = 'python';

  @override
  void initState() {
    super.initState();
    // Tombol kirim ikut aktif/nonaktif saat isi editor berubah.
    _codeController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _codeController
      ..removeListener(_onFormChanged)
      ..dispose();
    _errorController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final code = _codeController.text;
    final error = _errorController.text;
    if (code.trim().isEmpty) return;

    FocusScope.of(context).unfocus();
    _codeController.clear();
    _errorController.clear();

    await ref
        .read(chatControllerProvider.notifier)
        .ask(sourceCode: code, language: _language, errorMessage: error);
    _scheduleScrollToBottom();
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listController.hasClients) return;
      _listController.jumpTo(_listController.position.maxScrollExtent);
    });
  }

  /// Dialog komentar saat user menilai jawaban "kurang tepat".
  ///
  /// Mengembalikan `null` bila dibatalkan, atau teks (boleh kosong) bila
  /// dikirim.
  Future<String?> _askComment() => showDialog<String>(
    context: context,
    builder: (dialogContext) => const _CommentDialog(),
  );

  Future<void> _handleFeedback(
    ChatExchange exchange,
    ChatFeedback feedback,
  ) async {
    String? comment;
    if (feedback == ChatFeedback.notHelpful) {
      comment = await _askComment();
      if (comment == null) return; // dibatalkan
    }

    try {
      await ref
          .read(chatControllerProvider.notifier)
          .sendFeedback(
            exchangeId: exchange.id,
            feedback: feedback,
            comment: comment,
          );
      if (!mounted) return;
      _pesan(feedback == ChatFeedback.helpful
          ? 'Terima kasih! Masukanmu membantu AI belajar.'
          : 'Masukanmu sudah dikirim.');
    } on ChatException catch (error) {
      if (!mounted) return;
      _pesan(error.message);
    }
  }

  void _pesan(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _clearTextInputs() {
    _codeController.clear();
    _errorController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref.watch(chatControllerProvider);
    final isSending = conversation.isSending;
    final canSend = _codeController.text.trim().isNotEmpty && !isSending;
    // Ukuran font editor mengikuti preferensi lokal (layar Pengaturan), sama
    // seperti `--editor-font-size` di web.
    final editorFontSize = ref.watch(
      appSettingsProvider.select((settings) => settings.editorFontSize),
    );

    // Gulirkan ke bawah setiap kali percakapan berubah (bubble baru / jawaban).
    ref.listen<ChatConversation>(chatControllerProvider, (previous, next) {
      _scheduleScrollToBottom();
    });

    return Column(
      children: [
        Expanded(
          child: conversation.isEmpty
              ? const _EmptyChatView()
              : ListView.builder(
                  controller: _listController,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  itemCount: conversation.exchanges.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ExchangeView(
                      exchange: conversation.exchanges[index],
                      onFeedback: _handleFeedback,
                      onRetry: (id) =>
                          ref.read(chatControllerProvider.notifier).retry(id),
                    ),
                  ),
                ),
        ),
        _Composer(
          language: _language,
          onLanguageChanged: isSending
              ? null
              : (value) => setState(() => _language = value),
          codeController: _codeController,
          errorController: _errorController,
          editorFontSize: editorFontSize,
          isSending: isSending,
          canSend: canSend,
          hasConversation: conversation.exchanges.isNotEmpty,
          onSend: _send,
          onClear: _clearTextInputs,
        ),
      ],
    );
  }
}

/// Satu pasangan tanya-jawab (pesan user + balasan/loading/error).
class _ExchangeView extends StatelessWidget {
  const _ExchangeView({
    required this.exchange,
    required this.onFeedback,
    required this.onRetry,
  });

  final ChatExchange exchange;
  final Future<void> Function(ChatExchange, ChatFeedback) onFeedback;
  final ValueChanged<String> onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChatUserBubble(exchange: exchange),
        const SizedBox(height: 10),
        if (exchange.answer != null)
          ChatAssistantBubble(
            exchange: exchange,
            onFeedback: (feedback) => onFeedback(exchange, feedback),
          )
        else if (exchange.hasFailed)
          ChatFailedBubble(
            message: exchange.error!,
            onRetry: () => onRetry(exchange.id),
          )
        else
          ChatPendingBubble(language: exchange.language),
      ],
    );
  }
}

// =============================================================================
// Keadaan kosong
// =============================================================================
class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentPink.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.bug_report_outlined,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Tempel kode & pesan errornya',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'CodeMentor AI menjelaskan penyebabnya langkah demi langkah, '
            'lengkap dengan saran perbaikan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.panelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CARA PAKAI', style: AppTheme.monoLabel),
                const SizedBox(height: 10),
                for (final step in const [
                  'Pilih bahasa pemrogramannya',
                  'Tempel kode yang bermasalah',
                  'Isi pesan error (bila ada)',
                  'Tekan Kirim dan baca penjelasannya',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.arrow_right_alt,
                          size: 16,
                          color: AppColors.accentPink,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            step,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Panel input
// =============================================================================
class _Composer extends StatelessWidget {
  const _Composer({
    required this.language,
    required this.onLanguageChanged,
    required this.codeController,
    required this.errorController,
    required this.editorFontSize,
    required this.isSending,
    required this.canSend,
    required this.hasConversation,
    required this.onSend,
    required this.onClear,
  });

  final String language;
  final ValueChanged<String>? onLanguageChanged;
  final TextEditingController codeController;
  final TextEditingController errorController;

  /// Ukuran font editor kode (dari preferensi lokal).
  final double editorFontSize;

  final bool isSending;
  final bool canSend;
  final bool hasConversation;
  final VoidCallback onSend;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.code,
                size: 16,
                color: AppColors.accentPink,
              ),
              const SizedBox(width: 8),
              _LanguagePicker(
                value: language,
                onChanged: onLanguageChanged,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: !isSending ? onClear : null,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Bersihkan'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: codeController,
            enabled: !isSending,
            minLines: 3,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            style: AppTheme.mono(
              fontSize: editorFontSize - 1.5,
              letterSpacing: 0,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: '# tempel kodemu di sini',
              fillColor: AppColors.inputBg,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: errorController,
            enabled: !isSending,
            maxLines: 1,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (canSend) onSend();
            },
            style: const TextStyle(fontSize: 13.5),
            decoration: const InputDecoration(
              hintText: 'Pesan error (opsional) — mis. NameError: ...',
              fillColor: AppColors.inputBg,
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  isSending
                      ? 'Menunggu jawaban AI...'
                      : 'AI menjelaskan penyebab & solusinya',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              GradientButton(
                label: 'Kirim',
                icon: Icons.send_rounded,
                loading: isSending,
                onPressed: isSending || !canSend ? null : onSend,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        border: Border.all(color: AppColors.inputBorder),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged == null
              ? null
              : (next) {
                  if (next != null) onChanged!(next);
                },
          dropdownColor: AppColors.surface3,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: AppColors.textMuted,
          ),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          items: [
            for (final entry in ApiConstants.languageLabels.entries)
              DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dialog isi komentar untuk penilaian "kurang tepat".
///
/// Controller teks dimiliki `State` ini (bukan variabel lokal pemanggil) supaya
/// tidak ada `TextEditingController` yang dipakai setelah dibuang: dialog masih
/// membangun ulang selama animasi keluar setelah `showDialog` selesai.
class _CommentDialog extends StatefulWidget {
  const _CommentDialog();

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Apa yang kurang tepat?'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Opsional — tulis masukanmu di sini',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: AppTheme.paperButtonStyle.copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
          ),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Kirim'),
        ),
      ],
    );
  }
}
