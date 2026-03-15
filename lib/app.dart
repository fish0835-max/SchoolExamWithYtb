import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers/auth_provider.dart';
import 'features/child/home/home_screen.dart';
import 'features/child/youtube_player/youtube_player_screen.dart';
import 'features/parent/pin_gate/pin_gate_screen.dart';
import 'features/parent/dashboard/parent_dashboard_screen.dart';
import 'features/parent/subject_range/subject_range_screen.dart';
import 'features/parent/timer_config/timer_config_screen.dart';
import 'features/parent/photo_upload/photo_upload_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/child/home/child_select_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/child-select',
    routes: [
      // Child selection screen
      GoRoute(
        path: '/child-select',
        builder: (context, state) => const ChildSelectScreen(),
      ),

      // Child home (YouTube + timer)
      GoRoute(
        path: '/child/home',
        builder: (context, state) => const HomeScreen(),
      ),

      // YouTube player with quiz overlay
      GoRoute(
        path: '/child/player',
        builder: (context, state) {
          final videoId = state.uri.queryParameters['videoId'] ?? '';
          return YoutubePlayerScreen(videoId: videoId);
        },
      ),

      // Parent PIN gate
      GoRoute(
        path: '/parent/pin',
        builder: (context, state) => const PinGateScreen(),
      ),

      // Parent dashboard (PIN protected)
      GoRoute(
        path: '/parent/dashboard',
        builder: (context, state) => const ParentDashboardScreen(),
      ),

      // Subject range settings
      GoRoute(
        path: '/parent/subject-range',
        builder: (context, state) {
          final subject = state.uri.queryParameters['subject'] ?? 'math';
          return SubjectRangeScreen(subject: subject);
        },
      ),

      // Timer config
      GoRoute(
        path: '/parent/timer-config',
        builder: (context, state) => const TimerConfigScreen(),
      ),

      // Photo upload for custom questions
      GoRoute(
        path: '/parent/photo-upload',
        builder: (context, state) => const PhotoUploadScreen(),
      ),

      // Child profile / learning history
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return ProfileScreen(userId: userId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('頁面不存在：${state.error}'),
      ),
    ),
  );
});

class SchoolExamApp extends ConsumerWidget {
  const SchoolExamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '康軒學習遊戲',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      routerConfig: router,
      locale: const Locale('zh', 'TW'),
    );
  }
}
