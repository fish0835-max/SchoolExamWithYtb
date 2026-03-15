/// Represents a single quiz question
class Question {
  final String id;
  final int grade;
  final String subject;
  final int semester;
  final String? unit;
  final int? unitOrder;
  final String questionText;
  final List<String>? options; // null for fill-in-the-blank
  final String correctAnswer;
  final QuestionType questionType;
  final int difficulty; // 1-3
  final QuestionSource source;

  const Question({
    required this.id,
    required this.grade,
    required this.subject,
    required this.semester,
    this.unit,
    this.unitOrder,
    required this.questionText,
    this.options,
    required this.correctAnswer,
    required this.questionType,
    this.difficulty = 1,
    this.source = QuestionSource.fixed,
  });

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id']?.toString() ?? '',
        grade: json['grade'] as int,
        subject: json['subject'] as String,
        semester: json['semester'] as int? ?? 1,
        unit: json['unit_name'] as String? ?? json['unit'] as String?,
        unitOrder: json['unit_order'] as int?,
        questionText: json['question_text'] as String,
        options: (json['options'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
        correctAnswer: json['correct_answer'] as String,
        questionType: QuestionType.fromString(json['question_type'] as String),
        difficulty: json['difficulty'] as int? ?? 1,
        source: QuestionSource.fromString(json['source'] as String? ?? 'fixed'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'grade': grade,
        'subject': subject,
        'semester': semester,
        'unit': unit,
        'unit_order': unitOrder,
        'question_text': questionText,
        'options': options,
        'correct_answer': correctAnswer,
        'question_type': questionType.value,
        'difficulty': difficulty,
        'source': source.value,
      };

  bool checkAnswer(String answer) {
    return answer.trim() == correctAnswer.trim();
  }
}

enum QuestionType {
  multipleChoice('multiple_choice'),
  fillBlank('fill_blank');

  const QuestionType(this.value);
  final String value;

  static QuestionType fromString(String s) => switch (s) {
        'fill_blank' => fillBlank,
        _ => multipleChoice,
      };
}

enum QuestionSource {
  fixed('fixed'),
  ai('ai'),
  photo('photo');

  const QuestionSource(this.value);
  final String value;

  static QuestionSource fromString(String s) => switch (s) {
        'ai' => ai,
        'photo' => photo,
        _ => fixed,
      };
}

/// Represents the result of a quiz attempt
class QuizResult {
  final Question question;
  final String userAnswer;
  final bool isCorrect;
  final DateTime answeredAt;

  const QuizResult({
    required this.question,
    required this.userAnswer,
    required this.isCorrect,
    required this.answeredAt,
  });
}
