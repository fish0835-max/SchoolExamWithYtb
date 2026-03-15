/// Represents a child user profile
class ChildUser {
  final String id;
  final String familyId;
  final String name;
  final String? avatarEmoji;
  final DateTime createdAt;

  const ChildUser({
    required this.id,
    required this.familyId,
    required this.name,
    this.avatarEmoji,
    required this.createdAt,
  });

  factory ChildUser.fromJson(Map<String, dynamic> json) => ChildUser(
        id: json['id'] as String,
        familyId: json['family_id'] as String,
        name: json['name'] as String,
        avatarEmoji: json['avatar_emoji'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'family_id': familyId,
        'name': name,
        'avatar_emoji': avatarEmoji,
        'created_at': createdAt.toIso8601String(),
      };

  ChildUser copyWith({
    String? name,
    String? avatarEmoji,
  }) =>
      ChildUser(
        id: id,
        familyId: familyId,
        name: name ?? this.name,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        createdAt: createdAt,
      );
}

/// Represents a learning session
class LearningSession {
  final String id;
  final String userId;
  int youtubeMinutes;
  int questionsAnswered;
  int questionsCorrect;
  final DateTime startedAt;

  LearningSession({
    required this.id,
    required this.userId,
    this.youtubeMinutes = 0,
    this.questionsAnswered = 0,
    this.questionsCorrect = 0,
    required this.startedAt,
  });

  factory LearningSession.fromJson(Map<String, dynamic> json) => LearningSession(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        youtubeMinutes: json['youtube_minutes'] as int? ?? 0,
        questionsAnswered: json['questions_answered'] as int? ?? 0,
        questionsCorrect: json['questions_correct'] as int? ?? 0,
        startedAt: DateTime.parse(json['started_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'youtube_minutes': youtubeMinutes,
        'questions_answered': questionsAnswered,
        'questions_correct': questionsCorrect,
        'started_at': startedAt.toIso8601String(),
      };

  double get accuracy =>
      questionsAnswered == 0 ? 0 : questionsCorrect / questionsAnswered;
}

/// Represents a curriculum unit (lesson)
class CurriculumUnit {
  final String id;
  final String publisher;
  final int grade;
  final int semester;
  final String subject;
  final int unitOrder;
  final String unitName;

  const CurriculumUnit({
    required this.id,
    required this.publisher,
    required this.grade,
    required this.semester,
    required this.subject,
    required this.unitOrder,
    required this.unitName,
  });

  factory CurriculumUnit.fromJson(Map<String, dynamic> json) => CurriculumUnit(
        id: json['id'] as String,
        publisher: json['publisher'] as String,
        grade: json['grade'] as int,
        semester: json['semester'] as int,
        subject: json['subject'] as String,
        unitOrder: json['unit_order'] as int,
        unitName: json['unit_name'] as String,
      );
}
