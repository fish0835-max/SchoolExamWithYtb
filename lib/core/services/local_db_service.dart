import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

// sqflite 僅在非 Web 平台使用
import 'package:sqflite/sqflite.dart' if (dart.library.html) 'stub/sqflite_stub.dart';
import 'package:path/path.dart' if (dart.library.html) 'stub/path_stub.dart';

import '../config/app_config.dart';
import '../models/question.dart';

/// Local question bank service
/// - Web: in-memory list loaded from JSON asset
/// - Mobile / Desktop: SQLite
class LocalDbService {
  static final LocalDbService instance = LocalDbService._();
  LocalDbService._();

  // Web: in-memory cache
  final List<Question> _webCache = [];

  // Mobile/Desktop: SQLite
  Database? _db;

  Future<void> init() async {
    if (kIsWeb) {
      await _loadWebCache();
    } else {
      await _initSqlite();
    }
  }

  // ── Web: load from JSON asset ─────────────────────────────
  Future<void> _loadWebCache() async {
    try {
      final jsonStr =
          await rootBundle.loadString(AppConfig.questionsAssetPath);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final questions = data['questions'] as List<dynamic>;
      _webCache.clear();
      for (final q in questions) {
        _webCache.add(Question.fromJson(q as Map<String, dynamic>));
      }
    } catch (_) {
      // Asset not ready yet — will return empty list
    }
  }

  // ── Mobile/Desktop: SQLite ────────────────────────────────
  Future<void> _initSqlite() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConfig.localDbName);

    _db = await openDatabase(
      path,
      version: AppConfig.localDbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    await _seedFromAssets();
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS questions (
        id TEXT PRIMARY KEY,
        grade INTEGER NOT NULL,
        subject TEXT NOT NULL,
        semester INTEGER NOT NULL,
        unit TEXT,
        unit_order INTEGER,
        question_text TEXT NOT NULL,
        options TEXT,
        correct_answer TEXT NOT NULL,
        question_type TEXT NOT NULL,
        difficulty INTEGER DEFAULT 1,
        source TEXT DEFAULT 'fixed'
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}

  Future<void> _seedFromAssets() async {
    final db = _db!;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM questions'),
    );
    if (count != null && count > 0) return;

    try {
      final jsonStr =
          await rootBundle.loadString(AppConfig.questionsAssetPath);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final questions = data['questions'] as List<dynamic>;

      final batch = db.batch();
      for (final q in questions) {
        final map = q as Map<String, dynamic>;
        batch.insert(
          'questions',
          {
            'id': map['id']?.toString() ?? '',
            'grade': map['grade'],
            'subject': map['subject'],
            'semester': map['semester'] ?? 1,
            'unit': map['unit_name'],
            'unit_order': map['unit_order'],
            'question_text': map['question_text'],
            'options': map['options'] != null
                ? jsonEncode(map['options'])
                : null,
            'correct_answer': map['correct_answer'],
            'question_type': map['question_type'] ?? 'multiple_choice',
            'difficulty': map['difficulty'] ?? 1,
            'source': 'fixed',
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  // ── Public API ────────────────────────────────────────────

  Future<List<Question>> getQuestions({
    required int grade,
    required String subject,
    required int semester,
    required String scopeMode,
    int? maxUnitOrder,
    int? targetUnitOrder,
    int limit = 10,
  }) async {
    if (kIsWeb) {
      return _getWebQuestions(
        grade: grade,
        subject: subject,
        semester: semester,
        scopeMode: scopeMode,
        maxUnitOrder: maxUnitOrder,
        targetUnitOrder: targetUnitOrder,
        limit: limit,
      );
    }
    return _getSqliteQuestions(
      grade: grade,
      subject: subject,
      semester: semester,
      scopeMode: scopeMode,
      maxUnitOrder: maxUnitOrder,
      targetUnitOrder: targetUnitOrder,
      limit: limit,
    );
  }

  List<Question> _getWebQuestions({
    required int grade,
    required String subject,
    required int semester,
    required String scopeMode,
    int? maxUnitOrder,
    int? targetUnitOrder,
    required int limit,
  }) {
    var filtered = _webCache.where((q) {
      if (q.grade != grade || q.subject != subject || q.semester != semester) {
        return false;
      }
      if (scopeMode == 'single' && targetUnitOrder != null) {
        return q.unitOrder == targetUnitOrder;
      }
      if (scopeMode == 'range' && maxUnitOrder != null) {
        return (q.unitOrder ?? 0) <= maxUnitOrder;
      }
      return true;
    }).toList();

    filtered.shuffle(Random());
    return filtered.take(limit).toList();
  }

  Future<List<Question>> _getSqliteQuestions({
    required int grade,
    required String subject,
    required int semester,
    required String scopeMode,
    int? maxUnitOrder,
    int? targetUnitOrder,
    required int limit,
  }) async {
    final db = _db!;
    String where = 'grade = ? AND subject = ? AND semester = ?';
    final args = <dynamic>[grade, subject, semester];

    if (scopeMode == 'single' && targetUnitOrder != null) {
      where += ' AND unit_order = ?';
      args.add(targetUnitOrder);
    } else if (scopeMode == 'range' && maxUnitOrder != null) {
      where += ' AND unit_order <= ?';
      args.add(maxUnitOrder);
    }

    final rows = await db.query(
      'questions',
      where: where,
      whereArgs: args,
      orderBy: 'RANDOM()',
      limit: limit,
    );

    return rows.map((row) {
      final optionsRaw = row['options'] as String?;
      return Question(
        id: row['id'] as String,
        grade: row['grade'] as int,
        subject: row['subject'] as String,
        semester: row['semester'] as int,
        unit: row['unit'] as String?,
        unitOrder: row['unit_order'] as int?,
        questionText: row['question_text'] as String,
        options: optionsRaw != null
            ? (jsonDecode(optionsRaw) as List).cast<String>()
            : null,
        correctAnswer: row['correct_answer'] as String,
        questionType: QuestionType.fromString(row['question_type'] as String),
        difficulty: row['difficulty'] as int? ?? 1,
        source: QuestionSource.fromString(row['source'] as String? ?? 'fixed'),
      );
    }).toList();
  }

  Future<void> insertQuestion(Question question) async {
    if (kIsWeb) {
      // Add to in-memory cache (not persisted across refresh on web)
      _webCache.removeWhere((q) => q.id == question.id);
      _webCache.add(question);
      return;
    }
    final db = _db!;
    await db.insert(
      'questions',
      {
        'id': question.id,
        'grade': question.grade,
        'subject': question.subject,
        'semester': question.semester,
        'unit': question.unit,
        'unit_order': question.unitOrder,
        'question_text': question.questionText,
        'options': question.options != null
            ? jsonEncode(question.options)
            : null,
        'correct_answer': question.correctAnswer,
        'question_type': question.questionType.value,
        'difficulty': question.difficulty,
        'source': question.source.value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
