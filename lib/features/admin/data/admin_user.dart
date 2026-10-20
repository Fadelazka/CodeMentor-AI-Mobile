import 'package:flutter/foundation.dart';

/// Satu akun user untuk tab Kelola User di layar Admin.
///
/// Meniru `AdminUser` di web (`src/components/admin/user-modal.tsx:7-13`):
/// hanya field yang diekspos route `GET /api/admin/users` — name, email, role, createdAt.
/// NIM, favoriteLanguage, image TIDAK dikembalikan API ini.
@immutable
class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'USER',
      createdAt: _parseDate(json['createdAt']),
    );
  }

  final String id;
  final String? name;
  final String? email;
  final String role;
  final DateTime createdAt;

  AdminUser copyWith({
    String? id,
    Object? name = _unset,
    Object? email = _unset,
    String? role,
    DateTime? createdAt,
  }) {
    return AdminUser(
      id: id ?? this.id,
      name: identical(name, _unset) ? this.name : name as String?,
      email: identical(email, _unset) ? this.email : email as String?,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Cocok dengan pencarian lokal di client (nama atau email).
  bool matches(String keyword) {
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) return true;
    final haystack = <String?>[name, email]
        .whereType<String>()
        .map((text) => text.toLowerCase())
        .join(' ');
    return haystack.contains(query);
  }

  static DateTime _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static const _unset = Object();
}

/// Draft form tambah/edit user (padanan `UserModal` di web).
class AdminUserDraft {
  const AdminUserDraft({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
  });

  final String name;
  final String email;
  final String password;
  final String role;

  AdminUserDraft copyWith({
    String? name,
    String? email,
    String? password,
    String? role,
  }) {
    return AdminUserDraft(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson({required bool isNew}) {
    final json = <String, dynamic>{
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'role': role,
    };
    if (isNew || password.isNotEmpty) {
      json['password'] = password;
    }
    return json;
  }

  /// Validasi per-field mengikuti pesan persis `src/components/admin/user-modal.tsx`.
  Map<String, String> validateFields({required bool isNew}) {
    final errors = <String, String>{};
    final trimmedName = name.trim();
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();

    if (trimmedName.length < 2) {
      errors['name'] = errName;
    }
    if (trimmedEmail.isEmpty) {
      errors['email'] = errEmailEmpty;
    } else if (!_emailRegex.hasMatch(trimmedEmail)) {
      errors['email'] = errEmailFormat;
    }
    if (isNew && trimmedPassword.isEmpty) {
      errors['password'] = errPasswordRequired;
    }
    if (trimmedPassword.isNotEmpty && trimmedPassword.length < 6) {
      errors['password'] = errPasswordShort;
    }
    if (role != 'USER' && role != 'ADMIN') {
      errors['role'] = errRole;
    }
    return errors;
  }

  String? validate({required bool isNew}) {
    final errors = validateFields(isNew: isNew);
    if (errors.isEmpty) return null;
    return errors.values.first;
  }

  static final RegExp _emailRegex =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static const String errName = 'Nama minimal 2 karakter.';
  static const String errEmailEmpty = 'Email wajib diisi.';
  static const String errEmailFormat = 'Format email tidak valid.';
  static const String errPasswordRequired = 'Password wajib diisi.';
  static const String errPasswordShort = 'Password minimal 6 karakter.';
  static const String errRole = 'Pilih role pengguna.';
}
