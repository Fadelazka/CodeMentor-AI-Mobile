import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';

/// Layar Edit Profil — mirip `EditProfileModal` di web.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _nimController;
  late final TextEditingController _emailController;

  String? _favoriteLanguage;
  File? _pickedImage;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authRepositoryProvider).session?.user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _nimController = TextEditingController(text: user?.nim ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _favoriteLanguage = user?.favoriteLanguage;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nimController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (picked == null) return;
      final file = File(picked.path);
      final size = await file.length();
      if (size > 2 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ukuran maksimal 2MB')),
        );
        return;
      }
      setState(() => _pickedImage = file);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memilih foto')),
      );
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Periksa kembali nama/email');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(profileRepositoryProvider);
      if (_pickedImage != null) {
        await repo.uploadAvatar(_pickedImage!);
      }
      await repo.updateProfile(
        name: name,
        email: email,
        nim: _nimController.text,
        favoriteLanguage: _favoriteLanguage,
      );
      await ref.read(authRepositoryProvider).fetchSession();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil diperbarui')),
      );
      Navigator.of(context).pop(true);
    } on ProfileException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).session?.user;
    final initial = (user?.name?.trim().isNotEmpty == true)
        ? user!.name!.trim()[0].toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.surface2,
                  child: _pickedImage != null
                      ? ClipOval(
                          child: Image.file(
                            _pickedImage!,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    onPressed: _saving ? null : _pickImage,
                    icon: const Icon(Icons.camera_alt, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _saving ? null : _pickImage,
              child: Text(_pickedImage == null ? 'Pilih Foto' : 'Ganti Foto'),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'JPG, PNG, WEBP, GIF. Maks 2MB.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 18),
          if (_error != null) ...[
            Text(
              _error!,
              style: const TextStyle(color: AppColors.accentPink, fontSize: 13),
            ),
            const SizedBox(height: 10),
          ],
          _field('Nama', _nameController),
          const SizedBox(height: 12),
          _field('NIM', _nimController),
          const SizedBox(height: 12),
          _dropdown(),
          const SizedBox(height: 12),
          _field('Email', _emailController),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GradientButton(
                  label: _saving ? 'Mengunggah...' : 'Simpan',
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: controller, decoration: const InputDecoration()),
      ],
    );
  }

  Widget _dropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bahasa Favorit', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _favoriteLanguage,
          decoration: const InputDecoration(),
          items: const [
            DropdownMenuItem(value: null, child: Text('Pilih bahasa')),
            DropdownMenuItem(value: 'python', child: Text('Python')),
            DropdownMenuItem(value: 'javascript', child: Text('JavaScript')),
            DropdownMenuItem(value: 'java', child: Text('Java')),
            DropdownMenuItem(value: 'cpp', child: Text('C++')),
            DropdownMenuItem(value: 'php', child: Text('PHP')),
          ],
          onChanged: _saving ? null : (v) => setState(() => _favoriteLanguage = v),
        ),
      ],
    );
  }
}
