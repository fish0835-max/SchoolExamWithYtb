import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/settings_service.dart';

class TimerConfigScreen extends ConsumerStatefulWidget {
  const TimerConfigScreen({super.key});

  @override
  ConsumerState<TimerConfigScreen> createState() =>
      _TimerConfigScreenState();
}

class _TimerConfigScreenState extends ConsumerState<TimerConfigScreen> {
  bool _isLoading = true;
  late ParentSettings _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await ref.read(settingsServiceProvider).getSettings();
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    await ref.read(settingsServiceProvider).saveSettings(_settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('計時器設定已儲存'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('計時器設定'),
        backgroundColor: const Color(0xFFE64A19),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text(
              '儲存',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // YouTube session time
          _TimerCard(
            icon: Icons.play_circle_outline,
            iconColor: const Color(0xFFFF0000),
            title: 'YouTube 觀看時間',
            description: '孩子每次看 YouTube 的分鐘數，時間到強制出題',
            value: _settings.youtubeSessionMinutes,
            min: 5,
            max: 120,
            step: 5,
            unit: '分鐘',
            onChanged: (v) => setState(() {
              _settings = _copyWith(youtubeSessionMinutes: v);
            }),
          ),

          const SizedBox(height: 12),

          // Questions to unlock
          _TimerCard(
            icon: Icons.quiz_outlined,
            iconColor: const Color(0xFF4CAF50),
            title: '需答對題數',
            description: '孩子需要答對幾題才能繼續看 YouTube',
            value: _settings.questionsToUnlock,
            min: 1,
            max: 10,
            step: 1,
            unit: '題',
            onChanged: (v) => setState(() {
              _settings = _copyWith(questionsToUnlock: v);
            }),
          ),

          const SizedBox(height: 12),

          // Question time limit
          _TimerCard(
            icon: Icons.hourglass_empty,
            iconColor: const Color(0xFF1976D2),
            title: '每題作答時間',
            description: '每題限制作答秒數（0 = 無限制）',
            value: _settings.questionTimeLimitSeconds,
            min: 0,
            max: 300,
            step: 15,
            unit: '秒',
            zeroLabel: '無限制',
            onChanged: (v) => setState(() {
              _settings = _copyWith(questionTimeLimitSeconds: v);
            }),
          ),

          const SizedBox(height: 24),

          // Summary card
          Card(
            elevation: 0,
            color: const Color(0xFFF3E5F5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF7B1FA2)),
                      SizedBox(width: 8),
                      Text(
                        '目前設定摘要',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7B1FA2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '孩子每看 ${_settings.youtubeSessionMinutes} 分鐘 YouTube，'
                    '需答對 ${_settings.questionsToUnlock} 題才能繼續。\n'
                    '每題作答時間：${_settings.questionTimeLimitSeconds == 0 ? "無限制" : "${_settings.questionTimeLimitSeconds} 秒"}',
                    style: const TextStyle(
                      color: Color(0xFF6A1B9A),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  ParentSettings _copyWith({
    int? youtubeSessionMinutes,
    int? questionsToUnlock,
    int? questionTimeLimitSeconds,
  }) =>
      ParentSettings(
        youtubeSessionMinutes:
            youtubeSessionMinutes ?? _settings.youtubeSessionMinutes,
        questionsToUnlock:
            questionsToUnlock ?? _settings.questionsToUnlock,
        questionTimeLimitSeconds:
            questionTimeLimitSeconds ?? _settings.questionTimeLimitSeconds,
        mathGrade: _settings.mathGrade,
        mathSemester: _settings.mathSemester,
        mathScopeMode: _settings.mathScopeMode,
        mathMaxUnitOrder: _settings.mathMaxUnitOrder,
        mathTargetUnitOrder: _settings.mathTargetUnitOrder,
        chineseGrade: _settings.chineseGrade,
        chineseSemester: _settings.chineseSemester,
        chineseScopeMode: _settings.chineseScopeMode,
        chineseMaxUnitOrder: _settings.chineseMaxUnitOrder,
        chineseTargetUnitOrder: _settings.chineseTargetUnitOrder,
        questionSource: _settings.questionSource,
      );
}

class _TimerCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final int value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final String? zeroLabel;
  final void Function(int) onChanged;

  const _TimerCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    this.zeroLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue =
        value == 0 && zeroLabel != null ? zeroLabel! : '$value $unit';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF888888),
              ),
            ),
            Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: (max - min) ~/ step,
              label: displayValue,
              activeColor: iconColor,
              onChanged: (v) => onChanged(
                (v / step).round() * step,
              ),
            ),
            // Quick preset buttons
            Wrap(
              spacing: 8,
              children: _presets.map((preset) {
                final label = preset == 0 && zeroLabel != null
                    ? zeroLabel!
                    : '$preset $unit';
                return ActionChip(
                  label: Text(label),
                  onPressed: () => onChanged(preset),
                  backgroundColor:
                      value == preset ? iconColor.withOpacity(0.15) : null,
                  labelStyle: TextStyle(
                    color: value == preset ? iconColor : null,
                    fontWeight: value == preset
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  List<int> get _presets {
    if (unit == '分鐘') return [10, 15, 20, 30, 45, 60];
    if (unit == '題') return [1, 2, 3, 5];
    if (unit == '秒') return [0, 30, 60, 90, 120, 180];
    return [];
  }
}
