// Test model chat: pembacaan respons `POST /api/chat` dan salinan `ChatExchange`.
import 'package:codementor_mobile/features/chat/domain/chat_answer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatAnswer.fromJson', () {
    test('membaca respons lengkap dari server', () {
      final answer = ChatAnswer.fromJson({
        'explanation': 'Variabel x belum didefinisikan.',
        'confidence': 88,
        'mock': false,
        'ragMatches': 2,
        'responseTimeMs': 1200,
        'detectedErrorCode': 'NameError',
        'chatHistoryId': 'clx123',
      });

      expect(answer.explanation, 'Variabel x belum didefinisikan.');
      expect(answer.confidence, 88);
      expect(answer.mock, isFalse);
      expect(answer.ragMatches, 2);
      expect(answer.responseTimeMs, 1200);
      expect(answer.detectedErrorCode, 'NameError');
      expect(answer.chatHistoryId, 'clx123');
      expect(answer.isSaved, isTrue);
    });

    test('toleran terhadap nilai number/string dan field kosong', () {
      final answer = ChatAnswer.fromJson({
        'explanation': '  ',
        'confidence': 88.6,
        'ragMatches': '3',
        'detectedErrorCode': '',
        'chatHistoryId': null,
      });

      expect(answer.confidence, 89);
      expect(answer.ragMatches, 3);
      expect(answer.detectedErrorCode, isNull);
      expect(answer.chatHistoryId, isNull);
      expect(answer.isSaved, isFalse);
      expect(answer.mock, isFalse);
      expect(answer.responseTimeMs, isNull);
    });
  });

  group('ChatExchange', () {
    const exchange = ChatExchange(
      id: 'x1',
      sourceCode: 'print(x)',
      language: 'python',
      errorMessage: 'NameError',
    );

    test('awalnya menunggu jawaban', () {
      expect(exchange.isPending, isTrue);
      expect(exchange.hasFailed, isFalse);
    });

    test('copyWith mengisi jawaban dan membersihkan error', () {
      const answer = ChatAnswer(explanation: 'ok', chatHistoryId: 'h1');
      final gagal = exchange.copyWith(error: 'Server mati.');
      expect(gagal.hasFailed, isTrue);
      expect(gagal.isPending, isFalse);

      final selesai = gagal.copyWith(answer: answer, clearError: true);
      expect(selesai.hasFailed, isFalse);
      expect(selesai.answer, same(answer));
      expect(selesai.feedback, isNull);

      final dinilai = selesai.copyWith(feedback: ChatFeedback.notHelpful);
      expect(dinilai.feedback, ChatFeedback.notHelpful);
      // Data asli tidak berubah (immutable).
      expect(selesai.feedback, isNull);
    });

    test('nama nilai feedback sesuai kontrak server', () {
      expect(ChatFeedback.helpful.wireName, 'helpful');
      expect(ChatFeedback.notHelpful.wireName, 'not_helpful');
    });
  });
}
