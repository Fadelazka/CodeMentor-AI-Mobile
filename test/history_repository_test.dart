// Test `HistoryRepository` dengan adapter Dio palsu (tanpa jaringan).
//
// Yang dijaga: bentuk pemanggilan endpoint (method + query parameter) dan
// pembacaan respons persis seperti `src/app/api/history/route.ts`:
//   - GET    /api/history?limit=50           (filter bahasa opsional)
//   - GET    /api/history?id=<id>            -> 404 = tidak ditemukan
//   - DELETE /api/history?id=<id>            (satu)
//   - DELETE /api/history?all=1              (semua)
//   - GET    /api/history/export?format=...  -> nama berkas dari header
import 'dart:convert';
import 'dart:typed_data';

import 'package:codementor_mobile/core/constants/api_constants.dart';
import 'package:codementor_mobile/features/history/data/history_repository.dart';
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

void main() {
  late _FakeAdapter adapter;
  late HistoryRepository repository;

  void useHandler(ResponseBody Function(RequestOptions options) handler) {
    adapter = _FakeAdapter((options) async => handler(options));
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    repository = HistoryRepository(dio: dio);
  }

  void useJson(Object body, {int status = 200}) =>
      useHandler((_) => _json(body, status: status));

  test('fetchList: GET /api/history dengan limit 50 tanpa filter bahasa', () async {
    useJson({
      'data': [
        {
          'id': 'h1',
          'language': 'python',
          'errorCode': 'NameError',
          'sourceCode': 'print(x)',
          'aiResponse': '## Penyebab',
          'confidence': 80,
          'createdAt': '2026-10-06T03:30:00.000Z',
        },
      ],
      'count': 1,
    });

    final items = await repository.fetchList();

    expect(items, hasLength(1));
    expect(items.single.id, 'h1');
    expect(items.single.languageLabel, 'Python');

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, ApiConstants.historyEndpoint);
    expect(request.queryParameters, <String, dynamic>{'limit': 50});
  });

  test('fetchList: bahasa dikirim sebagai query parameter', () async {
    useJson({'data': <dynamic>[]});

    await repository.fetchList(language: 'java');

    expect(adapter.requests.single.queryParameters, <String, dynamic>{
      'language': 'java',
      'limit': 50,
    });
  });

  test('fetchList: format tak dikenal jadi HistoryException', () async {
    useJson('bukan-map');

    expect(
      () => repository.fetchList(),
      throwsA(isA<HistoryException>()),
    );
  });

  test('fetchDetail: memakai id & membaca pembungkus { data }', () async {
    useJson({
      'data': {
        'id': 'abc123',
        'language': 'javascript',
        'sourceCode': 'x()',
        'aiResponse': 'oke',
      },
    });

    final item = await repository.fetchDetail('abc123');

    expect(item.id, 'abc123');
    expect(item.language, 'javascript');
    expect(adapter.requests.single.queryParameters, <String, dynamic>{
      'id': 'abc123',
    });
  });

  test('fetchDetail: 404 -> HistoryException(notFound: true)', () async {
    useJson({'error': 'Riwayat tidak ditemukan'}, status: 404);

    await expectLater(
      repository.fetchDetail('hilang'),
      throwsA(
        isA<HistoryException>()
            .having((error) => error.notFound, 'notFound', isTrue)
            .having((error) => error.message, 'message', 'Riwayat tidak ditemukan.'),
      ),
    );
  });

  test('fetchDetail: 401 -> pesan sesi tidak valid', () async {
    useJson({'error': 'Tidak terautentikasi'}, status: 401);

    await expectLater(
      repository.fetchDetail('h1'),
      throwsA(
        isA<HistoryException>().having(
          (error) => error.notFound,
          'notFound',
          isFalse,
        ),
      ),
    );
  });

  test('deleteOne: DELETE dengan query id', () async {
    useJson({'success': true});

    await repository.deleteOne('h7');

    final request = adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, ApiConstants.historyEndpoint);
    expect(request.queryParameters, <String, dynamic>{'id': 'h7'});
  });

  test('deleteAll: DELETE dengan all=1', () async {
    useJson({'success': true});

    await repository.deleteAll();

    final request = adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.queryParameters, <String, dynamic>{'all': 1});
  });

  test('exportHistory: format, filter, dan nama berkas dari server', () async {
    useHandler(
      (_) => ResponseBody.fromString(
        'ID,Tanggal\n1,"06 Okt 2026"\n',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/csv'],
          'content-disposition': [
            'attachment; filename="codementor-riwayat-2026-10-06-10-30-00.csv"',
          ],
        },
      ),
    );

    final file = await repository.exportHistory(
      format: 'csv',
      language: 'python',
      query: 'NameError',
    );

    expect(
      file.fileName,
      'codementor-riwayat-2026-10-06-10-30-00.csv',
    );
    expect(file.content, 'ID,Tanggal\n1,"06 Okt 2026"\n');
    expect(file.mimeType, 'text/csv');
    expect(adapter.requests.single.queryParameters, <String, dynamic>{
      'format': 'csv',
      'language': 'python',
      'q': 'NameError',
    });
  });

  test('exportHistory: JSON memakai MIME application/json', () async {
    useHandler(
      (_) => ResponseBody.fromString(
        '{"history":[]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      ),
    );

    final file = await repository.exportHistory(format: 'json');

    expect(file.mimeType, 'application/json');
    expect(file.fileName, endsWith('.json'));
    expect(file.content, '{"history":[]}');
  });
}
