import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_session.dart';
import '../services/settings_service.dart';
import '../services/firebase_service.dart';

/// Tracks the active child user
final activeChildProvider = StateProvider<ChildUser?>((ref) => null);

/// Parent mode state (true = unlocked via PIN)
final parentModeProvider = StateProvider<bool>((ref) => false);

/// List of children for the current family
final childrenProvider = FutureProvider<List<ChildUser>>((ref) async {
  // In MVP, we use a local family ID stored in settings
  // In production, this would use Supabase auth
  return [];
});

/// Currently active session
final activeSessionProvider = StateProvider<LearningSession?>((ref) => null);
