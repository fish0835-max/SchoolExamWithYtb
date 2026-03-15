import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/question.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/question_service.dart';
import '../../../core/services/settings_service.dart';

enum OverlayPhase { loading, question, correct, wrong, done }

/// Full-screen quiz overlay that cannot be dismissed without answering correctly
class QuizOverlay extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const QuizOverlay({super.key, required this.onComplete});

  @override
  ConsumerState<QuizOverlay> createState() => _QuizOverlayState();
}

class _QuizOverlayState extends ConsumerState<QuizOverlay> {
  OverlayPhase _phase = OverlayPhase.loading;
  Question? _currentQuestion;
  int _correctCount = 0;
  int _questionsToUnlock = AppConfig.defaultQuestionsToUnlock;
  int _timeLimitSeconds = AppConfig.defaultQuestionTimeLimitSeconds;
  int _remainingSeconds = AppConfig.defaultQuestionTimeLimitSeconds;
  Timer? _questionTimer;
  String? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndQuestion();
  }

  Future<void> _loadSettingsAndQuestion() async {
    final settings =
        await ref.read(settingsServiceProvider).getSettings();
    setState(() {
      _questionsToUnlock = settings.questionsToUnlock;
      _timeLimitSeconds = settings.questionTimeLimitSeconds;
      _remainingSeconds = settings.questionTimeLimitSeconds;
    });
    await _fetchQuestion();
  }

  Future<void> _fetchQuestion() async {
    setState(() => _phase = OverlayPhase.loading);
    final service = ref.read(questionServiceProvider);
    final question = await service.getNextQuestion('math');

    if (question != null) {
      setState(() {
        _currentQuestion = question;
        _phase = OverlayPhase.question;
        _selectedAnswer = null;
        _remainingSeconds = _timeLimitSeconds;
      });
      _startQuestionTimer();
    } else {
      // No questions available — fallback demo question
      setState(() {
        _currentQuestion = const Question(
          id: 'demo_1',
          grade: 2,
          subject: 'math',
          semester: 1,
          unitOrder: 1,
          unit: '加法',
          questionText: '15 + 27 = ?',
          options: ['40', '41', '42', '43'],
          correctAnswer: '42',
          questionType: QuestionType.multipleChoice,
          difficulty: 1,
        );
        _phase = OverlayPhase.question;
        _selectedAnswer = null;
        _remainingSeconds = _timeLimitSeconds;
      });
      _startQuestionTimer();
    }
  }

  void _startQuestionTimer() {
    if (_timeLimitSeconds == 0) return; // 0 = unlimited
    _questionTimer?.cancel();
    _questionTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _onTimeUp();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _onTimeUp() {
    _questionTimer?.cancel();
    setState(() => _phase = OverlayPhase.wrong);
    Future.delayed(const Duration(seconds: 2), _fetchQuestion);
  }

  void _onAnswerSelected(String answer) {
    if (_phase != OverlayPhase.question) return;
    _questionTimer?.cancel();

    final isCorrect =
        _currentQuestion?.checkAnswer(answer) ?? false;

    setState(() {
      _selectedAnswer = answer;
      _phase = isCorrect ? OverlayPhase.correct : OverlayPhase.wrong;
    });

    if (isCorrect) {
      _correctCount++;
      if (_correctCount >= _questionsToUnlock) {
        Future.delayed(const Duration(seconds: 2), () {
          setState(() => _phase = OverlayPhase.done);
          Future.delayed(const Duration(seconds: 1), widget.onComplete);
        });
      } else {
        // Need more correct answers
        Future.delayed(
            const Duration(seconds: 2), _fetchQuestion);
      }
    } else {
      Future.delayed(const Duration(seconds: 2), _fetchQuestion);
    }
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.95),
      child: SafeArea(
        child: _buildPhaseContent(),
      ),
    );
  }

  Widget _buildPhaseContent() {
    return switch (_phase) {
      OverlayPhase.loading => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF4CAF50)),
              SizedBox(height: 16),
              Text(
                '準備題目中...',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      OverlayPhase.question => _buildQuestionView(),
      OverlayPhase.correct => _buildResultView(true),
      OverlayPhase.wrong => _buildResultView(false),
      OverlayPhase.done => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎉', style: TextStyle(fontSize: 72)),
              SizedBox(height: 16),
              Text(
                '太棒了！繼續看影片吧！',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
    };
  }

  Widget _buildQuestionView() {
    final question = _currentQuestion!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '答對 $_correctCount/$_questionsToUnlock 才能繼續',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (_timeLimitSeconds > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _remainingSeconds <= 10
                        ? Colors.red
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$_remainingSeconds 秒',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Time progress bar
          if (_timeLimitSeconds > 0)
            LinearProgressIndicator(
              value: _remainingSeconds / _timeLimitSeconds,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(
                _remainingSeconds <= 10 ? Colors.red : const Color(0xFF4CAF50),
              ),
              minHeight: 4,
            ),

          const SizedBox(height: 32),

          // Subject badge
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_subjectName(question.subject)} · ${question.unit ?? ''}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Question text
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              question.questionText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 24),

          // Answer options
          if (question.questionType == QuestionType.multipleChoice &&
              question.options != null)
            ...question.options!.asMap().entries.map((entry) {
              final idx = entry.key;
              final option = entry.value;
              final label = ['A', 'B', 'C', 'D'][idx];
              return _AnswerButton(
                label: label,
                text: option,
                selected: _selectedAnswer == option,
                onTap: () => _onAnswerSelected(option),
              );
            }),

          if (question.questionType == QuestionType.fillBlank)
            _FillBlankInput(
              onSubmit: _onAnswerSelected,
            ),
        ],
      ),
    );
  }

  Widget _buildResultView(bool isCorrect) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isCorrect ? '✅' : '❌',
            style: const TextStyle(fontSize: 80),
          ),
          const SizedBox(height: 16),
          Text(
            isCorrect ? '答對了！真棒！🎉' : '答錯了，再試一次！',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!isCorrect && _currentQuestion != null) ...[
            const SizedBox(height: 16),
            Text(
              '正確答案：${_currentQuestion!.correctAnswer}',
              style: const TextStyle(
                color: Color(0xFF81C784),
                fontSize: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _subjectName(String subject) => switch (subject) {
        'math' => '數學',
        'chinese' => '國文',
        _ => subject,
      };
}

class _AnswerButton extends StatelessWidget {
  final String label;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _AnswerButton({
    required this.label,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF4CAF50)
                : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? const Color(0xFF4CAF50) : Colors.white24,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? Colors.white24 : Colors.white12,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white,
                    fontSize: 18,
                    fontWeight: selected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FillBlankInput extends StatefulWidget {
  final void Function(String) onSubmit;

  const _FillBlankInput({required this.onSubmit});

  @override
  State<_FillBlankInput> createState() => _FillBlankInputState();
}

class _FillBlankInputState extends State<_FillBlankInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          style: const TextStyle(color: Colors.white, fontSize: 20),
          textAlign: TextAlign.center,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            hintText: '輸入答案...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Colors.white24, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFF4CAF50), width: 2),
            ),
          ),
          onSubmitted: widget.onSubmit,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (_controller.text.isNotEmpty) {
                widget.onSubmit(_controller.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              '確認答案',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
