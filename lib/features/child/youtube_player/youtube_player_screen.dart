import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

// Native player (Android / iOS / Windows / macOS)
import 'package:youtube_player_flutter/youtube_player_flutter.dart'
    if (dart.library.html) '../../../core/services/stub/youtube_player_stub.dart';

// Web player (browser — HtmlElementView + iframe postMessage)
import 'web_player_stub.dart'
    if (dart.library.html) 'web_player.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/timer_service.dart';
import '../quiz_overlay/quiz_overlay.dart';

// ── Search result model ────────────────────────────────────────────────────

class _SearchResult {
  final String videoId;
  final String title;
  final String thumbnail;
  final String channel;

  const _SearchResult({
    required this.videoId,
    required this.title,
    required this.thumbnail,
    required this.channel,
  });
}

// ── Screen ─────────────────────────────────────────────────────────────────

class YoutubePlayerScreen extends ConsumerStatefulWidget {
  final String videoId;

  const YoutubePlayerScreen({super.key, required this.videoId});

  @override
  ConsumerState<YoutubePlayerScreen> createState() =>
      _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends ConsumerState<YoutubePlayerScreen> {
  YoutubePlayerController? _nativeController;
  final WebYoutubeController _webController = WebYoutubeController();

  bool _showOverlay = true;
  bool _showSearchBar = false;
  bool _isSearching = false;
  List<_SearchResult> _searchResults = [];

  int _youtubeDurationSeconds = AppConfig.debugDurationSeconds ??
      (AppConfig.defaultYoutubeMinutes * 60);

  String get _videoId =>
      widget.videoId.isEmpty ? 'dQw4w9WgXcQ' : widget.videoId;

  // ── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _webController.hideForOverlay();
    } else {
      _nativeController = YoutubePlayerController(
        initialVideoId: _videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: false,
          forceHD: false,
        ),
      );
    }
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await ref.read(settingsServiceProvider).getSettings();
    if (!mounted) return;
    setState(() {
      _youtubeDurationSeconds = AppConfig.debugDurationSeconds ??
          (settings.youtubeSessionMinutes * 60);
    });
  }

  // ── Timer / overlay ───────────────────────────────────────────────────────

  void _onTimerExpired() {
    if (kIsWeb) {
      _webController.pauseVideo();
      _webController.hideForOverlay();
    } else {
      _nativeController?.pause();
    }
    setState(() {
      _showOverlay = true;
      _showSearchBar = false;
      _searchResults = [];
    });
  }

  void _onQuizComplete() {
    setState(() => _showOverlay = false);
    final timer = ref.read(timerProvider.notifier);
    timer.setup(_youtubeDurationSeconds, onExpired: _onTimerExpired);
    timer.start();
    if (kIsWeb) {
      _webController.showAndPlay();
    } else {
      _nativeController?.play();
    }
  }

  // ── Video switching ───────────────────────────────────────────────────────

  void _switchVideo(String videoId) {
    if (kIsWeb) {
      _webController.loadVideo(videoId);
    } else {
      _nativeController?.load(videoId);
    }
    setState(() {
      _showSearchBar = false;
      _searchResults = [];
    });
  }

  // ── YouTube search ────────────────────────────────────────────────────────

  static String? _extractVideoId(String input) {
    final trimmed = input.trim();
    final regex = RegExp(
      r'(?:youtube\.com/watch\?(?:[^#&]*&)?v=|youtu\.be/)([a-zA-Z0-9_-]{11})',
    );
    final match = regex.firstMatch(trimmed);
    if (match != null) return match.group(1);
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) return trimmed;
    return null;
  }

  Future<void> _onSearchSubmit(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    // Direct URL / video ID → play immediately
    final videoId = _extractVideoId(trimmed);
    if (videoId != null) {
      _switchVideo(videoId);
      return;
    }

    // Keyword search via YouTube Data API
    final apiKey = AppConfig.youtubeApiKey;
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請在 assets/.env 填入 YOUTUBE_API_KEY 才能使用關鍵字搜尋'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final uri = Uri.parse(
        'https://www.googleapis.com/youtube/v3/search'
        '?part=snippet'
        '&q=${Uri.encodeComponent(trimmed)}'
        '&type=video'
        '&maxResults=8'
        '&key=$apiKey',
      );
      final response = await http.get(uri);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>;
        setState(() {
          _searchResults = items.map((item) {
            final snippet = item['snippet'] as Map<String, dynamic>;
            final thumbnails =
                snippet['thumbnails'] as Map<String, dynamic>;
            final thumb = (thumbnails['medium'] ?? thumbnails['default'])
                as Map<String, dynamic>;
            return _SearchResult(
              videoId: (item['id'] as Map<String, dynamic>)['videoId']
                  as String,
              title: snippet['title'] as String,
              thumbnail: thumb['url'] as String,
              channel: snippet['channelTitle'] as String,
            );
          }).toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜尋失敗（${response.statusCode}）')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('搜尋時發生錯誤，請確認網路連線')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _nativeController?.dispose();
    _webController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  Widget _buildVideoPlayer() {
    if (kIsWeb) {
      return WebYoutubePlayer(videoId: _videoId, controller: _webController);
    }
    return YoutubePlayer(
      controller: _nativeController!,
      showVideoProgressIndicator: true,
      progressColors: const ProgressBarColors(
        playedColor: Color(0xFF4CAF50),
        handleColor: Color(0xFF2E7D32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerProvider);
    final showResults = _searchResults.isNotEmpty || _isSearching;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              // ── Top bar ──────────────────────────────────────────────────
              SafeArea(
                bottom: false,
                child: Container(
                  color: Colors.black,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.white),
                      ),
                      const Spacer(),
                      if (!_showOverlay)
                        IconButton(
                          onPressed: () => setState(() {
                            _showSearchBar = !_showSearchBar;
                            if (!_showSearchBar) _searchResults = [];
                          }),
                          icon: Icon(
                            _showSearchBar ? Icons.search_off : Icons.search,
                            color: Colors.white70,
                          ),
                        ),
                      // Timer pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: timerState.remainingSeconds < 30
                              ? Colors.red.withOpacity(0.85)
                              : Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              timerState.formattedTime,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),

              // ── Search bar (collapsible) ──────────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _showSearchBar && !_showOverlay
                    ? _SearchBar(
                        isSearching: _isSearching,
                        onSubmit: _onSearchSubmit,
                      )
                    : const SizedBox.shrink(),
              ),

              // ── Search results OR video player ────────────────────────
              Expanded(
                child: showResults && _showSearchBar
                    ? _SearchResultsList(
                        results: _searchResults,
                        isLoading: _isSearching,
                        onSelect: (videoId) => _switchVideo(videoId),
                      )
                    : _buildVideoPlayer(),
              ),
            ],
          ),

          // Timer progress bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: LinearProgressIndicator(
                value: timerState.progress,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(
                  timerState.remainingSeconds < 30
                      ? Colors.red
                      : const Color(0xFF4CAF50),
                ),
                minHeight: 3,
              ),
            ),
          ),

          // Quiz overlay
          if (_showOverlay) QuizOverlay(onComplete: _onQuizComplete),
        ],
      ),
    );
  }
}

