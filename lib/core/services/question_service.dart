import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/question.dart';
import 'local_db_service.dart';
import 'settings_service.dart';

/// Abstract interface for question sources
abstract class QuestionSourceStrategy {
  Future<Question?> fetchQuestion({
    required int grade,
    required String subject,
    required int semester,
    required String scopeMode,
    int? maxUnitOrder,
    int? targetUnitOrder,
    String? unitName,
  });
}

/// Fixed question bank from local SQLite
class FixedBankSource implements QuestionSourceStrategy {
  final LocalDbService _db;
  FixedBankSource(this._db);

  @override
  Future<Question?> fetchQuestion({
    required int grade,
    required String subject,
    required int semester,
    required String scopeMode,
    int? maxUnitOrder,
    int? targetUnitOrder,
    String? unitName,
  }) async {
    final questions = await _db.getQuestions(
      grade: grade,
      subject: subject,
      semester: semester,
      scopeMode: scopeMode,
      maxUnitOrder: maxUnitOrder,
      targetUnitOrder: targetUnitOrder,
      limit: 1,
    );
    return questions.isEmpty ? null : questions.first;
  }
}

/// AI-generated questions via Firebase Cloud Function
class AIGeneratedSource implements QuestionSourceStrategy {
  final FirebaseFunctions _functions;
  final LocalDbService _db;

  AIGeneratedSource(this._functions, this._db);

  @override
  Future<Question?> fetchQuestion({
    required int grade,
    required String subject,
    required int semester,
    required String scopeMode,
    int? maxUnitOrder,
    int? targetUnitOrder,
    String? unitName,
  }) async {
    try {
      final callable = _functions.httpsCallable('generateQuestion');
      final result = await callable.call({
        'grade': grade,
        'subject': subject,
        'semester': semester,
        'scope_mode': scopeMode,
        'max_unit_order': maxUnitOrder,
        'target_unit_order': targetUnitOrder,
        'unit_name': unitName,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final question = Question.fromJson({
        ...data,
        'id': const Uuid().v4(),
        'grade': grade,
        'subject': subject,
        'semester': semester,
        'source': 'ai',
      });
      // Cache AI-generated question locally
      await _db.insertQuestion(question);
      return question;
    } catch (e) {
      // Fall through — caller will use fixed bank as fallback
    }
    return null;
  }
}

/// Photo-based question generation via Firebase Cloud Function
class PhotoSource implements QuestionSourceStrategy {
  final FirebaseFunctions _functions;
  final String base64Image;

  PhotoSource(this._functions, {required this.base64Image});

  @override
  Future<Question?> fetchQuestion({
    required int grade,
    required String subject,
    required int semester,
    required String scopeMode,
    int? maxUnitOrder,
    int? targetUnitOrder,
    String? unitName,
  }) async {
    try {
      final callable = _functions.httpsCallable('generateFromPhoto');
      final result = await callable.call({
        'image_base64': base64Image,
        'grade': grade,
        'subject': subject,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      return Question.fromJson({
        ...data,
        'id': const Uuid().v4(),
        'grade': grade,
        'subject': subject,
        'semester': semester,
        'source': 'photo',
      });
    } catch (e) {
      // Fall through
    }
    return null;
  }
}

/// Main question service that coordinates sources based on parent settings
class QuestionService {
  final LocalDbService _db;
  final FirebaseFunctions _functions;
  final SettingsService _settings;

  QuestionService(this._db, this._functions, this._settings);

  Future<Question?> getNextQuestion(String subject) async {
    final settings = await _settings.getSettings();

    final grade =
        subject == 'math' ? settings.mathGrade : settings.chineseGrade;
    final semester =
        subject == 'math' ? settings.mathSemester : settings.chineseSemester;
    final scopeMode =
        subject == 'math' ? settings.mathScopeMode : settings.chineseScopeMode;
    final maxUnitOrder = subject == 'math'
        ? settings.mathMaxUnitOrder
        : settings.chineseMaxUnitOrder;
    final targetUnitOrder = subject == 'math'
        ? settings.mathTargetUnitOrder
        : settings.chineseTargetUnitOrder;

    final questionSource = settings.questionSource;

    if (questionSource == 'ai') {
      final aiSource = AIGeneratedSource(_functions, _db);
      return aiSource.fetchQuestion(
        grade: grade,
        subject: subject,
        semester: semester,
        scopeMode: scopeMode,
        maxUnitOrder: maxUnitOrder,
        targetUnitOrder: targetUnitOrder,
      );
    }

    if (questionSource == 'fixed') {
      final fixedSource = FixedBankSource(_db);
      return fixedSource.fetchQuestion(
        grade: grade,
        subject: subject,
        semester: semester,
        scopeMode: scopeMode,
        maxUnitOrder: maxUnitOrder,
        targetUnitOrder: targetUnitOrder,
      );
    }

    // 'mixed' mode: 30% AI, 70% fixed
    if (questionSource == 'mixed') {
      final useAi = (DateTime.now().millisecondsSinceEpoch % 10) <
          (AppConfig.aiQuestionRatio * 10);

      if (useAi) {
        final aiSource = AIGeneratedSource(_functions, _db);
        final q = await aiSource.fetchQuestion(
          grade: grade,
          subject: subject,
          semester: semester,
          scopeMode: scopeMode,
          maxUnitOrder: maxUnitOrder,
          targetUnitOrder: targetUnitOrder,
        );
        if (q != null) return q;
      }

      // Fallback to fixed bank
      final fixedSource = FixedBankSource(_db);
      return fixedSource.fetchQuestion(
        grade: grade,
        subject: subject,
        semester: semester,
        scopeMode: scopeMode,
        maxUnitOrder: maxUnitOrder,
        targetUnitOrder: targetUnitOrder,
      );
    }

    return null;
  }
}

final questionServiceProvider = Provider<QuestionService>((ref) {
  return QuestionService(
    LocalDbService.instance,
    FirebaseFunctions.instance,
    ref.watch(settingsServiceProvider),
  );
});
