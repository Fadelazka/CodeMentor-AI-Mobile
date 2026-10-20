import 'package:codementor_mobile/features/admin/data/admin_user.dart';
import 'package:codementor_mobile/features/admin/data/admin_users_repository.dart';
import 'package:dio/dio.dart';

/// User contoh untuk test.
AdminUser fakeAdminUser({
  String id = 'user-1',
  String? name = 'Budi Santoso',
  String? email = 'budi@example.com',
  String role = 'USER',
  DateTime? createdAt,
}) => AdminUser(
      id: id,
      name: name,
      email: email,
      role: role,
      createdAt: createdAt ?? DateTime(2026, 10, 6),
    );

/// Repository Kelola User tanpa jaringan untuk test UI.
class FakeAdminUsersRepository extends AdminUsersRepository {
  FakeAdminUsersRepository({List<AdminUser>? users})
      : users = users ?? <AdminUser>[],
        super(dio: Dio());

  /// Daftar user yang dianggap tersimpan di "server".
  List<AdminUser> users;

  int listFetchCount = 0;

  final List<AdminUserDraft> createdDrafts = <AdminUserDraft>[];
  final List<String> updatedIds = <String>[];
  final List<AdminUserDraft> updatedDrafts = <AdminUserDraft>[];
  final List<String> deletedIds = <String>[];

  String createdMessage = 'User berhasil ditambahkan.';
  String updatedMessage = 'User berhasil diperbarui.';
  String deletedMessage = 'User berhasil dihapus.';

  AdminUserException? listError;
  AdminUserException? createError;
  AdminUserException? updateError;
  AdminUserException? deleteError;

  @override
  Future<List<AdminUser>> fetchUsers() async {
    listFetchCount++;
    final error = listError;
    if (error != null) throw error;
    return List<AdminUser>.of(users);
  }

  @override
  Future<AdminUserMutationResult> createUser(AdminUserDraft draft) async {
    createdDrafts.add(draft);
    final error = createError;
    if (error != null) throw error;

    final created = _fromDraft(draft, id: 'user-new-${users.length + 1}');
    users = [created, ...users];
    return AdminUserMutationResult(user: created, message: createdMessage);
  }

  @override
  Future<AdminUserMutationResult> updateUser(
    String id,
    AdminUserDraft draft,
  ) async {
    updatedIds.add(id);
    updatedDrafts.add(draft);
    final error = updateError;
    if (error != null) throw error;

    final updated = _fromDraft(draft, id: id);
    users = [for (final user in users) user.id == id ? updated : user];
    return AdminUserMutationResult(user: updated, message: updatedMessage);
  }

  @override
  Future<String> deleteUser(String id) async {
    deletedIds.add(id);
    final error = deleteError;
    if (error != null) throw error;

    users = [for (final user in users) if (user.id != id) user];
    return deletedMessage;
  }

  AdminUser _fromDraft(AdminUserDraft draft, {required String id}) => AdminUser(
        id: id,
        name: draft.name.trim(),
        email: draft.email.trim().toLowerCase(),
        role: draft.role,
        createdAt: DateTime(2026, 10, 7),
      );
}
