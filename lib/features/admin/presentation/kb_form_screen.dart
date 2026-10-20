import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../data/kb_controller.dart';
import '../data/kb_entry.dart';
import '../data/kb_repository.dart';
import 'widgets/admin_form_fields.dart';

/// Form tambah/edit satu rekaman Knowledge Base.
///
/// Padanan `KbModal` di web (`src/components/admin/kb-modal.tsx`): field,
/// label, pesan validasi, dan teks tombol disamakan persis.
///
/// Layar ini dipush sebagai halaman penuh (bukan dialog) karena field-nya
/// banyak — lebih nyaman di layar HP. Hasil pop: [KbMutationResult] bila
/// tersimpan, agar pemanggil menampilkan pesan dari server.
class KbFormScreen extends ConsumerStatefulWidget {
  const KbFormScreen({super.key, this.record});

  /// `null` = tambah rekaman baru; terisi = edit rekaman lama
  /// (judul, tombol, dan body PUT menyesuaikan — lihat web `isEdit`).
  final KbEntry? record;

  @override
  ConsumerState<KbFormScreen> createState() => _KbFormScreenState();
}

class _KbFormScreenState extends ConsumerState<KbFormScreen> {
  late final TextEditingController _errorCodeController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _solutionController;
  late final TextEditingController _examplesController;
  late final TextEditingController _tagsController;

  late String _language;
  late bool _isActive;
  bool _saving = false;

  /// Error per field, kunci = nama field ('language', 'errorCode', ...).
  Map<String, String> _errors = const {};
  String? _serverError;

  bool get _isEdit => widget.record != null;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _language = record?.language ?? ApiConstants.supportedLanguages.first;
    _isActive = record?.isActive ?? true;
    _errorCodeController = TextEditingController(text: record?.errorCode ?? '');
    _titleController = TextEditingController(text: record?.title ?? '');
    _descriptionController = TextEditingController(
      text: record?.description ?? '',
    );
    _solutionController = TextEditingController(text: record?.solution ?? '');
    _examplesController = TextEditingController(text: record?.examples ?? '');
    _tagsController = TextEditingController(
      text: KbEntryDraft.tagsToText(record?.tags ?? const []),
    );
  }

  @override
  void dispose() {
    _errorCodeController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _solutionController.dispose();
    _examplesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  KbEntryDraft _currentDraft() => KbEntryDraft(
    language: _language,
    errorCode: _errorCodeController.text,
    title: _titleController.text,
    description: _descriptionController.text,
    solution: _solutionController.text,
    examples: _examplesController.text,
    tags: KbEntryDraft.tagsFromText(_tagsController.text),
    isActive: _isActive,
  );

  Future<void> _save() async {
    final draft = _currentDraft();

    // Validasi per field — pesan yang dipakai sama dengan `validate()` model.
    setState(() {
      _errors = <String, String>{
        if (draft.language.trim().isEmpty)
          'language': KbEntryDraft.errLanguage,
        if (draft.errorCode.trim().isEmpty)
          'errorCode': KbEntryDraft.errErrorCode,
        if (draft.title.trim().isEmpty) 'title': KbEntryDraft.errTitle,
        if (draft.description.trim().isEmpty)
          'description': KbEntryDraft.errDescription,
        if (draft.solution.trim().isEmpty)
          'solution': KbEntryDraft.errSolution,
      };
      _serverError = null;
    });
    if (_errors.isNotEmpty) return;

    setState(() => _saving = true);

    try {
      final notifier = ref.read(kbListProvider.notifier);
      final result = _isEdit
          ? await notifier.updateEntry(widget.record!.id, draft)
          : await notifier.create(draft);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on KbException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverError = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Rekaman Error' : 'Tambah Rekaman Error'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          const Text(
            'Isi detail rekaman knowledge base yang ingin disimpan.',
            style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
          ),
          if (_serverError != null) ...[
            const SizedBox(height: 14),
            ServerErrorBox(message: _serverError!),
          ],
          const SizedBox(height: 16),
          FieldLabel('Bahasa Pemrograman', error: _errors['language']),
          // Dropdown polos (bukan `DropdownButtonFormField`) seperti dropdown
          // filter di layar Riwayat: tema global memakai `filled` + warna latar,
          // yang memicu assertion ListTile-in-DecroatedBox padaFormField.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              border: Border.all(color: AppColors.inputBorder),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _language,
                isExpanded: true,
                dropdownColor: AppColors.surface2,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                items: [
                  for (final language in ApiConstants.supportedLanguages)
                    DropdownMenuItem(
                      value: language,
                      child: Text(
                        ApiConstants.languageLabels[language] ?? language,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _language = value ?? _language),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FieldTextInput(
            label: 'Tipe Error',
            hint: 'contoh: ZeroDivisionError',
            controller: _errorCodeController,
            error: _errors['errorCode'],
            enabled: !_saving,
            mono: true,
          ),
          const SizedBox(height: 14),
          FieldTextInput(
            label: 'Judul / Nama Error',
            hint: 'contoh: Pembagian dengan Nol',
            controller: _titleController,
            error: _errors['title'],
            enabled: !_saving,
          ),
          const SizedBox(height: 14),
          FieldTextInput(
            label: 'Deskripsi Masalah',
            hint: 'Apa yang terjadi dan kapan error ini muncul...',
            controller: _descriptionController,
            error: _errors['description'],
            enabled: !_saving,
            maxLines: 4,
          ),
          const SizedBox(height: 14),
          FieldTextInput(
            label: 'Solusi / Cara Perbaiki',
            hint: 'Langkah konkret untuk mengatasi error...',
            controller: _solutionController,
            error: _errors['solution'],
            enabled: !_saving,
            maxLines: 4,
          ),
          const SizedBox(height: 14),
          FieldTextInput(
            label: 'Contoh Kode Bermasalah',
            hint: '// tempel kode yang menyebabkan error (opsional)',
            controller: _examplesController,
            enabled: !_saving,
            maxLines: 4,
            mono: true,
            showRequired: false,
          ),
          const SizedBox(height: 14),
          FieldTextInput(
            label: 'Konsep Terkait',
            hint: 'contoh: Math, Division',
            helper: 'Pisahkan dengan koma.',
            controller: _tagsController,
            enabled: !_saving,
            showRequired: false,
          ),
          const SizedBox(height: 8),
          // Baris + Switch (bukan `SwitchListTile`): tema menggambar latar di
          // atas `DecoratedBox` panel, sementara ListTile melukis latarnya ke
          // Material terdekat -> memicu assertion bila dipakai langsung di sini.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 4, 4),
            decoration: AppTheme.panelDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isActive
                            ? 'Aktif: tersedia untuk RAG retrieval'
                            : 'Nonaktif: disembunyikan',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _isActive,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.inputBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    minimumSize: const Size(0, 46),
                  ),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: AppTheme.paperButtonStyle.copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Menyimpan...' : _isEdit ? 'Simpan Perubahan' : 'Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}






