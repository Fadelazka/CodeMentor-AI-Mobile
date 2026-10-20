import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/export_saver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/badge_pill.dart';
import '../../../core/widgets/gradient_button.dart';
import '../data/history_controller.dart';
import '../data/history_repository.dart';
import '../domain/chat_history_item.dart';

/// Layar "Riwayat" — padanan `src/app/(app)/riwayat/page.tsx`.
///
/// Perilaku yang disamakan dengan web:
/// - daftar dari `GET /api/history?limit=50` (+ `language` bila difilter),
/// - pencarian teks disaring LOKAL (web juga begitu: tidak memanggil API),
/// - hapus satu entri & hapus semua, dengan konfirmasi,
/// - ekspor CSV/JSON lewat `GET /api/history/export`.
///
/// Bedanya di mobile: hasil ekspor dibagikan lewat share sheet (padanan
/// "unduh" di browser), lihat [ExportSaver].
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// true saat berkas ekspor sedang diambil/dibagikan.
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    ref.read(historyFilterProvider.notifier).setQuery(_searchController.text);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _pesan(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openExportSheet() async {
    final format = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXxl),
        ),
      ),
      builder: (sheetContext) => const _ExportSheet(),
    );
    if (format == null) return;
    await _export(format);
  }

  /// Mengambil berkas dari server lalu membagikannya (CSV/JSON).
  Future<void> _export(String format) async {
    final filter = ref.read(historyFilterProvider);

    setState(() => _isExporting = true);
    try {
      final file = await ref
          .read(historyRepositoryProvider)
          .exportHistory(
            format: format,
            language: filter.language,
            query: filter.query.trim(),
          );
      final message = await ref.read(exportSaverProvider).save(file);
      if (!mounted) return;
      _pesan(message);
    } on HistoryException catch (error) {
      if (!mounted) return;
      _pesan(error.message);
    } on ExportException catch (error) {
      if (!mounted) return;
      _pesan(error.message);
    } catch (error) {
      if (!mounted) return;
      _pesan('Gagal mengekspor riwayat.');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _deleteOne(ChatHistoryItem item) async {
    final confirmed = await _confirm(
      title: 'Hapus riwayat ini?',
      message:
          'Riwayat ${item.languageLabel} (${item.errorCodeLabel}) akan '
          'dihapus permanen.',
    );
    if (confirmed != true) return;

    try {
      await ref.read(historyRepositoryProvider).deleteOne(item.id);
      ref.invalidate(historyListProvider);
      if (!mounted) return;
      _pesan('Riwayat dihapus.');
    } on HistoryException catch (error) {
      if (!mounted) return;
      _pesan(error.message);
    }
  }

  Future<void> _deleteAll() async {
    final confirmed = await _confirm(
      title: 'Hapus SEMUA riwayat?',
      message: 'Tindakan ini tidak dapat dibatalkan.',
    );
    if (confirmed != true) return;

    try {
      await ref.read(historyRepositoryProvider).deleteAll();
      ref.invalidate(historyListProvider);
      if (!mounted) return;
      _pesan('Semua riwayat dihapus.');
    } on HistoryException catch (error) {
      if (!mounted) return;
      _pesan(error.message);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
  }) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
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

  void _resetFilter() {
    _searchController.clear();
    ref.read(historyFilterProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(historyFilterProvider);
    final listAsync = ref.watch(historyListProvider);
    final rows = listAsync.value ?? const <ChatHistoryItem>[];
    final filtered = [
      for (final item in rows)
        if (item.matches(filter.query)) item,
    ];

    return RefreshIndicator(
      color: AppColors.accentPink,
      backgroundColor: AppColors.surface2,
      onRefresh: () async {
        ref.invalidate(historyListProvider);
        await ref.read(historyListProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          const _Header(),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isExporting ? null : _openExportSheet,
                style: _outlineButtonStyle(),
                icon: _isExporting
                    ? const SizedBox(
                        height: 15,
                        width: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentPink,
                        ),
                      )
                    : const Icon(Icons.download_outlined, size: 17),
                label: Text(_isExporting ? 'Meng-export...' : 'Ekspor'),
              ),
              if (rows.isNotEmpty) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _deleteAll,
                  style: _outlineButtonStyle(danger: true),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 17),
                  label: const Text('Hapus Semua'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Cari error, atau kata kunci dalam kode...',
              fillColor: AppColors.inputBg,
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: AppColors.textMuted,
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          _LanguageSelect(
            value: filter.language,
            onChanged: (value) =>
                ref.read(historyFilterProvider.notifier).setLanguage(value),
          ),
          if (filter.isActive)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _resetFilter,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.close, size: 15),
                label: const Text('Reset filter', style: TextStyle(fontSize: 12)),
              ),
            ),
          const SizedBox(height: 14),
          if (listAsync.hasError && !listAsync.hasValue)
            _ErrorPanel(
              message: listAsync.error is HistoryException
                  ? (listAsync.error! as HistoryException).message
                  : 'Terjadi kesalahan tak terduga.',
              onRetry: () => ref.invalidate(historyListProvider),
            )
          else if (!listAsync.hasValue)
            const _SkeletonList()
          else if (filtered.isEmpty && rows.isEmpty)
            _EmptyPanel(
              title: 'Belum ada riwayat',
              description:
                  'Coba tanyakan error pertama Anda di halaman Chat AI.',
              action: GradientButton(
                label: 'Mulai Bertanya',
                icon: Icons.forum_outlined,
                onPressed: () => context.go(AppRoutes.chat),
              ),
            )
          else if (filtered.isEmpty)
            const _EmptyPanel(
              title: 'Tidak ada hasil filter',
              description: 'Coba ubah kata kunci atau filter bahasa.',
            )
          else
            for (final item in filtered) ...[
              _HistoryCard(
                item: item,
                onOpen: () => context.go(AppRoutes.historyDetail(item.id)),
                onDelete: () => _deleteOne(item),
              ),
              const SizedBox(height: 14),
            ],
          if (filtered.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Divider(height: 1, color: AppColors.borderSoft),
            const SizedBox(height: 12),
            Text(
              'Menampilkan ${filtered.length} dari ${rows.length} riwayat',
              style: AppTheme.mono(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  /// Gaya tombol garis (padanan `GradientButton variant="outline"` di web).
  ButtonStyle _outlineButtonStyle({bool danger = false}) {
    final color = danger ? AppColors.neonPink : AppColors.textSecondary;
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
    );
  }
}

// =============================================================================
// Kepala halaman
// =============================================================================
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RIWAYAT', style: AppTheme.monoEyebrow),
        const SizedBox(height: 6),
        const Text(
          'Riwayat Analisis',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Semua error yang pernah Anda tanyakan, tersimpan rapi untuk '
          'dipelajari kembali.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Pemilih bahasa (filter server)
// =============================================================================
class _LanguageSelect extends StatelessWidget {
  const _LanguageSelect({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        border: Border.all(color: AppColors.inputBorder),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          dropdownColor: AppColors.surface3,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 20,
            color: AppColors.textMuted,
          ),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          items: [
            const DropdownMenuItem(value: 'all', child: Text('Semua Bahasa')),
            for (final entry in ApiConstants.languageLabels.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Kartu satu riwayat
// =============================================================================
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.onOpen,
    required this.onDelete,
  });

  final ChatHistoryItem item;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.panelDecoration(color: Colors.transparent),
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
                  BadgePill(label: item.errorCodeLabel, tone: BadgeTone.pink),
                  if (item.confidence != null)
                    BadgePill(
                      label: 'Confidence ${item.confidence}%',
                      tone: BadgePill.toneForConfidence(item.confidence!),
                    ),
                  Text(
                    item.formattedDate,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF05060A),
                  border: Border.all(color: AppColors.borderSoft),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Text(
                  item.sourceCode,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.mono(
                    fontSize: 11,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                item.responsePreview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onOpen,
                    style: _cardButtonStyle(),
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('Buka'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    style: _cardButtonStyle(
                      color: AppColors.neonPink,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 15),
                    label: const Text('Hapus'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static ButtonStyle _cardButtonStyle({Color color = AppColors.textMuted}) =>
      OutlinedButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
      );
}

// =============================================================================
// Bagian: keadaan kosong, gagal, dan memuat
// =============================================================================
class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.title,
    required this.description,
    this.action,
  });

  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: AppColors.accentPink.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            ),
            child: const Icon(
              Icons.history,
              size: 22,
              color: AppColors.accentPink,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 26,
            color: AppColors.neonAmber,
          ),
          const SizedBox(height: 10),
          const Text(
            'Gagal memuat riwayat',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}

/// Kerangka pemuatan — 5 kotak seperti `LoadingSkeleton` di web.
class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < 5; index++) ...[
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              border: Border.all(color: AppColors.borderSoft),
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

// =============================================================================
// Lembar pilihan format ekspor (padanan ExportDropdown di web)
// =============================================================================
class _ExportSheet extends StatelessWidget {
  const _ExportSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            height: 4,
            width: 42,
            decoration: BoxDecoration(
              color: AppColors.borderHover,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'EKSPOR RIWAYAT',
            style: AppTheme.mono(fontSize: 10, letterSpacing: 1.2),
          ),
          const SizedBox(height: 4),
          const _ExportOption(
            format: 'csv',
            label: 'Export CSV',
            description: 'Buka di Excel / Google Sheets',
            icon: Icons.table_chart_outlined,
          ),
          const _ExportOption(
            format: 'json',
            label: 'Export JSON',
            description: 'Untuk backup atau developer',
            icon: Icons.data_object,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.format,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String format;
  final String label;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(format),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: AppColors.accentPink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Icon(icon, size: 17, color: AppColors.accentPink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
