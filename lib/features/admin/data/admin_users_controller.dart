import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_user.dart';
import 'admin_users_repository.dart';

/// Daftar user untuk tab **Kelola User** di layar Admin.
final adminUsersProvider =
    AsyncNotifierProvider<AdminUsersNotifier, List<AdminUser>>(
  AdminUsersNotifier.new,
);

class AdminUsersNotifier extends AsyncNotifier<List<AdminUser>> {
  @override
  Future<List<AdminUser>> build() =>
      ref.watch(adminUsersRepositoryProvider).fetchUsers();

  AdminUsersRepository get _repository => ref.read(adminUsersRepositoryProvider);

  /// Tambah user; daftar lokal langsung dimasukkan entri baru di depan.
  Future<AdminUserMutationResult> create(AdminUserDraft draft) async {
    final result = await _repository.createUser(draft);
    state = AsyncData([
      result.user,
      for (final user in state.value ?? const <AdminUser>[]) user,
    ]);
    return result;
  }

  /// Edit user; entri lama ditimpa di tempat (tidak berpindah posisi).
  Future<AdminUserMutationResult> updateUser(
    String id,
    AdminUserDraft draft,
  ) async {
    final result = await _repository.updateUser(id, draft);
    _replace(result.user);
    return result;
  }

  /// Hapus user; entri dibuang dari daftar lokal dan pesan server dikembalikan.
  Future<String> remove(String id) async {
    final message = await _repository.deleteUser(id);
    state = AsyncData([
      for (final user in state.value ?? const <AdminUser>[])
        if (user.id != id) user,
    ]);
    return message;
  }

  void _replace(AdminUser updated) {
    state = AsyncData([
      for (final user in state.value ?? const <AdminUser>[])
        user.id == updated.id ? updated : user,
    ]);
  }
}

/// Kata kunci pencarian lokal di tab Kelola User.
class AdminUserSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void change(String value) => state = value;

  void clear() => state = '';
}

final adminUserSearchProvider = NotifierProvider<AdminUserSearchNotifier, String>(
  AdminUserSearchNotifier.new,
);

/// Query pencarian + halaman (meniru pagination web, 10 per halaman).
class AdminUserQuery {
  const AdminUserQuery({this.keyword = '', this.pageIndex = 0});

  final String keyword;
  final int pageIndex;

  AdminUserQuery copyWith({String? keyword, int? pageIndex}) {
    return AdminUserQuery(
      keyword: keyword ?? this.keyword,
      pageIndex: pageIndex ?? this.pageIndex,
    );
  }
}

class AdminUserQueryNotifier extends Notifier<AdminUserQuery> {
  @override
  AdminUserQuery build() => const AdminUserQuery();

  void search(String keyword) => state = AdminUserQuery(keyword: keyword);

  void goToPage(int index) => state = state.copyWith(pageIndex: index);

  void resetPage() => state = state.copyWith(pageIndex: 0);
}

final adminUserQueryProvider =
    NotifierProvider<AdminUserQueryNotifier, AdminUserQuery>(
  AdminUserQueryNotifier.new,
);
