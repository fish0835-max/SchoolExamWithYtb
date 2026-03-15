import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/user_session.dart';
import '../../../core/providers/auth_provider.dart';

class ChildSelectScreen extends ConsumerWidget {
  const ChildSelectScreen({super.key});

  // Demo children for MVP (replace with Supabase fetch in production)
  static final _demoChildren = [
    ChildUser(
      id: 'child_1',
      familyId: 'family_1',
      name: '小明',
      avatarEmoji: '🐻',
      createdAt: DateTime(2024, 1, 1),
    ),
    ChildUser(
      id: 'child_2',
      familyId: 'family_1',
      name: '小華',
      avatarEmoji: '🐰',
      createdAt: DateTime(2024, 1, 1),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FFF4),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            // Title
            const Text(
              '今天誰要學習？',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '選擇你的頭像開始吧！',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF66BB6A),
              ),
            ),
            const SizedBox(height: 48),

            // Child avatar grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemCount: _demoChildren.length + 1,
                itemBuilder: (context, index) {
                  if (index < _demoChildren.length) {
                    return _ChildCard(
                      child: _demoChildren[index],
                      onTap: () {
                        ref.read(activeChildProvider.notifier).state =
                            _demoChildren[index];
                        context.go('/child/home');
                      },
                    );
                  }
                  // "Add child" card (parent only)
                  return _AddChildCard(
                    onTap: () => context.push('/parent/pin'),
                  );
                },
              ),
            ),

            // Hidden parent mode button (bottom-right corner)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onLongPress: () => context.push('/parent/pin'),
                  child: const Icon(
                    Icons.settings,
                    color: Color(0xFFCCCCCC),
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final ChildUser child;
  final VoidCallback onTap;

  const _ChildCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              child.avatarEmoji ?? '😊',
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 12),
            Text(
              child.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddChildCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddChildCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFCCCCCC),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 48,
              color: Color(0xFFAAAAAA),
            ),
            SizedBox(height: 12),
            Text(
              '新增孩子',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFFAAAAAA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
