// Copyright 2022 Sarbagya Dhaubanjar. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library youtube_player_iframe_web;

import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

// FIX: use dart:ui_web instead of dart:ui — platformViewRegistry was moved in Flutter 3.19+
import 'platform_view_stub.dart' if (dart.library.html) 'dart:ui_web' as ui;

/// Builds an iframe based WebView.
///
/// This is used as the default implementation for [WebView.platform] on web.
class YoutubePlayerIframeWeb implements WebViewPlatform {
  /// Constructs a new instance of [YoutubePlayerIframeWeb].
  YoutubePlayerIframeWeb() {
    ui.platformViewRegistry.registerViewFactory(
      'youtube-iframe',
      (int viewId) => IFrameElement()
        ..id = 'youtube-$viewId'
        ..style.border = 'none'
        ..style.height = '100%'
        ..style.width = '100%'
        ..allow = 'autoplay;fullscreen',
    );
  }

  @override
  Widget build({
    required BuildContext context,
    required CreationParams creationParams,
    required WebViewPlatformCallbacksHandler webViewPlatformCallbacksHandler,
    required JavascriptChannelRegistry? javascriptChannelRegistry,
    WebViewPlatformCreatedCallback? onWebViewPlatformCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  }) {
    return HtmlElementView(
      viewType: 'youtube-iframe',
      onPlatformViewCreated: (int viewId) {
        if (onWebViewPlatformCreated == null) return;

        final element = document.getElementById(
          'youtube-$viewId',
        )! as IFrameElement;

        if (creationParams.initialUrl != null) {
          // ignore: unsafe_html
          element.src = creationParams.initialUrl;
        }
        onWebViewPlatformCreated(WebWebViewPlatformController(element));

        window.onMessage.listen(
          (event) {
            javascriptChannelRegistry?.onJavascriptChannelMessage(
              'YoutubePlayer',
              event.data,
            );
          },
        );
      },
    );
  }

  @override
  Future<bool> clearCookies() async => false;

  /// Gets called when the plugin is registered.
  static void registerWith(Registrar registrar) {}
}

/// Implementation of [WebViewPlatformController] for web.
class WebWebViewPlatformController implements WebViewPlatformController {
  /// Constructs a [WebWebViewPlatformController].
  WebWebViewPlatformController(this._element);

  final IFrameElement _element;
  HttpRequestFactory _httpRequestFactory = HttpRequestFactory();

  /// Setter for setting the HttpRequestFactory, for testing purposes.
  @visibleForTesting
  // ignore: avoid_setters_without_getters
  set httpRequestFactory(HttpRequestFactory factory) {
    _httpRequestFactory = factory;
  }

  @override
  Future<void> addJavascriptChannels(Set<String> javascriptChannelNames) {
    throw UnimplementedError();
  }

  @override
  Future<bool> canGoBack() {
    throw UnimplementedError();
  }

  @override
  Future<bool> canGoForward() {
    throw UnimplementedError();
  }

  @override
  Future<void> clearCache() {
    throw UnimplementedError();
  }

  @override
  Future<String?> currentUrl() {
    throw UnimplementedError();
  }

  @override
  Future<String> evaluateJavascript(String javascript) {
    throw UnimplementedError();
  }

  @override
  Future<int> getScrollX() {
    throw UnimplementedError();
  }

  @override
  Future<int> getScrollY() {
    throw UnimplementedError();
  }

  @override
  Future<String?> getTitle() {
    throw UnimplementedError();
  }

  @override
  Future<void> goBack() {
    throw UnimplementedError();
  }

  @override
  Future<void> goForward() {
    throw UnimplementedError();
  }

  @override
  Future<void> loadUrl(String url, Map<String, String>? headers) async {
    // ignore: unsafe_html
    _element.src = url;
  }

  @override
  Future<void> reload() {
    throw UnimplementedError();
  }

  @override
  Future<void> removeJavascriptChannels(Set<String> javascriptChannelNames) {
    throw UnimplementedError();
  }

  @override
  Future<void> runJavascript(String javascript) async {
    final function = javascript.replaceAll('"', '<<quote>>');
    _element.contentWindow?.postMessage(
      '{"key": null, "function": "$function"}',
      '*',
    );
  }

  @override
  Future<String> runJavascriptReturningResult(String javascript) async {
    final contentWindow = _element.contentWindow;
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    final function = javascript.replaceAll('"', '<<quote>>');

    final completer = Completer<String>();
    final subscription = window.onMessage.listen(
      (event) {
        final data = jsonDecode(event.data);

        if (data is Map && data.containsKey(key)) {
          completer.complete(data[key].toString());
        }
      },
    );

    contentWindow?.postMessage(
      '{"key": "$key", "function": "$function"}',
      '*',
    );

    final result = await completer.future;
    subscription.cancel();

    return result;
  }

  @override
  Future<void> scrollBy(int x, int y) {
    throw UnimplementedError();
  }

  @override
  Future<void> scrollTo(int x, int y) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateSettings(WebSettings setting) async {}

  @override
  Future<void> loadFile(String absoluteFilePath) {
    throw UnimplementedError();
  }

  @override
  Future<void> loadHtmlString(
    String html, {
    String? baseUrl,
  }) async {
    // ignore: unsafe_html
    _element.src = 'data:text/html,${Uri.encodeFull(html)}';
  }

  @override
  Future<void> loadRequest(WebViewRequest request) async {
    if (!request.uri.hasScheme) {
      throw ArgumentError('WebViewRequest#uri is required to have a scheme.');
    }
    final httpReq = await _httpRequestFactory.request(request.uri.toString(),
        method: request.method.serialize(),
        requestHeaders: request.headers,
        sendData: request.body);
    final contentType =
        httpReq.getResponseHeader('content-type') ?? 'text/html';
    // ignore: unsafe_html
    _element.src =
        'data:$contentType,${Uri.encodeFull(httpReq.responseText ?? '')}';
  }

  @override
  Future<void> loadFlutterAsset(String key) {
    throw UnimplementedError();
  }
}

/// Factory class for creating [HttpRequest] instances.
class HttpRequestFactory {
  Future<HttpRequest> request(
    String url, {
    String? method,
    bool? withCredentials,
    String? responseType,
    String? mimeType,
    Map<String, String>? requestHeaders,
    dynamic sendData,
    void Function(ProgressEvent e)? onProgress,
  }) {
    return HttpRequest.request(
      url,
      method: method,
      withCredentials: withCredentials,
      responseType: responseType,
      mimeType: mimeType,
      requestHeaders: requestHeaders,
      sendData: sendData,
      onProgress: onProgress,
    );
  }
}
