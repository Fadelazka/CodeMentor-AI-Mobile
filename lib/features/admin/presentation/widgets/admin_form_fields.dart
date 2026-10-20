import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Label field untuk form admin (meniru pola KB).
class FieldLabel extends StatelessWidget {
  const FieldLabel(
    this.text, {
    super.key,
    this.showRequired = true,
    this.error,
  });

  final String text;
  final bool showRequired;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null && error!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          showRequired ? '$text *' : text,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: 0.6,
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.accentPink,
            ),
          ),
        ],
      ],
    );
  }
}

/// Input teks terstandar untuk form admin.
class FieldTextInput extends StatelessWidget {
  const FieldTextInput({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.helper,
    this.enabled = true,
    this.maxLines = 1,
    this.mono = false,
    this.showRequired = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? error;
  final String? helper;
  final bool enabled;
  final int maxLines;
  final bool mono;
  final bool showRequired;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null && error!.isNotEmpty;
    final baseStyle = mono ? AppTheme.mono(fontSize: 13) : const TextStyle(fontSize: 13.5, height: 1.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label, showRequired: showRequired, error: error),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          style: baseStyle.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            fillColor: enabled ? AppColors.inputBg : AppColors.surface2,
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg - 2),
              borderSide: BorderSide(color: hasError ? AppColors.accentPink : AppColors.borderSoft),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg - 2),
              borderSide: BorderSide(
                color: hasError ? AppColors.accentPink : AppColors.textSecondary,
                width: 1.4,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg - 2),
              borderSide: const BorderSide(color: AppColors.borderSoft),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: maxLines > 1 ? 12 : 10,
            ),
            isDense: true,
          ),
        ),
        if (helper != null && helper!.isNotEmpty && !hasError) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

/// Kotak pesan server (sukses/error) untuk form.
class ServerErrorBox extends StatelessWidget {
  const ServerErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        border: Border.all(color: AppColors.accentPink.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.accentPink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTheme.mono(
                fontSize: 12,
                letterSpacing: 0.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
