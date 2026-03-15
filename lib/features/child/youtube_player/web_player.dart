// Web-only YouTube player using HtmlElementView + YouTube iframe postMessage API
// Only compiled when dart.library.html is available (i.e., Flutter Web)
import 'dart:async';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

import 'package:flutter/material.dart';

/// Controls the YouTube iframe via postMessage (works with ?enablejsapi=1).
/// Also manages iframe visibility so that Flutter overlays can receive taps.
class WebYoutubeController {
  html.IFrameElement? _iframe;

  // Track desired visibility so we can apply it as soon as the iframe is created
  bool _visible = false; // start hidden — quiz is shown before any video

  void _setIframe(html.IFrameElement el) {
    _iframe = el;
    _applyVisibility();
  }

  void _applyVisibility() {
    if (_iframe == null) return;
    if (_visible) {
      _iframe!.style.visibility = 'visible';
      _iframe!.style.pointerEvents = 'auto';
    } else {
      // Hide iframe AND pass pointer events through to Flutter's canvas
      _iframe!.style.visibility = 'hidden';
      _iframe!.style.pointerEvents = 'none';
    }
  }

  /// Call when showing the quiz overlay:
  /// hides the iframe and lets Flutter widgets receive taps.
  void hideForOverlay() {
    _visible = false;
    _applyVisibility();
  }

  /// Call when dismissing the quiz overlay:
  /// shows the iframe and resumes playback.
  void showAndPlay() {
    _visible = true;
    _applyVisibility();
    // Brief delay — gives the player time to respond after being un-hidden
    Future.delayed(const Duration(milliseconds: 300), playVideo);
  }

  void pauseVideo() {
    _iframe?.contentWindow?.postMessage(
      '{"event":"command","func":"pauseVideo","args":""}',
      'https://www.youtube.com',
    );
  }

  void playVideo() {
    _iframe?.contentWindow?.postMessage(
      '{"event":"command","func":"playVideo","args":""}',
      'https://www.youtube.com',
    );
  }

  /// Load a different video without recreating the iframe.
  void loadVideo(String videoId) {
    _iframe?.contentWindow?.postMessage(
      '{"event":"command","func":"loadVideoById","args":["$videoId",0]}',
      'https://www.youtube.com',
    );
  }

  void dispose() {
    _iframe = null;
  }
}

/// Renders a YouTube video via HtmlElementView on web.
class WebYoutubePlayer extends StatefulWidget {
  final String videoId;
  final WebYoutubeController controller;

  const WebYoutubePlayer({
    super.key,
    required this.videoId,
    required this.controller,
  });

  @override
  State<WebYoutubePlayer> createState() => _WebYoutubePlayerState();
}

class _WebYoutubePlayerState extends State<WebYoutubePlayer> {
  static int _seq = 0;
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'yt-player-${widget.videoId}-${++_seq}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        // autoplay=0: don't play until quiz is answered
        ..src =
            'https://www.youtube.com/embed/${widget.videoId}?autoplay=0&enablejsapi=1&rel=0'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'autoplay; encrypted-media; fullscreen'
        // sandbox: block new-window/tab opening while keeping playback working
        ..setAttribute(
          'sandbox',
          'allow-scripts allow-same-origin allow-forms allow-presentation',
        );
      widget.controller._setIframe(iframe);
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
