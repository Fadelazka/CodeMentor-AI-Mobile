// Test model `ChatHistoryItem` + pengurai jawaban AI
// (`lib/features/history/domain/`).
//
// Yang dijaga:
//   - pembacaan JSON dari `GET /api/history` (termasuk kolom null/kosong),
//   - label & cuplikan untuk kartu daftar,
//   - pencarian lokal (hanya errorCode + sourceCode, sama seperti web),
//   - `parseAiResponse` memisahkan blok "Kode yang Sudah Dibenarkan",
//   - `isCodeCorrectResponse` mengenali jawaban "sudah benar".
import 'package:codementor_mobile/features/history/domain/ai_response_parser.dart';
import 'package:codementor_mobile/features/history/domain/chat_history_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatHistoryItem.fromJson', () {
    test('membaca seluruh kolom dari server', () {
      final item = ChatHistoryItem.fromJson(<String, dynamic>{
        'id': 'clx1',
        'language': 'javascript',
        'errorCode': 'TypeError',
        'errorMessage': 'x is not a function',
        'sourceCode': 'x()',
        'aiResponse': '## Penyebab',
        'confidence': 92,
        'createdAt': '2026-10-06T10:30:00.000Z',
      });

      expect(item.id, 'clx1');
      expect(item.language, 'javascript');
      expect(item.errorCode, 'TypeError');
      expect(item.errorMessage, 'x is not a function');
      expect(item.sourceCode, 'x()');
      expect(item.aiResponse, '## Penyebab');
      expect(item.confidence, 92);
      expect(item.createdAt, isNotNull);
    });

    test('kolom kosong/hilang menjadi null atau string kosong', () {
      final item = ChatHistoryItem.fromJson(<String, dynamic>{
        'id': 'clx2',
        'language': 'python',
        'errorCode': '   ',
        'errorMessage': null,
        'sourceCode': 'print(1)',
        'aiResponse': 'oke',
        'confidence': null,
        'createdAt': 'bukan-tanggal',
      });

      expect(item.errorCode, isNull, reason: 'spasi saja dianggap kosong');
      expect(item.errorMessage, isNull);
      expect(item.confidence, isNull);
      expect(item.createdAt, isNull);
    });

    test('confidence berbentuk double/teks tetap dibaca sebagai int', () {
      expect(
        ChatHistoryItem.fromJson(<String, dynamic>{'confidence': 88.6})
            .confidence,
        89,
      );
      expect(
        ChatHistoryItem.fromJson(<String, dynamic>{'confidence': '75'})
            .confidence,
        75,
      );
    });
  });

  group('label & cuplikan kartu', () {
    final item = ChatHistoryItem(
      id: 'h1',
      language: 'cpp',
      errorCode: null,
      sourceCode: 'int main() {}',
      aiResponse: 'Penjelasan singkat.',
      createdAt: DateTime(2026, 10, 6, 10, 30),
    );

    test('languageLabel memakai label resmi, fallback huruf besar', () {
      expect(item.languageLabel, 'C++');
      expect(
        ChatHistoryItem(id: 'x', language: 'ruby', sourceCode: '', aiResponse: '')
            .languageLabel,
        'RUBY',
      );
    });

    test('errorCodeLabel kosong ditampilkan sebagai N/A', () {
      expect(item.errorCodeLabel, 'N/A');
      expect(
        ChatHistoryItem(
          id: 'x',
          language: 'python',
          errorCode: 'NameError',
          sourceCode: '',
          aiResponse: '',
        ).errorCodeLabel,
        'NameError',
      );
    });

    test('formattedDate memakai format Indonesia', () {
      expect(item.formattedDate, '06 Okt 2026, 10.30');
      expect(
        ChatHistoryItem(id: 'x', language: 'python', sourceCode: '', aiResponse: '')
            .formattedDate,
        '-',
      );
    });

    test('responsePreview merapikan spasi & memotong 200 huruf', () {
      expect(
        ChatHistoryItem(
          id: 'x',
          language: 'python',
          sourceCode: '',
          aiResponse: '  Baris satu\n\n  baris   dua  ',
        ).responsePreview,
        'Baris satu baris dua',
      );

      final panjang = 'a' * 260;
      final preview = ChatHistoryItem(
        id: 'x',
        language: 'python',
        sourceCode: '',
        aiResponse: panjang,
      ).responsePreview;
      expect(preview.length, 203); // 200 huruf + '...'
      expect(preview.endsWith('...'), isTrue);
    });
  });

  group('matches (pencarian lokal)', () {
    final item = ChatHistoryItem(
      id: 'h1',
      language: 'python',
      errorCode: 'NameError',
      errorMessage: 'x belum dibuat',
      sourceCode: 'print(x)',
      aiResponse: 'Jawaban rahasia',
    );

    test('kata kunci kosong selalu cocok', () {
      expect(item.matches(''), isTrue);
      expect(item.matches('   '), isTrue);
    });

    test('mencocokkan errorCode & sourceCode tanpa peduli huruf besar/kecil', () {
      expect(item.matches('nameerror'), isTrue);
      expect(item.matches('PRINT'), isTrue);
    });

    test('TIDAK mencari di jawaban AI (sama seperti web)', () {
      expect(item.matches('rahasia'), isFalse);
      expect(item.matches('tidak ada'), isFalse);
    });
  });

  group('parseAiResponse', () {
    test('memisahkan blok "Kode yang Sudah Dibenarkan"', () {
      final parsed = parseAiResponse(
        '## Penyebab\n\nVariabel x kosong.\n\n'
        '## Kode yang Sudah Dibenarkan\n\n```python\nx = 1\nprint(x)\n```\n',
      );

      expect(parsed.fixedCode, 'x = 1\nprint(x)');
      expect(parsed.language, 'python');
      expect(parsed.explanation, contains('## Penyebab'));
      expect(parsed.explanation, contains('Variabel x kosong.'));
      expect(parsed.explanation, isNot(contains('Kode yang Sudah Dibenarkan')));
    });

    test('mengenali judul tanpa bahasa pada info-string', () {
      final parsed = parseAiResponse(
        '## Kode yang Sudah Dibenarkan\n\n```\nprint(1)\n```\n',
      );

      expect(parsed.fixedCode, 'print(1)');
      expect(parsed.language, isNull);
    });

    test('"Kode yang Bermasalah" hanya diambil kodenya', () {
      final parsed = parseAiResponse(
        '## Kode yang Bermasalah\n\n```python\nprint(x)\n```\n\n'
        'Penjelasan setelahnya.\n',
      );

      expect(parsed.brokenCode, 'print(x)');
      expect(parsed.fixedCode, isNull);
      expect(parsed.explanation, contains('Kode yang Bermasalah'));
    });

    test('judul huruf kecil tetap dikenali (case-insensitive)', () {
      final parsed = parseAiResponse(
        '## kode yang sudah dibenarkan\n\n```js\nlet a = 1;\n```\n',
      );

      expect(parsed.fixedCode, 'let a = 1;');
      expect(parsed.language, 'js');
    });
  });

  group('isCodeCorrectResponse', () {
    test('mengenali frasa "sudah benar"/"100%"/"kode benar"/"tidak ada error"', () {
      expect(isCodeCorrectResponse('Kode kamu sudah benar.'), isTrue);
      expect(isCodeCorrectResponse('Akurasi 100% untuk kode ini.'), isTrue);
      expect(isCodeCorrectResponse('KODE BENAR'), isTrue);
      expect(isCodeCorrectResponse('Tidak ada error di sini.'), isTrue);
    });

    test('jawaban biasa dianggap belum benar', () {
      expect(
        isCodeCorrectResponse('Ada kesalahan pada baris 3, perbaiki dulu.'),
        isFalse,
      );
    });

    test('memindai seluruh teks (bukan hanya 200 huruf pertama)', () {
      final panjang = '${'x' * 400} sudah benar';
      expect(isCodeCorrectResponse(panjang), isTrue);
    });
  });
}
