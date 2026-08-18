import 'dart:async';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/services/youtube/youtube_service.dart';

const _youtubeHomeUrl = 'https://m.youtube.com/';
const _youtubeBridgeName = 'openYouTubeVideo';
const _desktopPlayScheme = 'mangatan-youtube';
const _playerLaunchDebounce = Duration(milliseconds: 1500);

String? directYouTubeVideoId(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null) return null;
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();

  String? videoId;
  if (host == 'youtu.be') {
    videoId = segments.firstOrNull;
  } else if (_isYouTubeHost(host)) {
    videoId = switch (segments.firstOrNull) {
      'watch' => uri.queryParameters['v'],
      'shorts' || 'live' || 'embed' || 'v' => segments.elementAtOrNull(1),
      _ => null,
    };
  }
  return _isYouTubeVideoId(videoId) ? videoId : null;
}

bool _isYouTubeHost(String host) =>
    host == 'youtube.com' ||
    host.endsWith('.youtube.com') ||
    host == 'youtube-nocookie.com' ||
    host.endsWith('.youtube-nocookie.com');

bool _isYouTubeVideoId(String? value) =>
    value != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(value);

String? _desktopBridgeVideoUrl(String input) {
  final uri = Uri.tryParse(input);
  if (uri?.scheme != _desktopPlayScheme || uri?.host != 'play') return null;
  final url = uri!.queryParameters['url'];
  return directYouTubeVideoId(url ?? '') == null ? null : url;
}

const youtubeInterceptScript = r'''
(function() {
  if (window.__mangatanYoutubeBridgeInstalled) return;
  window.__mangatanYoutubeBridgeInstalled = true;

  function playableUrl(rawUrl) {
    try {
      var url = new URL(rawUrl, window.location.href);
      var host = url.hostname.toLowerCase().replace(/^www\./, '');
      var path = url.pathname || '';
      var youtubeHost = host === 'youtube.com' ||
          host.endsWith('.youtube.com') ||
          host === 'youtube-nocookie.com' ||
          host.endsWith('.youtube-nocookie.com');
      return (
        (host === 'youtu.be' && /^\/[a-zA-Z0-9_-]{11}\/?$/.test(path)) ||
        (youtubeHost &&
          ((path === '/watch' &&
              /^[a-zA-Z0-9_-]{11}$/.test(url.searchParams.get('v') || '')) ||
           /^\/(?:shorts|live|embed|v)\/[a-zA-Z0-9_-]{11}\/?$/.test(path)))
      );
    } catch (_) {
      return false;
    }
  }

  function openInMangatan(rawUrl) {
    if (!playableUrl(rawUrl)) return false;
    var href = new URL(rawUrl, window.location.href).href;
    var bridge = window.flutter_inappwebview;
    if (!bridge || !bridge.callHandler) {
      window.location.assign(href);
      return true;
    }

    var acknowledged = false;
    var fallback = function() {
      if (acknowledged) return;
      acknowledged = true;
      window.location.assign(href);
    };
    var fallbackTimer = setTimeout(fallback, 350);
    Promise.resolve(bridge.callHandler('openYouTubeVideo', href)).then(
      function(result) {
        if (result === true) {
          acknowledged = true;
          clearTimeout(fallbackTimer);
        } else {
          fallback();
        }
      },
      fallback
    );
    return true;
  }

  document.addEventListener('click', function(event) {
    var link = event.target && event.target.closest
        ? event.target.closest('a')
        : null;
    if (link && link.href && openInMangatan(link.href)) {
      event.preventDefault();
      event.stopPropagation();
      event.stopImmediatePropagation();
    }
  }, true);

  var pushState = history.pushState;
  history.pushState = function() {
    var result = pushState.apply(this, arguments);
    setTimeout(function() { openInMangatan(window.location.href); }, 0);
    return result;
  };
  var replaceState = history.replaceState;
  history.replaceState = function() {
    var result = replaceState.apply(this, arguments);
    setTimeout(function() { openInMangatan(window.location.href); }, 0);
    return result;
  };
  window.addEventListener('popstate', function() {
    setTimeout(function() { openInMangatan(window.location.href); }, 0);
  });
  openInMangatan(window.location.href);
})();
''';