// ── Search bar widget ──────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  final bool isSearching;
  final Future<void> Function(String) onSubmit;

  const _SearchBar({required this.isSearching, required this.onSubmit});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white54, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: '搜尋影片或貼上 YouTube 網址',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (v) {
                if (v.isNotEmpty) widget.onSubmit(v);
              },
            ),
          ),
          if (widget.isSearching)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF4CAF50),
              ),
            )
          else
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.send, color: Color(0xFF4CAF50), size: 20),
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  widget.onSubmit(_controller.text);
                }
              },
            ),
        ],
      ),
    );
  }
}

// ── Search results list ────────────────────────────────────────────────────

class _SearchResultsList extends StatelessWidget {
  final List<_SearchResult> results;
  final bool isLoading;
  final void Function(String videoId) onSelect;

  const _SearchResultsList({
    required this.results,
    required this.isLoading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      );
    }
    if (results.isEmpty) {
      return const Center(
        child: Text('沒有結果', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final r = results[i];
        return InkWell(
          onTap: () => onSelect(r.videoId),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    r.thumbnail,
                    width: 100,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 100,
                      height: 56,
                      color: Colors.white12,
                      child: const Icon(Icons.play_circle,
                          color: Colors.white38),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Title + channel
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.channel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.play_arrow,
                    color: Color(0xFF4CAF50), size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
