// ignore: depend_on_referenced_packages
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application-wide constants and configuration
class AppConfig {
  AppConfig._();

  // ── API Keys（從 assets/.env 讀取，由 flutter_dotenv 載入）──
  // assets/.env 已加入 .gitignore，不會上傳至 Git
  static String get youtubeApiKey =>
      dotenv.env['YOUTUBE_API_KEY'] ?? '';

  // Claude API key 僅供 Cloud Functions 使用（從 functions/.env 讀取）
  // Flutter 端不應直接呼叫 Claude API

  // ── 計時器預設值 ──────────────────────────────────────────────────────────
  // 正式版 YouTube 觀看時間（分鐘）
  static const int defaultYoutubeMinutes = 30;

  // DEBUG 覆寫：設定秒數可強制覆蓋家長設定，方便測試。
  // 上線前改為 null 即可恢復使用 defaultYoutubeMinutes。
  static const int? debugDurationSeconds = 30; // null = 使用 defaultYoutubeMinutes
  // ──────────────────────────────────────────────────────────────────────────

  static const int defaultQuestionsToUnlock = 1;
  static const int defaultQuestionTimeLimitSeconds = 90;

  // AI question generation
  static const bool useAiQuestions = true;
  static const double aiQuestionRatio = 0.3; // 30% AI, 70% fixed bank

  // PIN settings
  static const int pinMinLength = 4;
  static const int pinMaxLength = 6;

  // Supported subjects
  static const List<String> subjects = ['math', 'chinese'];

  // Subject display names
  static const Map<String, String> subjectNames = {
    'math': '數學',
    'chinese': '國文',
  };

  // Grade range
  static const int minGrade = 1;
  static const int maxGrade = 6;

  // Curriculum publisher
  static const String defaultPublisher = 'kangxuan';

  // Local DB
  static const String localDbName = 'school_exam.db';
  static const int localDbVersion = 1;

  // Asset paths
  static const String questionsAssetPath = 'assets/questions/questions.json';
  static const String correctAnimationPath = 'assets/animations/correct.json';
  static const String wrongAnimationPath = 'assets/animations/wrong.json';
  static const String celebrationAnimationPath = 'assets/animations/celebration.json';
}

/// Parent-configurable settings (stored in shared_preferences)
class ParentSettings {
  int youtubeSessionMinutes;
  int questionsToUnlock;
  int questionTimeLimitSeconds;

  // Math settings
  int mathGrade;
  int mathSemester;
  String mathScopeMode; // 'range' | 'single'
  int mathMaxUnitOrder;
  int mathTargetUnitOrder;

  // Chinese settings
  int chineseGrade;
  int chineseSemester;
  String chineseScopeMode;
  int chineseMaxUnitOrder;
  int chineseTargetUnitOrder;

  // Question source
  String questionSource; // 'fixed' | 'ai' | 'photo' | 'mixed'

  ParentSettings({
    this.youtubeSessionMinutes = AppConfig.defaultYoutubeMinutes,
    this.questionsToUnlock = AppConfig.defaultQuestionsToUnlock,
    this.questionTimeLimitSeconds = AppConfig.defaultQuestionTimeLimitSeconds,
    this.mathGrade = 2,
    this.mathSemester = 1,
    this.mathScopeMode = 'range',
    this.mathMaxUnitOrder = 5,
    this.mathTargetUnitOrder = 1,
    this.chineseGrade = 2,
    this.chineseSemester = 1,
    this.chineseScopeMode = 'range',
    this.chineseMaxUnitOrder = 5,
    this.chineseTargetUnitOrder = 1,
    this.questionSource = 'mixed',
  });

  Map<String, dynamic> toJson() => {
        'youtubeSessionMinutes': youtubeSessionMinutes,
        'questionsToUnlock': questionsToUnlock,
        'questionTimeLimitSeconds': questionTimeLimitSeconds,
        'mathGrade': mathGrade,
        'mathSemester': mathSemester,
        'mathScopeMode': mathScopeMode,
        'mathMaxUnitOrder': mathMaxUnitOrder,
        'mathTargetUnitOrder': mathTargetUnitOrder,
        'chineseGrade': chineseGrade,
        'chineseSemester': chineseSemester,
        'chineseScopeMode': chineseScopeMode,
        'chineseMaxUnitOrder': chineseMaxUnitOrder,
        'chineseTargetUnitOrder': chineseTargetUnitOrder,
        'questionSource': questionSource,
      };

  factory ParentSettings.fromJson(Map<String, dynamic> json) => ParentSettings(
        youtubeSessionMinutes:
            ((json['youtubeSessionMinutes'] as int?) ?? 0) > 0
                ? json['youtubeSessionMinutes'] as int
                : AppConfig.defaultYoutubeMinutes,
        questionsToUnlock:
            ((json['questionsToUnlock'] as int?) ?? 0) > 0
                ? json['questionsToUnlock'] as int
                : AppConfig.defaultQuestionsToUnlock,
        questionTimeLimitSeconds:
            ((json['questionTimeLimitSeconds'] as int?) ?? 0) > 0
                ? json['questionTimeLimitSeconds'] as int
                : AppConfig.defaultQuestionTimeLimitSeconds,
        mathGrade: json['mathGrade'] ?? 2,
        mathSemester: json['mathSemester'] ?? 1,
        mathScopeMode: json['mathScopeMode'] ?? 'range',
        mathMaxUnitOrder: json['mathMaxUnitOrder'] ?? 5,
        mathTargetUnitOrder: json['mathTargetUnitOrder'] ?? 1,
        chineseGrade: json['chineseGrade'] ?? 2,
        chineseSemester: json['chineseSemester'] ?? 1,
        chineseScopeMode: json['chineseScopeMode'] ?? 'range',
        chineseMaxUnitOrder: json['chineseMaxUnitOrder'] ?? 5,
        chineseTargetUnitOrder: json['chineseTargetUnitOrder'] ?? 1,
        questionSource: json['questionSource'] ?? 'mixed',
      );
}
