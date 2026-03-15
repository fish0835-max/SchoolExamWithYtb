// Web stub for youtube_player_flutter
import 'package:flutter/material.dart';

class YoutubePlayerController {
  YoutubePlayerController({required String initialVideoId, dynamic flags});
  void pause() {}
  void play() {}
  void load(String videoId) {}
  void dispose() {}
}

class YoutubePlayerFlags {
  const YoutubePlayerFlags({
    bool autoPlay = true,
    bool mute = false,
    bool enableCaption = true,
    bool forceHD = false,
  });
}

class YoutubePlayer extends StatelessWidget {
  const YoutubePlayer({
    super.key,
    required YoutubePlayerController controller,
    bool showVideoProgressIndicator = false,
    dynamic progressColors,
  });
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class ProgressBarColors {
  const ProgressBarColors({Color? playedColor, Color? handleColor});
}

class YoutubePlayerBuilder extends StatelessWidget {
  final YoutubePlayer player;
  final Widget Function(BuildContext, Widget) builder;
  const YoutubePlayerBuilder({super.key, required this.player, required this.builder});
  @override
  Widget build(BuildContext context) => builder(context, player);
}
