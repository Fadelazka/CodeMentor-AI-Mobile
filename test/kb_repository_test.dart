// Test `KnowledgeBaseRepository` dengan adapter Dio palsu (tanpa jaringan).
//
// Yang dijaga: bentuk pemanggilan endpoint (method + query parameter + body)
// dan pembacaan respons persis seperti
// `src/app/api/admin/knowledge-base/route.ts`:
//   - GET    /api/admin/knowledge-base          -> { data, count }
//   - POST   /api/admin/knowledge-base          -> 201 { data, message }
//   - PUT    /api/admin/knowledge-base?id=<id>  -> { data, message }
//          (body draft penuh, atau hanya { isActive } untuk toggle)
//   - DELETE /api/admin/knowledge-base?id=<id>  -> { success, message }
//
// Guard role ADMIN di server menjawab 403 "Forbidden: admin only" — pesan itu
// harus diteruskan apa adanya ke UI (lihat test 403 di bagian bawah).
import 'dart:convert';
import 'dart:typed_data';

import 'package:codementor_mobile/core/constants/api_constants.dart';
import 'package:codementor_mobile/features/admin/data/kb_entry.dart';
import 'package:codementor_mobile/features/admin/data/kb_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter Dio palsu: setiap permintaan dicatat lalu dijawab [handler].
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  /// Semua permintaan yang masuk (untuk diperiksa).
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Jawaban JSON biasa.
ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

/// Satu rekaman pada respons server.
Map<String, dynamic> _serverEntry({String id = 'kb1'}) => {
  'id': id,
  'language': 'python',
  'errorCode': 'ZeroDivisionError',
  'title': 'Pembagian dengan Nol',
  'description': 'Terjadi saat membagi dengan 0.',
  'solution': 'Cek pembilang sebelum dibagi.',
  'examples': null,
  'tags': ['Math'],
  'isActive': true,
  'updatedAt': '2026-10-06T08:30:00.000Z',
};

const KbEntryDraft _draft = KbEntryDraft(
  language: 'python',
  errorCode: 'ZeroDivisionError',
  title: 'Pembagian dengan Nol',
  description: 'Terjadi saat membagi dengan 0.',
  solution: 'Cek pembilang sebelum dibagi.',
  tags: ['Math'],
);

void main() {
  late _FakeAdapter adapter;
  late KnowledgeBaseRepository repository;

  void useHandler(ResponseBody Function(RequestOptions options) handler) {
    adapter = _FakeAdapter((options) async => handler(options));
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    repository = KnowledgeBaseRepository(dio: dio);
  }

  void useJson(Object body, {int status = 200}) =>
      useHandler((_) => _json(body, status: status));

  test('fetchEntries: GET tanpa query, respons { data, count } diparse', () async {
    useJson({
      'data': [_serverEntry()],
      'count': 1,
    });

    final entries = await repository.fetchEntries();

    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, ApiConstants.adminKbEndpoint);
    expect(adapter.requests.single.queryParameters, isEmpty);

    expect(entries, hasLength(1));
    expect(entries.single.id, 'kb1');
    expect(entries.single.errorCode, 'ZeroDivisionError');
    expect(entries.single.tags, <String>['Math']);
    expect(entries.single.updatedAt, DateTime.utc(2026, 10, 6, 8, 30));
  });

  test('fetchEntries: respons tanpa field data -> KbException', () async {
    useJson(<String, Object>{});

    expect(
      repository.fetchEntries,
      throwsA(isA<KbException>()),
    );
  });

  test('createEntry: POST dengan body draft penuh + pesan server', () async {
    useJson(
      {'data': _serverEntry(id: 'kb-baru'), 'message': 'Rekaman knowledge base ditambahkan.'},
      status: 201,
    );

    final result = await repository.createEntry(_draft);

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, ApiConstants.adminKbEndpoint);
    expect(request.queryParameters, isEmpty);
    expect(request.data, <String, dynamic>{
      'language': 'python',
      'errorCode': 'ZeroDivisionError',
      'title': 'Pembagian dengan Nol',
      'description': 'Terjadi saat membagi dengan 0.',
      'solution': 'Cek pembilang sebelum dibagi.',
      'examples': null,
      'tags': <String>['Math'],
      'isActive': true,
    });

    expect(result.entry.id, 'kb-baru');
    expect(result.message, 'Rekaman knowledge base ditambahkan.');
  });

  test('createEntry: pesan server kosong -> pesan bawaan dipakai', () async {
    useJson(
      {'data': _serverEntry(), 'message': ''},
      status: 201,
    );

    final result = await repository.createEntry(_draft);

    expect(result.message, 'Rekaman knowledge base ditambahkan.');
  });

  test('updateEntry: PUT ?id= dengan body draft penuh', () async {
    useJson({
      'data': _serverEntry(),
      'message': 'Rekaman diperbarui.',
    });

    final result = await repository.updateEntry('kb1', _draft);

    final request = adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.queryParameters, <String, dynamic>{'id': 'kb1'});
    expect((request.data as Map)['errorCode'], 'ZeroDivisionError');
    expect(result.entry.id, 'kb1');
    expect(result.message, 'Rekaman diperbarui.');
  });

  test('toggleActive: PUT ?id= dengan HANYA { isActive }', () async {
    useJson({
      'data': {..._serverEntry(), 'isActive': false},
      'message': 'Status rekaman diperbarui.',
    });

    final result = await repository.toggleActive(id: 'kb1', isActive: false);

    final request = adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.queryParameters, <String, dynamic>{'id': 'kb1'});
    expect(request.data, <String, dynamic>{'isActive': false});
    expect(result.entry.isActive, isFalse);
    expect(result.message, 'Status rekaman diperbarui.');
  });

  test('deleteEntry: DELETE ?id= dan pesan server dikembalikan', () async {
    useJson({'success': true, 'message': 'Rekaman dihapus.'});

    final message = await repository.deleteEntry('kb1');

    final request = adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.queryParameters, <String, dynamic>{'id': 'kb1'});
    expect(message, 'Rekaman dihapus.');
  });

  test('deleteEntry: respons tanpa pesan -> pesan bawaan dipakai', () async {
    useJson({'success': true});

    expect(await repository.deleteEntry('kb1'), 'Rekaman dihapus.');
  });

  test('403 guard admin: pesan error server diteruskan apa adanya', () async {
    useJson({'error': 'Forbidden: admin only'}, status: 403);

    expect(
      repository.fetchEntries,
      throwsA(
        isA<KbException>().having(
          (e) => e.message,
          'message',
          'Forbidden: admin only',
        ),
      ),
    );
  });

  test('403 tanpa pesan: diarahkan ke pesan "masuk ulang"', () async {
    useJson(<String, Object>{}, status: 403);

    expect(
      () => repository.deleteEntry('kb1'),
      throwsA(
        isA<KbException>().having(
          (e) => e.message,
          'message',
          'Sesi kamu tidak lagi valid. Silakan masuk ulang.',
        ),
      ),
    );
  });

  test('server tidak terjangkau -> pesan koneksi', () async {
    useHandler(
      (_) => throw DioException(
        requestOptions: RequestOptions(path: ApiConstants.adminKbEndpoint),
        type: DioExceptionType.connectionError,
      ),
    );

    expect(
      repository.fetchEntries,
      throwsA(
        isA<KbException>().having(
          (e) => e.message,
          'message',
          'Tidak dapat terhubung ke server. Periksa koneksi internetmu.',
        ),
      ),
    );
  });
}
