import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_session.dart';

/// Firebase Firestore data access layer（取代 Supabase service）
///
/// Firestore 集合對應：
///   families        → /families/{familyId}
///   users (孩子)    → /families/{familyId}/users/{userId}
///   child_settings  → /families/{familyId}/users/{userId}/settings/{subject}
///   sessions        → /families/{familyId}/users/{userId}/sessions/{sessionId}
///   questions       → /questions/{questionId}
///   curriculum_units→ /curriculum_units/{unitId}
class FirebaseService {
  final FirebaseFirestore _db;
  FirebaseService(this._db);

  // --- Family & User management ---

  Future<String> createFamily(String pinHash) async {
    final ref = await _db.collection('families').add({
      'pin_hash': pinHash,
      'created_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<ChildUser> createChild(
    String familyId,
    String name, {
    String? avatarEmoji,
  }) async {
    final ref = await _db
        .collection('families')
        .doc(familyId)
        .collection('users')
        .add({
      'family_id': familyId,
      'name': name,
      'avatar_emoji': avatarEmoji ?? '😊',
      'created_at': FieldValue.serverTimestamp(),
    });
    final snap = await ref.get();
    return _childFromDoc(snap);
  }

  Future<List<ChildUser>> getChildren(String familyId) async {
    final snap = await _db
        .collection('families')
        .doc(familyId)
        .collection('users')
        .orderBy('created_at')
        .get();
    return snap.docs.map(_childFromDoc).toList();
  }

  Future<void> updateChild(
    String familyId,
    String childId, {
    String? name,
    String? avatarEmoji,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (avatarEmoji != null) updates['avatar_emoji'] = avatarEmoji;
    await _db
        .collection('families')
        .doc(familyId)
        .collection('users')
        .doc(childId)
        .update(updates);
  }

  Future<void> deleteChild(String familyId, String childId) async {
    await _db
        .collection('families')
        .doc(familyId)
        .collection('users')
        .doc(childId)
        .delete();
  }

  // --- Sessions ---

  Future<LearningSession> startSession(
      String familyId, String userId) async {
    final ref = await _db
        .collection('families')
        .doc(familyId)
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .add({
      'user_id': userId,
      'youtube_minutes': 0,
      'questions_answered': 0,
      'questions_correct': 0,
      'started_at': FieldValue.serverTimestamp(),
    });
    return LearningSession(
      id: ref.id,
      userId: userId,
      startedAt: DateTime.now(),
    );
  }

  Future<void> updateSession(
    String familyId,
    String userId,
    String sessionId, {
    int? youtubeMinutes,
    int? questionsAnswered,
    int? questionsCorrect,
  }) async {
    final updates = <String, dynamic>{};
    if (youtubeMinutes != null) updates['youtube_minutes'] = youtubeMinutes;
    if (questionsAnswered != null) {
      updates['questions_answered'] = questionsAnswered;
    }
    if (questionsCorrect != null) {
      updates['questions_correct'] = questionsCorrect;
    }
    await _db
        .collection('families')
        .doc(familyId)
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .doc(sessionId)
        .update(updates);
  }

  Future<List<LearningSession>> getSessions(
    String familyId,
    String userId, {
    int limit = 30,
  }) async {
    final snap = await _db
        .collection('families')
        .doc(familyId)
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .orderBy('started_at', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(_sessionFromDoc).toList();
  }

  // --- Curriculum units ---

  Future<List<CurriculumUnit>> getCurriculumUnits({
    required int grade,
    required int semester,
    required String subject,
    String publisher = 'kangxuan',
  }) async {
    final snap = await _db
        .collection('curriculum_units')
        .where('grade', isEqualTo: grade)
        .where('semester', isEqualTo: semester)
        .where('subject', isEqualTo: subject)
        .where('publisher', isEqualTo: publisher)
        .orderBy('unit_order')
        .get();
    return snap.docs.map(_unitFromDoc).toList();
  }

  // --- Helpers ---

  ChildUser _childFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAt = data['created_at'];
    return ChildUser(
      id: doc.id,
      familyId: data['family_id'] as String,
      name: data['name'] as String,
      avatarEmoji: data['avatar_emoji'] as String?,
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.now(),
    );
  }

  LearningSession _sessionFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final startedAt = data['started_at'];
    return LearningSession(
      id: doc.id,
      userId: data['user_id'] as String,
      youtubeMinutes: data['youtube_minutes'] as int? ?? 0,
      questionsAnswered: data['questions_answered'] as int? ?? 0,
      questionsCorrect: data['questions_correct'] as int? ?? 0,
      startedAt: startedAt is Timestamp
          ? startedAt.toDate()
          : DateTime.now(),
    );
  }

  CurriculumUnit _unitFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CurriculumUnit(
      id: doc.id,
      publisher: data['publisher'] as String,
      grade: data['grade'] as int,
      semester: data['semester'] as int,
      subject: data['subject'] as String,
      unitOrder: data['unit_order'] as int,
      unitName: data['unit_name'] as String,
    );
  }
}

final firebaseServiceProvider = Provider<FirebaseService>(
  (ref) => FirebaseService(FirebaseFirestore.instance),
);