const _stopYouTubePlaybackScript = r'''
(function() {
  document.querySelectorAll('video, audio').forEach(function(media) {
    try {
      media.pause();
      media.removeAttribute('src');
      media.load();
    } catch (_) {}
  });
})();
''';

class YouTubeBrowserScreen extends StatefulWidget {
  const YouTubeBrowserScreen({super.key});

  @override
  State<YouTubeBrowserScreen> createState() => _YouTubeBrowserScreenState();
}

class _YouTubeBrowserScreenState extends State<YouTubeBrowserScreen> {
  final _youtube = YouTubeService();
  InAppWebViewController? _controller;
  _YouTubeInAppBrowser? _browser;
  Webview? _desktopWebview;
  double _progress = 0;
  String _title = 'YouTube';
  bool _openingVideo = false;
  bool _externalWindowClosed = false;
  bool _disposing = false;
  String? _lastVideoId;
  String? _sitePlaybackVideoId;
  DateTime? _lastLaunchAt;

  bool get _usesDesktopWindow => Platform.isLinux || Platform.isWindows;

  @override
  void initState() {
    super.initState();
    if (_usesDesktopWindow) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDesktop());
    }
  }

  @override
  void dispose() {
    _disposing = true;
    _youtube.close();
    _browser?.close();
    if (!_externalWindowClosed) _desktopWebview?.close();
    super.dispose();
  }

  Future<void> _openDesktop() async {
    if (!mounted) return;
    if (Platform.isLinux) {
      final view = await WebviewWindow.create(
        configuration: const CreateConfiguration(
          title: 'Mangatan - YouTube',
          openMaximized: true,
        ),
      );
      if (!mounted) {
        view.close();
        return;
      }
      _desktopWebview = view;
      view
        ..addScriptToExecuteOnDocumentCreated(youtubeInterceptScript)
        ..setOnUrlRequestCallback((url) {
          final bridgedUrl = _desktopBridgeVideoUrl(url);
          final playableUrl = bridgedUrl ?? url;
          final videoId = directYouTubeVideoId(playableUrl);
          if (videoId == _sitePlaybackVideoId) return true;
          if (videoId != null) {
            unawaited(_openVideo(playableUrl));
            return false;
          }
          return true;
        })
        ..launch(_youtubeHomeUrl);
      view.onClose.whenComplete(() {
        _externalWindowClosed = true;
        if (mounted && !_disposing && !_openingVideo) context.pop();
      });
      return;
    }

    final browser = _YouTubeInAppBrowser(
      onCreated: (controller) {
        _controller = controller;
        _installBridge(controller);
      },
      onNavigate: _handleNavigation,
      onProgress: _updateProgress,
      onTitle: _updateTitle,
      onClosed: () {
        _externalWindowClosed = true;
        if (mounted && !_disposing && !_openingVideo) context.pop();
      },
    );
    _browser = browser;
    await browser.openUrlRequest(
      urlRequest: URLRequest(url: WebUri(_youtubeHomeUrl)),
      settings: InAppBrowserClassSettings(
        browserSettings: InAppBrowserSettings(
          hideUrlBar: false,
          hideToolbarTop: false,
        ),
        webViewSettings: InAppWebViewSettings(
          isInspectable: kDebugMode,
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          useShouldOverrideUrlLoading: true,
          supportMultipleWindows: false,
          thirdPartyCookiesEnabled: true,
          sharedCookiesEnabled: true,
        ),
      ),
    );
  }

  void _installBridge(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: _youtubeBridgeName,
      callback: (JavaScriptHandlerFunctionData data) {
        final url = data.args.firstOrNull?.toString();
        if (url == null) return false;
        final videoId = directYouTubeVideoId(url);
        if (videoId == null) return false;
        if (videoId == _sitePlaybackVideoId) return true;
        unawaited(_openVideo(url));
        return true;
      },
    );
  }

  Future<NavigationActionPolicy> _handleNavigation(String? url) async {
    if (url == null) return NavigationActionPolicy.ALLOW;
    final bridgedUrl = _desktopBridgeVideoUrl(url);
    final playableUrl = bridgedUrl ?? url;
    final videoId = directYouTubeVideoId(playableUrl);
    if (videoId == _sitePlaybackVideoId) {
      return NavigationActionPolicy.ALLOW;
    }
    if (videoId != null) {
      unawaited(_openVideo(playableUrl));
      return NavigationActionPolicy.CANCEL;
    }
    final scheme = Uri.tryParse(url)?.scheme;
    return const {
          'http',
          'https',
          'about',
          'data',
          'javascript',
        }.contains(scheme)
        ? NavigationActionPolicy.ALLOW
        : NavigationActionPolicy.CANCEL;
  }

  void _updateProgress(int progress) {
    if (!mounted) return;
    setState(() => _progress = progress / 100);
    if (progress >= 25) unawaited(_injectInterception());
  }

  void _updateTitle(String? title) {
    if (!mounted || title == null || title.isEmpty) return;
    setState(() => _title = title);
  }

  Future<void> _injectInterception() async {
    try {
      await _controller?.evaluateJavascript(source: youtubeInterceptScript);
    } catch (_) {}
  }

  Future<void> _openVideo(String url) async {
    final videoId = directYouTubeVideoId(url);
    if (videoId == null || _openingVideo) return;
    if (videoId == _sitePlaybackVideoId) return;
    final now = DateTime.now();
    if (_lastVideoId == videoId &&
        _lastLaunchAt != null &&
        now.difference(_lastLaunchAt!) < _playerLaunchDebounce) {
      return;
    }
    _lastVideoId = videoId;
    _lastLaunchAt = now;
    _openingVideo = true;
    Object? extractionError;

    try {
      await _desktopWebview?.stop();
      await _controller?.stopLoading();
      await _desktopWebview?.evaluateJavaScript(_stopYouTubePlaybackScript);
      await _controller?.evaluateJavascript(source: _stopYouTubePlaybackScript);
      if (Platform.isLinux) {
        await _desktopWebview?.setWebviewWindowVisibility(false);
      } else if (Platform.isWindows) {
        await _browser?.hide();
      }
      final chapterId = await _youtube.prepareVideoUrlForPlayback(url);
      if (!mounted) return;
      await context.push('/animePlayerView', extra: chapterId);
    } catch (error) {
      extractionError = error;
      _sitePlaybackVideoId = videoId;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_friendlyError(error)} Opening it on YouTube instead.',
            ),
          ),
        );
      }
    } finally {
      _openingVideo = false;
      if (Platform.isLinux && !_externalWindowClosed) {
        await _desktopWebview?.setWebviewWindowVisibility(true);
        await _desktopWebview?.bringToForeground();
      } else if (Platform.isWindows && !_externalWindowClosed) {
        await _browser?.show();
      }
      if (extractionError != null && !_externalWindowClosed) {
        if (Platform.isLinux) {
          _desktopWebview?.launch(url);
        } else {
          await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
        }
      }
      if (_externalWindowClosed && mounted && !_disposing) {
        context.pop();
      }
    }
  }

  Future<void> _goBack() async {
    if (await _controller?.canGoBack() == true) {
      await _controller?.goBack();
    } else if (mounted) {
      context.pop();
    }
  }

  Future<void> _showSettings() async {
    var quality = await YouTubePreferences.preferredQuality();
    var autoAdd = await YouTubePreferences.autoAddChannels();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('YouTube settings'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: quality,
                  decoration: const InputDecoration(
                    labelText: 'Preferred video quality',
                  ),
                  items: [
                    for (final value in youtubePreferredQualities)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => quality = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Add opened channels to the library'),
                  value: autoAdd,
                  onChanged: (value) => setDialogState(() => autoAdd = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await YouTubePreferences.setPreferredQuality(quality);
                await YouTubePreferences.setAutoAddChannels(autoAdd);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_usesDesktopWindow) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('YouTube'),
          actions: [
            IconButton(
              tooltip: 'YouTube settings',
              onPressed: _showSettings,
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
        ),
        body: const Center(
          child: Text('YouTube is open in its browser window.'),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_goBack());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title, overflow: TextOverflow.ellipsis),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          actions: [
            IconButton(
              tooltip: 'YouTube settings',
              onPressed: _showSettings,
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
          bottom: _progress < 1
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress),
                )
              : null,
        ),
        body: InAppWebView(
          webViewEnvironment: webViewEnvironment,
          initialUrlRequest: URLRequest(url: WebUri(_youtubeHomeUrl)),
          initialSettings: InAppWebViewSettings(
            isInspectable: kDebugMode,
            javaScriptEnabled: true,
            domStorageEnabled: true,
            databaseEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
            useShouldOverrideUrlLoading: true,
            supportMultipleWindows: false,
            thirdPartyCookiesEnabled: true,
            sharedCookiesEnabled: true,
          ),
          onWebViewCreated: (controller) {
            _controller = controller;
            _installBridge(controller);
          },
          shouldOverrideUrlLoading: (_, action) {
            if (action.isForMainFrame == false) {
              return Future.value(NavigationActionPolicy.ALLOW);
            }
            return _handleNavigation(action.request.url?.toString());
          },
          onLoadStart: (_, url) async {
            final value = url?.toString();
            final videoId = directYouTubeVideoId(value ?? '');
            if (videoId != null && videoId != _sitePlaybackVideoId) {
              unawaited(_openVideo(value!));
            }
          },
          onLoadStop: (controller, url) async {
            _updateProgress(100);
            _updateTitle(await controller.getTitle());
            await _injectInterception();
            final value = url?.toString();
            final videoId = directYouTubeVideoId(value ?? '');
            if (videoId != null && videoId != _sitePlaybackVideoId) {
              unawaited(_openVideo(value!));
            }
          },
          onProgressChanged: (_, progress) => _updateProgress(progress),
          onTitleChanged: (_, title) => _updateTitle(title),
          onUpdateVisitedHistory: (_, url, _) async {
            await _injectInterception();
            final value = url?.toString();
            final videoId = directYouTubeVideoId(value ?? '');
            if (videoId != null && videoId != _sitePlaybackVideoId) {
              unawaited(_openVideo(value!));
            }
          },
        ),
      ),
    );
  }

  static String _friendlyError(Object error) {
    final text = error.toString().replaceFirst(RegExp(r'^Exception: '), '');
    if (text.contains('VideoUnplayableException')) {
      return 'This video is unavailable or cannot be played in your region.';
    }
    return 'YouTube could not open this video. $text';
  }
}

