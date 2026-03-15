import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/settings_service.dart';

class SubjectRangeScreen extends ConsumerStatefulWidget {
  final String subject;

  const SubjectRangeScreen({super.key, required this.subject});

  @override
  ConsumerState<SubjectRangeScreen> createState() =>
      _SubjectRangeScreenState();
}

class _SubjectRangeScreenState extends ConsumerState<SubjectRangeScreen> {
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
          content: Text('設定已儲存'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    }
  }

  String get _subjectName =>
      AppConfig.subjectNames[widget.subject] ?? widget.subject;

  int get _grade =>
      widget.subject == 'math' ? _settings.mathGrade : _settings.chineseGrade;

  int get _semester => widget.subject == 'math'
      ? _settings.mathSemester
      : _settings.chineseSemester;

  String get _scopeMode => widget.subject == 'math'
      ? _settings.mathScopeMode
      : _settings.chineseScopeMode;

  int get _maxUnitOrder => widget.subject == 'math'
      ? _settings.mathMaxUnitOrder
      : _settings.chineseMaxUnitOrder;

  int get _targetUnitOrder => widget.subject == 'math'
      ? _settings.mathTargetUnitOrder
      : _settings.chineseTargetUnitOrder;

  void _setGrade(int grade) {
    setState(() {
      if (widget.subject == 'math') {
        _settings = ParentSettings(
          youtubeSessionMinutes: _settings.youtubeSessionMinutes,
          questionsToUnlock: _settings.questionsToUnlock,
          questionTimeLimitSeconds: _settings.questionTimeLimitSeconds,
          mathGrade: grade,
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
      } else {
        _settings = ParentSettings(
          youtubeSessionMinutes: _settings.youtubeSessionMinutes,
          questionsToUnlock: _settings.questionsToUnlock,
          questionTimeLimitSeconds: _settings.questionTimeLimitSeconds,
          mathGrade: _settings.mathGrade,
          mathSemester: _settings.mathSemester,
          mathScopeMode: _settings.mathScopeMode,
          mathMaxUnitOrder: _settings.mathMaxUnitOrder,
          mathTargetUnitOrder: _settings.mathTargetUnitOrder,
          chineseGrade: grade,
          chineseSemester: _settings.chineseSemester,
          chineseScopeMode: _settings.chineseScopeMode,
          chineseMaxUnitOrder: _settings.chineseMaxUnitOrder,
          chineseTargetUnitOrder: _settings.chineseTargetUnitOrder,
          questionSource: _settings.questionSource,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Estimate unit count based on grade (康軒通常每學期 8-12 課)
    final estimatedUnits = 10;

    return Scaffold(
      appBar: AppBar(
        title: Text('$_subjectName 出題設定'),
        backgroundColor: widget.subject == 'math'
            ? const Color(0xFF1976D2)
            : const Color(0xFF388E3C),
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
          // Grade selector
          _SettingCard(
            title: '年級',
            child: _GradeSelector(
              selectedGrade: _grade,
              onChanged: _setGrade,
            ),
          ),

          const SizedBox(height: 12),

          // Semester selector
          _SettingCard(
            title: '學期',
            child: Row(
              children: [
                _SemesterChip(
                  label: '上學期',
                  selected: _semester == 1,
                  onTap: () => setState(() {
                    if (widget.subject == 'math') {
                      _settings = _copySettingsWith(mathSemester: 1);
                    } else {
                      _settings = _copySettingsWith(chineseSemester: 1);
                    }
                  }),
                ),
                const SizedBox(width: 8),
                _SemesterChip(
                  label: '下學期',
                  selected: _semester == 2,
                  onTap: () => setState(() {
                    if (widget.subject == 'math') {
                      _settings = _copySettingsWith(mathSemester: 2);
                    } else {
                      _settings = _copySettingsWith(chineseSemester: 2);
                    }
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Scope mode selector
          _SettingCard(
            title: '課次模式',
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('範圍模式'),
                  subtitle: const Text('從第 1 課到第 N 課都會出題'),
                  value: 'range',
                  groupValue: _scopeMode,
                  onChanged: (v) => setState(() {
                    if (widget.subject == 'math') {
                      _settings = _copySettingsWith(mathScopeMode: v!);
                    } else {
                      _settings = _copySettingsWith(chineseScopeMode: v!);
                    }
                  }),
                  activeColor: const Color(0xFF4CAF50),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  title: const Text('單課模式'),
                  subtitle: const Text('只出指定那一課的題目'),
                  value: 'single',
                  groupValue: _scopeMode,
                  onChanged: (v) => setState(() {
                    if (widget.subject == 'math') {
                      _settings = _copySettingsWith(mathScopeMode: v!);
                    } else {
                      _settings = _copySettingsWith(chineseScopeMode: v!);
                    }
                  }),
                  activeColor: const Color(0xFF4CAF50),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Unit order selector
          _SettingCard(
            title: _scopeMode == 'range' ? '最大課次（出到第幾課）' : '指定課次',
            child: Column(
              children: [
                Text(
                  _scopeMode == 'range'
                      ? '第 1 課 到 第 ${_scopeMode == 'range' ? _maxUnitOrder : _targetUnitOrder} 課'
                      : '第 $_targetUnitOrder 課',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                Slider(
                  value: (_scopeMode == 'range'
                          ? _maxUnitOrder
                          : _targetUnitOrder)
                      .toDouble(),
                  min: 1,
                  max: estimatedUnits.toDouble(),
                  divisions: estimatedUnits - 1,
                  label: '第 ${_scopeMode == 'range' ? _maxUnitOrder : _targetUnitOrder} 課',
                  activeColor: const Color(0xFF4CAF50),
                  onChanged: (v) {
                    setState(() {
                      if (_scopeMode == 'range') {
                        if (widget.subject == 'math') {
                          _settings = _copySettingsWith(
                              mathMaxUnitOrder: v.round());
                        } else {
                          _settings = _copySettingsWith(
                              chineseMaxUnitOrder: v.round());
                        }
                      } else {
                        if (widget.subject == 'math') {
                          _settings = _copySettingsWith(
                              mathTargetUnitOrder: v.round());
                        } else {
                          _settings = _copySettingsWith(
                              chineseTargetUnitOrder: v.round());
                        }
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Question source
          _SettingCard(
            title: '出題來源',
            child: Column(
              children: [
                _SourceOption(
                  value: 'fixed',
                  label: '固定題庫',
                  description: '使用預設康軒題庫',
                  icon: Icons.library_books,
                  selected: _settings.questionSource == 'fixed',
                  onTap: () => setState(() {
                    _settings = _copySettingsWith(questionSource: 'fixed');
                  }),
                ),
                _SourceOption(
                  value: 'ai',
                  label: 'AI 動態出題',
                  description: 'Claude AI 每次生成新題目',
                  icon: Icons.auto_awesome,
                  selected: _settings.questionSource == 'ai',
                  onTap: () => setState(() {
                    _settings = _copySettingsWith(questionSource: 'ai');
                  }),
                ),
                _SourceOption(
                  value: 'mixed',
                  label: '混合模式（推薦）',
                  description: '70% 固定題庫 + 30% AI 出題',
                  icon: Icons.shuffle,
                  selected: _settings.questionSource == 'mixed',
                  onTap: () => setState(() {
                    _settings = _copySettingsWith(questionSource: 'mixed');
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ParentSettings _copySettingsWith({
    int? mathGrade,
    int? mathSemester,
    String? mathScopeMode,
    int? mathMaxUnitOrder,
    int? mathTargetUnitOrder,
    int? chineseGrade,
    int? chineseSemester,
    String? chineseScopeMode,
    int? chineseMaxUnitOrder,
    int? chineseTargetUnitOrder,
    String? questionSource,
  }) =>
      ParentSettings(
        youtubeSessionMinutes: _settings.youtubeSessionMinutes,
        questionsToUnlock: _settings.questionsToUnlock,
        questionTimeLimitSeconds: _settings.questionTimeLimitSeconds,
        mathGrade: mathGrade ?? _settings.mathGrade,
        mathSemester: mathSemester ?? _settings.mathSemester,
        mathScopeMode: mathScopeMode ?? _settings.mathScopeMode,
        mathMaxUnitOrder: mathMaxUnitOrder ?? _settings.mathMaxUnitOrder,
        mathTargetUnitOrder:
            mathTargetUnitOrder ?? _settings.mathTargetUnitOrder,
        chineseGrade: chineseGrade ?? _settings.chineseGrade,
        chineseSemester: chineseSemester ?? _settings.chineseSemester,
        chineseScopeMode: chineseScopeMode ?? _settings.chineseScopeMode,
        chineseMaxUnitOrder:
            chineseMaxUnitOrder ?? _settings.chineseMaxUnitOrder,
        chineseTargetUnitOrder:
            chineseTargetUnitOrder ?? _settings.chineseTargetUnitOrder,
        questionSource: questionSource ?? _settings.questionSource,
      );
}

class _SettingCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _GradeSelector extends StatelessWidget {
  final int selectedGrade;
  final void Function(int) onChanged;

  const _GradeSelector({
    required this.selectedGrade,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: List.generate(6, (i) {
        final grade = i + 1;
        final isSelected = grade == selectedGrade;
        return FilterChip(
          label: Text('$grade 年級'),
          selected: isSelected,
          onSelected: (_) => onChanged(grade),
          selectedColor: const Color(0xFF4CAF50),
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : null,
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }),
    );
  }
}

class _SemesterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SemesterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4CAF50) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF4CAF50)
                : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey[700],
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SourceOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F5E9) : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF4CAF50)
                : Colors.grey[200]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF4CAF50) : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? const Color(0xFF2E7D32)
                          : Colors.black87,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4CAF50),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
