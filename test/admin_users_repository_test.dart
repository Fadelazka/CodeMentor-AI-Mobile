import 'package:codementor_mobile/features/admin/data/admin_user.dart';
import 'package:codementor_mobile/features/admin/data/admin_users_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminUsersRepository', () {
    test('fetchUsers memetakan daftar users', () async {
      final dio = _FakeDio(
        onGet: (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/api/admin/users'),
          statusCode: 200,
          data: {
            'users': [
              {
                'id': 'u1',
                'name': 'Budi',
                'email': 'budi@example.com',
                'role': 'USER',
                'createdAt': '2026-10-06T10:00:00.000Z',
              },
            ],
            'count': 1,
          },
        ),
      );

      final repo = AdminUsersRepository(dio: dio);
      final users = await repo.fetchUsers();

      expect(users.length, 1);
      expect(users.first.id, 'u1');
      expect(users.first.role, 'USER');
    });

    test('createUser POST ke endpoint users', () async {
      final dio = _FakeDio(
        onPost: (data) async {
          expect(data.path, '/api/admin/users');
          return Response<dynamic>(
            requestOptions: RequestOptions(path: data.path),
            statusCode: 201,
            data: {
              'user': {
                'id': 'u-new',
                'name': 'Citra',
                'email': 'citra@example.com',
                'role': 'ADMIN',
                'createdAt': '2026-10-07T10:00:00.000Z',
              },
              'message': 'User berhasil ditambahkan.',
            },
          );
        },
      );

      final repo = AdminUsersRepository(dio: dio);
      final result = await repo.createUser(
        const AdminUserDraft(
          name: 'Citra',
          email: 'citra@example.com',
          password: '123456',
          role: 'ADMIN',
        ),
      );

      expect(result.user.id, 'u-new');
      expect(result.message, 'User berhasil ditambahkan.');
    });

    test('updateUser PATCH ke /api/admin/users/{id}', () async {
      final dio = _FakeDio(
        onPatch: (data) async {
          expect(data.path, '/api/admin/users/u1');
          return Response<dynamic>(
            requestOptions: RequestOptions(path: data.path),
            statusCode: 200,
            data: {
              'user': {
                'id': 'u1',
                'name': 'Budi',
                'email': 'budi@example.com',
                'role': 'ADMIN',
                'createdAt': '2026-10-06T10:00:00.000Z',
              },
              'message': 'User berhasil diperbarui.',
            },
          );
        },
      );

      final repo = AdminUsersRepository(dio: dio);
      final result = await repo.updateUser(
        'u1',
        const AdminUserDraft(
          name: 'Budi',
          email: 'budi@example.com',
          password: '',
          role: 'ADMIN',
        ),
      );

      expect(result.user.role, 'ADMIN');
      expect(result.message, 'User berhasil diperbarui.');
    });

    test('deleteUser DELETE ke /api/admin/users/{id}', () async {
      final dio = _FakeDio(
        onDelete: (data) async {
          expect(data.path, '/api/admin/users/u1');
          return Response<dynamic>(
            requestOptions: RequestOptions(path: data.path),
            statusCode: 200,
            data: {'success': true, 'message': 'User berhasil dihapus.'},
          );
        },
      );

      final repo = AdminUsersRepository(dio: dio);
      final message = await repo.deleteUser('u1');

      expect(message, 'User berhasil dihapus.');
    });

    test('403 Forbidden diteruskan persis dari server', () async {
      final dio = _FakeDio(
        onGet: (_) async {
          throw DioException(
            requestOptions: RequestOptions(path: '/api/admin/users'),
            response: Response<dynamic>(
              requestOptions: RequestOptions(path: '/api/admin/users'),
              statusCode: 403,
              data: {'error': 'Forbidden'},
            ),
            type: DioExceptionType.badResponse,
          );
        },
      );

      final repo = AdminUsersRepository(dio: dio);

      expect(
        () => repo.fetchUsers(),
        throwsA(
          isA<AdminUserException>().having(
            (e) => e.message,
            'message',
            'Forbidden',
          ),
        ),
      );
    });

    test('400 Tidak bisa hapus akun sendiri diteruskan', () async {
      final dio = _FakeDio(
        onDelete: (data) async {
          throw DioException(
            requestOptions: RequestOptions(path: data.path),
            response: Response<dynamic>(
              requestOptions: RequestOptions(path: data.path),
              statusCode: 400,
              data: {'error': 'Tidak bisa hapus akun sendiri.'},
            ),
            type: DioExceptionType.badResponse,
          );
        },
      );

      final repo = AdminUsersRepository(dio: dio);

      expect(
        () => repo.deleteUser('me'),
        throwsA(
          isA<AdminUserException>().having(
            (e) => e.message,
            'message',
            'Tidak bisa hapus akun sendiri.',
          ),
        ),
      );
    });
  });
}

class _FakeDio extends Fake implements Dio {
  _FakeDio({
    this.onGet,
    this.onPost,
    this.onPatch,
    this.onDelete,
  });

  final Future<Response<dynamic>> Function(RequestOptions data)? onGet;
  final Future<Response<dynamic>> Function(RequestOptions data)? onPost;
  final Future<Response<dynamic>> Function(RequestOptions data)? onPatch;
  final Future<Response<dynamic>> Function(RequestOptions data)? onDelete;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    final res = await onGet?.call(RequestOptions(path: path, queryParameters: queryParameters));
    return res as Response<T>;
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final res = await onPost?.call(RequestOptions(path: path, data: data));
    return res as Response<T>;
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final res = await onPatch?.call(RequestOptions(path: path, data: data));
    return res as Response<T>;
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final res = await onDelete?.call(RequestOptions(path: path));
    return res as Response<T>;
  }
}
