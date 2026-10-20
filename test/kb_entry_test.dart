// Test model Knowledge Base (`lib/features/admin/data/kb_entry.dart`).
//
// Fokus: parsing respons server, filter pencarian lokal, dan draft form
// (validasi + body JSON yang dikirim ke `/api/admin/knowledge-base`).
import 'package:codementor_mobile/features/admin/data/kb_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_kb_repository.dart';

void main() {
  group('KbEntry.fromJson', () {
    test('memparse seluruh field dari respons server', () {
      final entry = KbEntry.fromJson(const {
        'id': 'kb1',
        'language': 'python',
        'errorCode': 'ZeroDivisionError',
        'title': 'Pembagian dengan Nol',
        'description': 'Terjadi saat membagi dengan 0.',
        'solution': 'Cek pembilang sebelum dibagi.',
        'examples': 'print(1/0)',
        'tags': ['Math', 'Division'],
        'isActive': false,
        'createdAt': '2026-09-01T10:00:00.000Z',
        'updatedAt': '2026-10-06T08:30:00.000Z',
      });

      expect(entry.id, 'kb1');
      expect(entry.language, 'python');
      expect(entry.errorCode, 'ZeroDivisionError');
      expect(entry.title, 'Pembagian dengan Nol');
      expect(entry.examples, 'print(1/0)');
      expect(entry.tags, <String>['Math', 'Division']);
      expect(entry.isActive, isFalse);
      expect(entry.createdAt, DateTime.utc(2026, 9, 1, 10));
      expect(entry.updatedAt, DateTime.utc(2026, 10, 6, 8, 30));
    });

    test('default aman untuk field yang hilang atau null', () {
      final entry = KbEntry.fromJson(const {'id': 'kb2', 'language': 'java'});

      expect(entry.errorCode, '');
      expect(entry.title, '');
      expect(entry.description, '');
      expect(entry.solution, '');
      expect(entry.examples, isNull);
      expect(entry.tags, isEmpty);
      // isActive default true (sama seperti skema DB).
      expect(entry.isActive, isTrue);
      expect(entry.updatedAt, isNull);
      expect(entry.formattedUpdatedAt, '-');
    });

    test('languageLabel & formattedTanggal mengikuti gaya web', () {
      expect(fakeKbEntry(language: 'cpp').languageLabel, 'C++');
      expect(fakeKbEntry(language: 'unknown').languageLabel, 'UNKNOWN');
      expect(
        fakeKbEntry(updatedAt: DateTime(2026, 10, 6)).formattedUpdatedAt,
        '06 Okt 2026',
      );
    });
  });

  group('matches (filter pencarian lokal)', () {
    final entry = fakeKbEntry(
      id: 'kb-1',
      language: 'python',
      errorCode: 'ZeroDivisionError',
      title: 'Pembagian dengan Nol',
    );

    test('mencocokkan kode error, judul, bahasa, dan id', () {
      expect(entry.matches('zero'), isTrue);
      expect(entry.matches('PEMBAGIAN'), isTrue);
      expect(entry.matches('python'), isTrue);
      expect(entry.matches('kb-1'), isTrue);
    });

    test('kueri kosong cocok dengan semua; yang lain tidak cocok', () {
      expect(entry.matches(''), isTrue);
      expect(entry.matches('   '), isTrue);
      expect(entry.matches('java'), isFalse);
      expect(entry.matches('kb-9'), isFalse);
    });
  });

  group('KbEntryDraft', () {
    test('validate mengembalikan pesan pertama yang gagal (urut sama web)', () {
      expect(const KbEntryDraft(
        language: '',
        errorCode: 'E',
        title: 'T',
        description: 'D',
        solution: 'S',
      ).validate(), KbEntryDraft.errLanguage);

      expect(const KbEntryDraft(
        language: 'python',
        errorCode: '',
        title: 'T',
        description: 'D',
        solution: 'S',
      ).validate(), KbEntryDraft.errErrorCode);

      expect(const KbEntryDraft(
        language: 'python',
        errorCode: 'E',
        title: '',
        description: 'D',
        solution: 'S',
      ).validate(), KbEntryDraft.errTitle);

      expect(const KbEntryDraft(
        language: 'python',
        errorCode: 'E',
        title: 'T',
        description: '  ',
        solution: 'S',
      ).validate(), KbEntryDraft.errDescription);

      expect(const KbEntryDraft(
        language: 'python',
        errorCode: 'E',
        title: 'T',
        description: 'D',
        solution: '',
      ).validate(), KbEntryDraft.errSolution);
    });

    test('validate lolos bila semua field wajib terisi', () {
      expect(const KbEntryDraft(
        language: 'python',
        errorCode: ' ZeroDivisionError ',
        title: ' Pembagian dengan Nol ',
        description: 'Deskripsi',
        solution: 'Solusi',
      ).validate(), isNull);
    });

    test('toJson: trim field & contoh kosong dikirim null', () {
      const draft = KbEntryDraft(
        language: 'python',
        errorCode: ' ZeroDivisionError ',
        title: 'Pembagian dengan Nol',
        description: 'Deskripsi',
        solution: 'Solusi',
        examples: '   ',
        tags: ['Math'],
        isActive: false,
      );

      expect(draft.toJson(), <String, dynamic>{
        'language': 'python',
        'errorCode': 'ZeroDivisionError',
        'title': 'Pembagian dengan Nol',
        'description': 'Deskripsi',
        'solution': 'Solusi',
        'examples': null,
        'tags': <String>['Math'],
        'isActive': false,
      });
    });

    test('toJson: contoh kode terisi ikut dikirim', () {
      const draft = KbEntryDraft(
        language: 'python',
        errorCode: 'E',
        title: 'T',
        description: 'D',
        solution: 'S',
        examples: 'print(1/0)',
      );

      expect(draft.toJson()['examples'], 'print(1/0)');
    });

    test('tagsFromText/tagsToText bolak-balik termasuk spasi berlebih', () {
      expect(KbEntryDraft.tagsFromText('Math, Division'), <String>[
        'Math',
        'Division',
      ]);
      expect(KbEntryDraft.tagsFromText(' Math , , Division '), <String>[
        'Math',
        'Division',
      ]);
      expect(KbEntryDraft.tagsFromText(''), isEmpty);
      expect(KbEntryDraft.tagsToText(const ['Math', 'Division']),
          'Math, Division');
    });

    test('toDraft membawa seluruh field entri lama', () {
      final entry = fakeKbEntry(
        language: 'java',
        errorCode: 'NullPointerException',
        title: 'Menunjuk Ke Null',
        description: 'Deskripsi',
        solution: 'Solusi',
        examples: 'int a = null;',
        tags: const ['OOP'],
        isActive: false,
      );

      final draft = entry.toDraft();

      expect(draft.language, 'java');
      expect(draft.errorCode, 'NullPointerException');
      expect(draft.title, 'Menunjuk Ke Null');
      expect(draft.description, 'Deskripsi');
      expect(draft.solution, 'Solusi');
      expect(draft.examples, 'int a = null;');
      expect(draft.tags, <String>['OOP']);
      expect(draft.isActive, isFalse);
    });
  });
}
