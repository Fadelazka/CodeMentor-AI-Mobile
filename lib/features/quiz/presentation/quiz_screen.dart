import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/code_meteors_background.dart';
import '../../auth/data/auth_repository.dart';
import '../data/quiz_repository.dart';
import 'quiz_result_screen.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _currentQuestion = 0;
  List<int?> _answers = List.filled(7, null);
  bool _isFinished = false;
  bool _isSubmitting = false;
  int _score = 0;

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Apa output dari `print(type([]))` di Python?',
      'options': ['<class \'list\'>', '<class \'tuple\'>', '<class \'dict\'>', '<class \'set\'>'],
      'answer': 0,
    },
    {
      'question': 'Mana yang merupakan cara mendeklarasikan variabel di JavaScript (ES6)?',
      'options': ['var x = 1', 'let x = 1', 'const x = 1', 'Semua benar'],
      'answer': 3,
    },
    {
      'question': 'Apa fungsi dari `public static void main(String[] args)` di Java?',
      'options': ['Method konstruktor', 'Titik masuk program', 'Method getter', 'Method setter'],
      'answer': 1,
    },
    {
      'question': 'Manakah yang merupakan pointer di C++?',
      'options': ['int x', 'int &x', 'int *x', 'int x()'],
      'answer': 2,
    },
    {
      'question': 'Fungsi `echo` di PHP digunakan untuk?',
      'options': ['Membaca file', 'Menampilkan output', 'Koneksi database', 'Menghapus variabel'],
      'answer': 1,
    },
    {
      'question': 'Apa perbedaan `==` dan `===` di JavaScript?',
      'options': ['Tidak ada perbedaan', '`===` membandingkan tipe dan nilai', '`==` lebih strict', 'Hanya beda penulisan'],
      'answer': 1,
    },
    {
      'question': 'Bagaimana cara membuat list kosong di Python?',
      'options': ['{}', '[]', '()', 'set()'],
      'answer': 1,
    },
  ];

  void _selectAnswer(int index) {
    setState(() {
      _answers[_currentQuestion] = index;
    });
  }

  void _nextQuestion() {
    if (_answers[_currentQuestion] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih jawaban terlebih dahulu')),
      );
      return;
    }

    if (_currentQuestion < _questions.length - 1) {
      setState(() {
        _currentQuestion++;
      });
    } else {
      _finishQuiz();
    }
  }

  void _previousQuestion() {
    if (_currentQuestion > 0) {
      setState(() {
        _currentQuestion--;
      });
    }
  }

  Future<void> _finishQuiz() async {
    int correct = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_answers[i] == _questions[i]['answer']) {
        correct++;
      }
    }
    _score = ((correct / _questions.length) * 100).round();

    String preference = 'medium';
    if (_score >= 80) preference = 'detailed';
    else if (_score < 50) preference = 'brief';

    setState(() => _isSubmitting = true);

    try {
      await ref.read(quizRepositoryProvider).submitQuiz(
            score: _score,
            preference: preference,
          );
      final authRepo = ref.read(authRepositoryProvider);
      try {
        await authRepo.client.updateSession({});
      } catch (e) {
        print('[QUIZ_SCREEN] updateSession error: $e');
      }
      await authRepo.fetchSession();
      await authRepo.client.refetchSession();
      if (!mounted) return;
      print('[QUIZ_SCREEN] quizCompletedAt: ${ref.read(authSnapshotProvider).session?.user.quizCompletedAt}');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(score: _score, preference: preference),
        ),
      );
      return;
    } catch (e) {
      print('[QUIZ_SCREEN] Submit error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan hasil kuis. Silakan coba lagi.')),
      );
      setState(() {
        _isSubmitting = false;
      });
      return;
    }
  }

  String _getPreferenceLabel(String pref) {
    switch (pref) {
      case 'brief':
        return 'Singkat';
      case 'detailed':
        return 'Lengkap';
      default:
        return 'Sedang';
    }
  }

  String _getPreferenceDesc(String pref) {
    switch (pref) {
      case 'brief':
        return 'AI akan menjawab ringkas dan langsung ke inti solusi';
      case 'detailed':
        return 'AI akan menjelaskan lebih mendalam dengan contoh dan konsep terkait';
      default:
        return 'AI akan memberi penjelasan seimbang sesuai kebutuhan';
    }
  }

  void _goToHome() {
    final snapshot = ref.read(authSnapshotProvider);
    final isAdmin = snapshot.session?.user.isAdmin == true;
    context.go(isAdmin ? AppRoutes.dashboard : AppRoutes.chat);
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) {
      int correct = (_score / 100 * 7).round();
      String preference = 'medium';
      if (_score >= 80) preference = 'detailed';
      else if (_score < 50) preference = 'brief';

      return Scaffold(
        body: CodeMeteorsBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppLogo(),
                        const SizedBox(height: 24),
                        Icon(Icons.emoji_events, size: 64, color: Colors.amber.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Kuis Selesai!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Skor Kamu',
                          style: TextStyle(color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$_score',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$correct dari 7 jawaban benar',
                          style: TextStyle(color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Preferensi AI: ${_getPreferenceLabel(preference)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.foreground,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getPreferenceDesc(preference),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.mutedForeground),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          style: AppTheme.paperButtonStyle,
                          onPressed: _goToHome,
                          child: const Text('Mulai Belajar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final question = _questions[_currentQuestion];

    return Scaffold(
      body: CodeMeteorsBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _currentQuestion > 0 ? _previousQuestion() : Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Spacer(),
                    const AppLogo(),
                    const Spacer(),
                    Text(
                      '${_currentQuestion + 1}/7',
                      style: TextStyle(color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LinearProgressIndicator(
                  value: (_currentQuestion + 1) / 7,
                  backgroundColor: AppColors.muted,
                  color: AppColors.accent,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        question['question'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...List.generate(4, (index) {
                        final isSelected = _answers[_currentQuestion] == index;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _selectAnswer(index),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : AppColors.card,
                                border: Border.all(
                                  color: isSelected ? AppColors.accent : AppColors.border,
                                ),
                                borderRadius: BorderRadius.circular(AppTheme.radius),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? AppColors.accent : AppColors.mutedForeground,
                                      ),
                                      color: isSelected ? AppColors.accent : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      question['options'][index],
                                      style: TextStyle(color: AppColors.foreground),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_currentQuestion > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousQuestion,
                          child: const Text('Kembali'),
                        ),
                      ),
                    if (_currentQuestion > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: AppTheme.paperButtonStyle,
                        onPressed: _isSubmitting ? null : _nextQuestion,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                              )
                            : Text(_currentQuestion == 6 ? 'Selesai' : 'Lanjut'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
