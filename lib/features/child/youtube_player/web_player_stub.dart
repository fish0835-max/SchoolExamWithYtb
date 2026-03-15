// Stub for non-web platforms — never actually executed (kIsWeb guards all usage)
import 'package:flutter/material.dart';

class WebYoutubeController {
  void hideForOverlay() {}
  void showAndPlay() {}
  void pauseVideo() {}
  void playVideo() {}
  void loadVideo(String videoId) {}
  void dispose() {}
}

class WebYoutubePlayer extends StatelessWidget {
  final String videoId;
  final WebYoutubeController controller;

  const WebYoutubePlayer({
    super.key,
    required this.videoId,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
