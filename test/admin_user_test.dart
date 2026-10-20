import 'package:codementor_mobile/features/admin/data/admin_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminUser', () {
    test('fromJson membaca field yang diekspos route users', () {
      final user = AdminUser.fromJson({
        'id': 'u1',
        'name': 'Budi',
        'email': 'budi@example.com',
        'role': 'ADMIN',
        'createdAt': '2026-10-06T10:00:00.000Z',
      });

      expect(user.id, 'u1');
      expect(user.name, 'Budi');
      expect(user.email, 'budi@example.com');
      expect(user.role, 'ADMIN');
    });

    test('matches melakukan filter lokal nama atau email', () {
      final user = AdminUser(
        id: 'u1',
        name: 'Budi Santoso',
        email: 'budi@example.com',
        role: 'USER',
        createdAt: _dummyDate,
      );

      expect(user.matches('budi'), isTrue);
      expect(user.matches('EXAMPLE'), isTrue);
      expect(user.matches('admin'), isFalse);
      expect(user.matches(''), isTrue);
    });
  });

  group('AdminUserDraft', () {
    test('validasi create: nama, email, password wajib', () {
      const draft = AdminUserDraft(
        name: 'A',
        email: '',
        password: '',
        role: 'USER',
      );

      final errors = draft.validateFields(isNew: true);
      expect(errors['name'], AdminUserDraft.errName);
      expect(errors['email'], AdminUserDraft.errEmailEmpty);
      expect(errors['password'], AdminUserDraft.errPasswordRequired);
    });

    test('validasi email format', () {
      const draft = AdminUserDraft(
        name: 'Budi',
        email: 'salah-email',
        password: '123456',
        role: 'USER',
      );

      expect(
        draft.validateFields(isNew: true)['email'],
        AdminUserDraft.errEmailFormat,
      );
    });

    test('validasi password minimal 6 saat diisi', () {
      const draft = AdminUserDraft(
        name: 'Budi',
        email: 'budi@example.com',
        password: '123',
        role: 'USER',
      );

      expect(
        draft.validateFields(isNew: true)['password'],
        AdminUserDraft.errPasswordShort,
      );
    });

    test('edit: password boleh kosong (tidak diubah)', () {
      const draft = AdminUserDraft(
        name: 'Budi',
        email: 'budi@example.com',
        password: '',
        role: 'ADMIN',
      );

      expect(draft.validate(isNew: false), isNull);
    });

    test('toJson create mengirim password', () {
      const draft = AdminUserDraft(
        name: 'Budi',
        email: 'Budi@Example.com',
        password: 'rahasia',
        role: 'USER',
      );

      final json = draft.toJson(isNew: true);
      expect(json['name'], 'Budi');
      expect(json['email'], 'budi@example.com');
      expect(json['password'], 'rahasia');
      expect(json['role'], 'USER');
    });

    test('toJson edit tanpa password tidak mengirim password', () {
      const draft = AdminUserDraft(
        name: 'Budi',
        email: 'budi@example.com',
        password: '',
        role: 'ADMIN',
      );

      final json = draft.toJson(isNew: false);
      expect(json.containsKey('password'), isFalse);
    });
  });
}

final _dummyDate = DateTime(2026, 10, 6);
