import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/config/app_config.dart';

class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  // Demo children for MVP
  static final _demoChildren = [
    (id: 'child_1', name: '小明', emoji: '🐻'),
    (id: 'child_2', name: '小華', emoji: '🐰'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          '家長設定',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(parentModeProvider.notifier).state = false;
            context.go('/child-select');
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Children management section
          _SectionHeader(title: '孩子帳號管理', icon: Icons.people),
          const SizedBox(height: 8),
          ..._demoChildren.map(
            (child) => _ChildTile(
              childId: child.id,
              name: child.name,
              emoji: child.emoji,
              onViewProfile: () => context.push('/profile/${child.id}'),
            ),
          ),
          _AddChildTile(
            onTap: () {
              _showAddChildDialog(context, ref);
            },
          ),

          const SizedBox(height: 24),

          // Subject settings section
          _SectionHeader(title: '出題範圍設定', icon: Icons.school),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.calculate,
            iconColor: const Color(0xFF1976D2),
            title: '數學設定',
            subtitle: '年級、學期、課次範圍',
            onTap: () => context.push('/parent/subject-range?subject=math'),
          ),
          _SettingsTile(
            icon: Icons.menu_book,
            iconColor: const Color(0xFF388E3C),
            title: '國文設定',
            subtitle: '年級、學期、課次範圍',
            onTap: () =>
                context.push('/parent/subject-range?subject=chinese'),
          ),

          const SizedBox(height: 24),

          // Timer settings
          _SectionHeader(title: '計時器設定', icon: Icons.timer),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.access_time,
            iconColor: const Color(0xFFE64A19),
            title: '計時器設定',
            subtitle: 'YouTube 時間、答題數量',
            onTap: () => context.push('/parent/timer-config'),
          ),

          const SizedBox(height: 24),

          // Question source settings
          _SectionHeader(title: '出題來源', icon: Icons.quiz),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.camera_alt,
            iconColor: const Color(0xFF7B1FA2),
            title: '照片出題',
            subtitle: '上傳教材照片，AI 自動出題',
            onTap: () => context.push('/parent/photo-upload'),
          ),

          const SizedBox(height: 24),

          // Danger zone
          _SectionHeader(title: '其他', icon: Icons.more_horiz),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.lock_reset,
            iconColor: Colors.red,
            title: '重設 PIN 碼',
            subtitle: '更改家長解鎖密碼',
            onTap: () => _showResetPinDialog(context, ref),
          ),
        ],
      ),
    );
  }

  void _showAddChildDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增孩子'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '孩子的名字',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ctx.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已新增 ${nameController.text}'),
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('新增'),
          ),
        ],
      ),
    );
  }

  void _showResetPinDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重設 PIN 碼'),
        content: const Text('確定要重設 PIN 碼嗎？\n下次進入家長模式時需輸入新 PIN 碼。'),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              // Clear PIN
              final prefs =
                  await ref.read(settingsServiceProvider).hasPin();
              ctx.pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PIN 碼已重設，下次進入家長模式時請設定新 PIN 碼'),
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('確定重設'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF666666)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF666666),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Color(0xFFCCCCCC),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ChildTile extends StatelessWidget {
  final String childId;
  final String name;
  final String emoji;
  final VoidCallback onViewProfile;

  const _ChildTile({
    required this.childId,
    required this.name,
    required this.emoji,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 32)),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: TextButton(
          onPressed: onViewProfile,
          child: const Text('查看記錄'),
        ),
      ),
    );
  }
}

class _AddChildTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddChildTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFCCCCCC), width: 1.5),
      ),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.add, color: Color(0xFF4CAF50)),
        ),
        title: const Text(
          '新增孩子',
          style: TextStyle(
            color: Color(0xFF4CAF50),
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