class _YouTubeInAppBrowser extends InAppBrowser {
  _YouTubeInAppBrowser({
    required this.onCreated,
    required this.onNavigate,
    required this.onProgress,
    required this.onTitle,
    required this.onClosed,
  }) : super(webViewEnvironment: webViewEnvironment);

  final void Function(InAppWebViewController) onCreated;
  final Future<NavigationActionPolicy> Function(String? url) onNavigate;
  final void Function(int progress) onProgress;
  final void Function(String? title) onTitle;
  final VoidCallback onClosed;

  @override
  Future<void> onBrowserCreated() async {
    onCreated(webViewController!);
  }

  @override
  Future<NavigationActionPolicy> shouldOverrideUrlLoading(
    NavigationAction navigationAction,
  ) => onNavigate(navigationAction.request.url?.toString());

  @override
  void onProgressChanged(int progress) => onProgress(progress);

  @override
  void onTitleChanged(String? title) => onTitle(title);

  @override
  Future<void> onLoadStop(WebUri? url) async {
    onProgress(100);
    await webViewController?.evaluateJavascript(source: youtubeInterceptScript);
    final value = url?.toString();
    if (directYouTubeVideoId(value ?? '') != null) {
      await onNavigate(value);
    }
  }

  @override
  void onUpdateVisitedHistory(WebUri? url, bool? isReload) {
    webViewController?.evaluateJavascript(source: youtubeInterceptScript);
    final value = url?.toString();
    if (directYouTubeVideoId(value ?? '') != null) {
      unawaited(onNavigate(value));
    }
  }

  @override
  void onExit() => onClosed();
}
