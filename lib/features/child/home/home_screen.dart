import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/auth_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _urlController = TextEditingController();
  List<_VideoItem> _recentVideos = [];


  @override
  void initState() {
    super.initState();
    _loadRecentVideos();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('recent_videos') ?? '[]';
    final list = jsonDecode(jsonStr) as List;
    if (mounted) {
      setState(() {
        _recentVideos = list
            .map((e) => _VideoItem.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    }
  }

  Future<void> _saveRecentVideo(_VideoItem video) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = [
      video,
      ..._recentVideos.where((v) => v.videoId != video.videoId),
    ].take(5).toList();
    await prefs.setString(
      'recent_videos',
      jsonEncode(updated.map((v) => v.toJson()).toList()),
    );
    if (mounted) setState(() => _recentVideos = updated);
  }

  String? _extractVideoId(String input) {
    final trimmed = input.trim();
    // Full URL: youtube.com/watch?v=ID or youtu.be/ID
    final regex = RegExp(
      r'(?:youtube\.com/watch\?(?:[^#&]*&)?v=|youtu\.be/)([a-zA-Z0-9_-]{11})',
    );
    final match = regex.firstMatch(trimmed);
    if (match != null) return match.group(1);
    // Direct 11-char ID
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) return trimmed;
    return null;
  }

  void _openVideo(_VideoItem video) {
    _saveRecentVideo(video);
    context.push('/child/player?videoId=${video.videoId}');
  }

  void _tryOpenUrl() {
    final videoId = _extractVideoId(_urlController.text);
    if (videoId != null) {
      _urlController.clear();
      _openVideo(_VideoItem(videoId: videoId, title: 'YouTube 影片', emoji: '▶️'));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請貼上有效的 YouTube 影片網址'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(activeChildProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0FFF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        title: Text(
          child != null
              ? '${child.name} 的學習時光 ${child.avatarEmoji ?? ''}'
              : '學習時光',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        actions: [
          // Hidden parent mode button (long press)
          GestureDetector(
            onLongPress: () => context.push('/parent/pin'),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.more_vert, color: Colors.white70),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome banner + URL input
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '想看什麼卡通？',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '看完 ${_formatMinutes()} 分鐘記得回答問題喔！',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                // YouTube URL input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Icon(Icons.link, color: Color(0xFF4CAF50), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            hintText: '貼上 YouTube 影片網址',
                            hintStyle: TextStyle(
                              color: Color(0xFFAAAAAA),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          style: const TextStyle(fontSize: 14),
                          onSubmitted: (_) => _tryOpenUrl(),
                        ),
                      ),
                      // Paste button
                      IconButton(
                        icon: const Icon(Icons.content_paste,
                            color: Color(0xFF888888), size: 20),
                        tooltip: '貼上',
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            _urlController.text = data!.text!;
                          }
                        },
                      ),
                      // Go button
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 22),
                          tooltip: '開始播放',
                          onPressed: _tryOpenUrl,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Recent videos section
                if (_recentVideos.isNotEmpty) ...[
                  const _SectionTitle(title: '最近觀看', icon: Icons.history),
                  const SizedBox(height: 10),
                  ..._recentVideos.map(
                    (v) => _VideoCard(
                      video: v,
                      onTap: () => _openVideo(v),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // How to find video URL hint
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline,
                              color: Color(0xFFFF8F00), size: 20),
                          SizedBox(width: 6),
                          Text(
                            '怎麼找影片網址？',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE65100),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. 在瀏覽器打開 YouTube\n'
                        '2. 找到想看的影片\n'
                        '3. 複製網址列的網址\n'
                        '4. 貼到上面的框框，按播放！',
                        style: TextStyle(
                          color: Color(0xFF5D4037),
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Switch child button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/child-select'),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('切換孩子'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4CAF50),
                  side: const BorderSide(color: Color(0xFF4CAF50)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMinutes() {
    // Default display - actual value loaded from settings in player screen
    return '30';
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4CAF50), size: 20),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  final _VideoItem video;
  final VoidCallback onTap;

  const _VideoCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  video.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                video.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.play_circle_fill,
                  color: Color(0xFF4CAF50), size: 28),
            ),
          ],
        ),
      ),
    );
  }
}


class _VideoItem {
  final String videoId;
  final String title;
  final String emoji;

  const _VideoItem({
    required this.videoId,
    required this.title,
    required this.emoji,
  });

  factory _VideoItem.fromJson(Map<String, dynamic> json) => _VideoItem(
        videoId: json['videoId'] as String,
        title: json['title'] as String,
        emoji: (json['emoji'] as String?) ?? '▶️',
      );

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'emoji': emoji,
      };
}
