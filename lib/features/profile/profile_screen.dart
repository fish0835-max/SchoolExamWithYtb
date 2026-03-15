import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user_session.dart';

class ProfileScreen extends ConsumerWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  // Demo session data for MVP
  static final _demoSessions = [
    LearningSession(
      id: 's1',
      userId: 'child_1',
      youtubeMinutes: 30,
      questionsAnswered: 3,
      questionsCorrect: 3,
      startedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    LearningSession(
      id: 's2',
      userId: 'child_1',
      youtubeMinutes: 60,
      questionsAnswered: 6,
      questionsCorrect: 5,
      startedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    LearningSession(
      id: 's3',
      userId: 'child_1',
      youtubeMinutes: 45,
      questionsAnswered: 4,
      questionsCorrect: 4,
      startedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Aggregate stats
    final totalMinutes = _demoSessions.fold(
        0, (sum, s) => sum + s.youtubeMinutes);
    final totalAnswered = _demoSessions.fold(
        0, (sum, s) => sum + s.questionsAnswered);
    final totalCorrect = _demoSessions.fold(
        0, (sum, s) => sum + s.questionsCorrect);
    final accuracy =
        totalAnswered == 0 ? 0.0 : totalCorrect / totalAnswered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('學習記錄'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary stats
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: '$totalMinutes',
                  unit: '分鐘',
                  label: '觀看時間',
                  color: const Color(0xFFFF0000),
                  icon: Icons.play_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  value: '$totalAnswered',
                  unit: '題',
                  label: '答題總數',
                  color: const Color(0xFF1976D2),
                  icon: Icons.quiz_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  value: '${(accuracy * 100).round()}%',
                  unit: '',
                  label: '正確率',
                  color: const Color(0xFF4CAF50),
                  icon: Icons.check_circle_outline,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Streak / stars
          Card(
            elevation: 0,
            color: const Color(0xFFFFF9C4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '連續學習 3 天！',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF795548),
                        ),
                      ),
                      Text(
                        '繼續保持，明天再來！',
                        style: TextStyle(
                          color: Colors.brown[400],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            '最近學習記錄',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Session list
          ..._demoSessions.map(
            (session) => _SessionCard(session: session),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: unit,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF888888),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final LearningSession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final date = session.startedAt;
    final dateStr =
        '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final stars = (session.accuracy * 3).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_filled,
                  color: Color(0xFF4CAF50),
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '看了 ${session.youtubeMinutes} 分鐘 · '
                    '答題 ${session.questionsAnswered} 題 · '
                    '答對 ${session.questionsCorrect} 題',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  children: List.generate(
                    3,
                    (i) => Icon(
                      Icons.star,
                      size: 16,
                      color: i < stars
                          ? const Color(0xFFFFB300)
                          : Colors.grey[200],
                    ),
                  ),
                ),
                Text(
                  '${(session.accuracy * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
