import 'package:codementor_mobile/core/router/app_routes.dart';
import 'package:codementor_mobile/features/admin/data/admin_user.dart';
import 'package:codementor_mobile/features/admin/data/admin_users_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_test_harness.dart';
import 'support/fake_admin_users_repository.dart';

Future<void> _openAdminUsers(
  WidgetTester tester, {
  FakeAdminUsersRepository? repo,
}) async {
  tester.view.physicalSize = const Size(400, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await pumpApp(
    tester,
    session: adminSession(),
    adminUsersRepository: repo ?? FakeAdminUsersRepository(),
  );
  routerOf(tester).go(AppRoutes.admin);
  await pumpSteps(tester, steps: 10);
}

void main() {
  configureAppTests();

  testWidgets('tab USER menampilkan daftar user', (tester) async {
    final repo = FakeAdminUsersRepository(
      users: [
        fakeAdminUser(
          id: 'u1',
          name: 'Budi Santoso',
          email: 'budi@example.com',
          role: 'USER',
        ),
        fakeAdminUser(
          id: 'u2',
          name: 'Admin Cik',
          email: 'admin@codementor.com',
          role: 'ADMIN',
        ),
      ],
    );

    await _openAdminUsers(tester, repo: repo);

    // Pindah ke tab USER
    await tester.tap(find.text('USER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Kelola User'), findsOneWidget);
    expect(find.text('Kelola akun pengguna CodeMentor AI'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('admin@codementor.com'), findsOneWidget);
    expect(find.text('Admin Cik'), findsOneWidget);
  });

  testWidgets('pencarian user filter nama atau email', (tester) async {
    final repo = FakeAdminUsersRepository(
      users: [
        fakeAdminUser(id: 'u1', name: 'Budi', email: 'budi@example.com'),
        fakeAdminUser(id: 'u2', name: 'Citra', email: 'citra@example.com'),
      ],
    );

    await _openAdminUsers(tester, repo: repo);

    await tester.tap(find.text('USER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final search = find.widgetWithText(TextField, 'Cari nama atau email...');
    expect(search, findsOneWidget);
    await tester.enterText(search, 'citra');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Budi'), findsNothing);
    expect(find.text('Citra'), findsOneWidget);
  });

  testWidgets('tambah user: form terisi, simpan, muncul pesan berhasil', (tester) async {
    final repo = FakeAdminUsersRepository(users: []);

    await _openAdminUsers(tester, repo: repo);

    await tester.tap(find.text('USER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Tambah'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final nameField = find.descendant(
      of: find.byType(Scaffold),
      matching: find.widgetWithText(TextField, 'contoh: Budi Santoso'),
    );
    final emailField = find.descendant(
      of: find.byType(Scaffold),
      matching: find.widgetWithText(TextField, 'nama@example.com'),
    );
    final passField = find.descendant(
      of: find.byType(Scaffold),
      matching: find.widgetWithText(TextField, 'Minimal 6 karakter'),
    );

    expect(nameField, findsOneWidget);
    expect(emailField, findsOneWidget);
    expect(passField, findsOneWidget);

    await tester.enterText(nameField, 'Citra');
    await tester.enterText(emailField, 'citra@example.com');
    await tester.enterText(passField, '123456');

    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('User berhasil ditambahkan.'), findsOneWidget);
    expect(find.text('Citra'), findsOneWidget);
  });

  testWidgets('edit user: ubah role menjadi ADMIN', (tester) async {
    final repo = FakeAdminUsersRepository(
      users: [
        fakeAdminUser(id: 'u1', name: 'Budi', email: 'budi@example.com', role: 'USER'),
      ],
    );

    await _openAdminUsers(tester, repo: repo);

    await tester.tap(find.text('USER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Edit user').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Buka dropdown Role
    await tester.tap(find.text('USER').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('ADMIN').last);
    await tester.pump();

    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('User berhasil diperbarui.'), findsOneWidget);
    expect(find.text('ADMIN'), findsAtLeastNWidgets(1));
  });

  testWidgets('hapus user: konfirmasi Ya, Hapus menampilkan pesan', (tester) async {
    final repo = FakeAdminUsersRepository(
      users: [
        fakeAdminUser(id: 'u1', name: 'Budi', email: 'budi@example.com'),
      ],
    );

    await _openAdminUsers(tester, repo: repo);

    await tester.tap(find.text('USER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Hapus user').first);
    await tester.pump();

    expect(find.text('Hapus User?'), findsOneWidget);
    await tester.tap(find.text('Ya, Hapus'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('User berhasil dihapus.'), findsOneWidget);
    expect(find.text('Belum ada user.'), findsOneWidget);
  });

  testWidgets('pagination: dengan >10 user muncul tombol Sebelumnya/Berikutnya', (tester) async {
    final users = List<AdminUser>.generate(
      12,
      (i) => fakeAdminUser(
        id: 'u$i',
        name: 'User $i',
        email: 'user$i@example.com',
      ),
    );
    final repo = FakeAdminUsersRepository(users: users);

    await _openAdminUsers(tester, repo: repo);

    await tester.tap(find.text('USER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Menampilkan 10 dari 12 user'), findsOneWidget);
    expect(find.text('Sebelumnya'), findsOneWidget);
    expect(find.text('Berikutnya'), findsOneWidget);
  });

  testWidgets('403 server diteruskan: pesan Forbidden muncul di SnackBar', (tester) async {
    final repo = FakeAdminUsersRepository(users: []);
    repo.listError = const AdminUserException('Forbidden');

    await _openAdminUsers(tester, repo: repo);

    await tester.tap(find.text('USER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Forbidden'), findsOneWidget);
  });
}
