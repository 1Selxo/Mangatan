import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_glossary.dart';
import 'package:mangayomi/services/hoshidicts/hoshidicts_backend.dart';
import 'package:mangayomi/services/mining/anki_audio_service.dart';
import 'package:mangayomi/services/mining/anki_card_builder.dart';
import 'package:mangayomi/services/mining/anki_connect_service.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';
import 'package:url_launcher/url_launcher.dart';

// Each result already contains every matching dictionary glossary. Keeping the
// headword count bounded avoids copying a very large nested payload through
// C++, Rust, Dart, and the WebView for every hover.
const hoshiPopupMaxResults = 3;

// Hoshidicts checks every prefix up to this length. Japanese words fit well
// within 24 characters, while an 80-character subtitle run multiplies queries.
const hoshiPopupScanLength = 24;

class HoshiDictionaryNavigationState {
  const HoshiDictionaryNavigationState({
    required this.canGoBack,
    required this.canGoForward,
  });

  static const empty = HoshiDictionaryNavigationState(
    canGoBack: false,
    canGoForward: false,
  );

  final bool canGoBack;
  final bool canGoForward;
}

class HoshiDictionaryPopupController {
  _HoshiDictionaryPopupState? _state;

  Future<void> goBack() => _state?._navigateBack() ?? Future.value();

  Future<void> goForward() => _state?._navigateForward() ?? Future.value();

  void _attach(_HoshiDictionaryPopupState state) => _state = state;

  void _detach(_HoshiDictionaryPopupState state) {
    if (identical(_state, state)) _state = null;
  }
}

class HoshiDictionaryPopup extends StatefulWidget {
  const HoshiDictionaryPopup({
    super.key,
    required this.text,
    this.miningContext,
    this.initialResults,
    this.controller,
    required this.preferences,
    required this.onMatchChanged,
    required this.onDismiss,
    this.onLoadingChanged,
    this.onLookupError,
    this.onNavigationChanged,
  });

  final String text;
  final FutureOr<MiningContext?> miningContext;
  final Future<List<HoshiLookupResult>>? initialResults;
  final HoshiDictionaryPopupController? controller;
  final DictionaryPopupPreferences preferences;
  final ValueChanged<int> onMatchChanged;
  final VoidCallback onDismiss;
  final ValueChanged<bool>? onLoadingChanged;
  final ValueChanged<Object>? onLookupError;
  final ValueChanged<HoshiDictionaryNavigationState>? onNavigationChanged;

  @override
  State<HoshiDictionaryPopup> createState() => _HoshiDictionaryPopupState();
}

class _HoshiDictionaryPopupState extends State<HoshiDictionaryPopup> {
  Future<_HoshiPopupData>? _shellFuture;
  late final Future<Map<String, String>> _stylesFuture;
  InAppWebViewController? _controller;
  List<HoshiLookupResult> _results = const [];
  List<Map<String, dynamic>> _entries = const [];
  Map<String, Map<String, String>> _dictionaryMediaData = const {};
  bool _exporting = false;
  bool _webReady = false;
  int _lookupGeneration = 0;
  int _cachedMatchNotificationGeneration = 0;
  Future<void> _javascriptQueue = Future<void>.value();
  Player? _audioPlayer;
  String? _requestedQuery;
  String? _resultQuery;
  String? _renderedQuery;
  String _emptyMessage = 'No dictionary results found.';

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    if (widget.text.trim().isNotEmpty) {
      unawaited(
        _lookupAndRender(
          widget.text,
          notifyMatch: true,
          initialResults: widget.initialResults,
        ),
      );
    }
    _stylesFuture = _loadStyles();
  }

  @override
  void didUpdateWidget(covariant HoshiDictionaryPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.text != widget.text) {
      unawaited(
        _lookupAndRender(
          widget.text,
          notifyMatch: true,
          initialResults: widget.initialResults,
        ),
      );
    } else if (oldWidget.initialResults != widget.initialResults) {
      if (_resultQuery == widget.text.trim() && _results.isNotEmpty) {
        _notifyCachedMatchAfterBuild();
      } else {
        // Retry an empty or stale result even when the spelling is unchanged
        // (for example after a failed lookup or dictionary reload).
        unawaited(
          _lookupAndRender(
            widget.text,
            notifyMatch: true,
            initialResults: widget.initialResults,
          ),
        );
      }
    } else if (oldWidget.onMatchChanged != widget.onMatchChanged &&
        _resultQuery == widget.text.trim() &&
        _renderedQuery == widget.text.trim() &&
        _results.isNotEmpty) {
      // A warm popup can be presented for the same spelling at a different
      // reader position. Replay the match only after the new frame is built.
      _notifyCachedMatchAfterBuild();
    }
  }

  void _notifyCachedMatchAfterBuild() {
    // didUpdateWidget runs while the popup subtree is building. Its listener
    // may belong to another overlay tree, so only notify once the frame ends.
    final generation = ++_cachedMatchNotificationGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _cachedMatchNotificationGeneration ||
          _resultQuery != widget.text.trim() ||
          _results.isEmpty) {
        return;
      }
      widget.onMatchChanged(_results.first.matched.length);
    });
  }

  Future<_HoshiPopupData> _loadShell({
    required ThemeData theme,
    required bool dark,
  }) async {
    final values = await Future.wait<dynamic>([
      rootBundle.loadString('assets/hoshi_popup/popup.css'),
      rootBundle.loadString('assets/hoshi_popup/popup.js'),
      rootBundle.loadString('assets/hoshi_popup/selection.js'),
      MiningPreferences.getAnkiAudioPreferences(),
      MiningPreferences.getActiveDictionaryProfile(),
    ]);
    return _HoshiPopupData(
      html: buildHoshiPopupHtml(
        popupCss: values[0] as String,
        popupJs: values[1] as String,
        selectionJs: values[2] as String,
        audioPreferences: values[3] as AnkiAudioPreferences,
        allowDuplicates:
            (values[4] as DictionaryProfile).duplicateAction == 'allow',
        preferences: widget.preferences,
        theme: theme,
        dark: dark,
      ),
    );
  }

  Future<Map<String, String>> _loadStyles() async {
    final styles = await HoshidictsLookupBackend.instance
        .getStyles()
        .catchError((_) => <HoshiDictionaryStyle>[]);
    return {for (final style in styles) style.dictName: style.styles};
  }

  void _setResults(
    List<HoshiLookupResult> results, {
    required Map<String, Map<String, String>> dictionaryMediaData,
  }) {
    _results = results;
    _entries = hoshiPopupEntries(results);
    _dictionaryMediaData = dictionaryMediaData;
  }

  Future<Map<String, Map<String, String>>> _loadPopupMedia(
    List<HoshiLookupResult> results,
  ) {
    if (_usesStableCustomSchemes) return Future.value(const {});
    return hoshiPopupMediaDataUris(
      results,
      (dictionary, path) => HoshidictsLookupBackend.instance.getMediaFile(
        dictName: dictionary,
        mediaPath: path,
      ),
      existing: _dictionaryMediaData,
    );
  }

  Future<void> _lookupAndRender(
    String text, {
    required bool notifyMatch,
    Future<List<HoshiLookupResult>>? initialResults,
  }) async {
    final generation = ++_lookupGeneration;
    _cachedMatchNotificationGeneration++;
    final query = text.trim();
    _requestedQuery = query;
    _notifyLoadingChanged(query.isNotEmpty);
    try {
      final results = query.isEmpty
          ? <HoshiLookupResult>[]
          : await (initialResults ??
                HoshidictsLookupBackend.instance.lookup(
                  query,
                  maxResults: hoshiPopupMaxResults,
                  scanLength: hoshiPopupScanLength,
                ));
      if (!mounted || generation != _lookupGeneration) return;
      final unchanged = query == _resultQuery && identical(results, _results);
      _setResults(
        results,
        dictionaryMediaData: unchanged
            ? _dictionaryMediaData
            : const <String, Map<String, String>>{},
      );
      _resultQuery = query;
      _emptyMessage = 'No dictionary results found.';
      if (!unchanged) await _replaceRender();
      if (!mounted || generation != _lookupGeneration) return;
      if (_webReady) _renderedQuery = query;
      if (notifyMatch && _webReady && results.isNotEmpty) {
        // Notify the reader only after the warm WebView has accepted the new
        // render request. A prefetched hidden render can therefore complete
        // before presentation without moving the reader highlight early.
        widget.onMatchChanged(results.first.matched.length);
      }
      if (!unchanged && !_usesStableCustomSchemes && results.isNotEmpty) {
        unawaited(_hydratePopupMedia(generation, results));
      }
    } catch (error) {
      if (!mounted || generation != _lookupGeneration) return;
      _setResults(const [], dictionaryMediaData: const {});
      _resultQuery = query;
      _emptyMessage = 'Dictionary lookup failed. Search again to retry.';
      widget.onLookupError?.call(error);
      await _replaceRender();
      if (mounted && generation == _lookupGeneration && _webReady) {
        _renderedQuery = query;
      }
    } finally {
      if (mounted && generation == _lookupGeneration) {
        _notifyLoadingChanged(false);
      }
    }
  }

  Future<void> _hydratePopupMedia(
    int generation,
    List<HoshiLookupResult> results,
  ) async {
    try {
      final dictionaryMediaData = await _loadPopupMedia(results);
      if (!mounted || generation != _lookupGeneration) return;
      _dictionaryMediaData = dictionaryMediaData;
      await _replaceRender();
    } catch (_) {
      // The text definitions are already rendered. Missing optional media
      // must not delay or invalidate the lookup/highlight interaction.
    }
  }

  void _notifyLoadingChanged(bool loading) {
    if (widget.onLoadingChanged == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoadingChanged?.call(loading);
    });
  }

  Future<int> _lookupRedirect(String query) async {
    final generation = ++_lookupGeneration;
    final normalized = query.trim();
    _requestedQuery = normalized;
    final results = await HoshidictsLookupBackend.instance.lookup(
      normalized,
      maxResults: hoshiPopupMaxResults,
      scanLength: hoshiPopupScanLength,
    );
    if (!mounted || generation != _lookupGeneration) return 0;
    final dictionaryMediaData = await _loadPopupMedia(results);
    if (!mounted || generation != _lookupGeneration) return 0;
    _setResults(results, dictionaryMediaData: dictionaryMediaData);
    _resultQuery = normalized;
    _renderedQuery = normalized;
    return _entries.length;
  }

  Future<bool> _isDuplicate(String expression) async {
    try {
      final dictionaryProfile =
          await MiningPreferences.getActiveDictionaryProfile();
      final profile = dictionaryProfile.anki;
      if (!profile.ankiEnabled || !profile.duplicateCheck) return false;
      final service = AnkiConnectService(
        endpoint: await MiningPreferences.getAnkiEndpoint(),
      );
      final status = await service.checkDuplicateExpression(
        deckName: profile.deckName,
        modelName: profile.modelName,
        expression: expression,
        duplicateScope: profile.duplicateScope,
        checkAllModels: profile.checkAllModels,
      );
      return status.isDuplicate;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _mine(Map<String, dynamic> content) async {
    final expression = content['expression']?.toString() ?? '';
    final reading = content['reading']?.toString() ?? '';
    HoshiLookupResult? result;
    for (final candidate in _results) {
      if (candidate.term.expression == expression &&
          candidate.term.reading == reading) {
        result = candidate;
        break;
      }
    }
    if (result == null || _exporting) return false;
    setState(() => _exporting = true);
    try {
      final miningContext = await widget.miningContext;
      if (miningContext == null) return false;
      final dictionaryProfile =
          await MiningPreferences.getActiveDictionaryProfile();
      final profile = dictionaryProfile.anki;
      if (!profile.ankiEnabled) {
        botToast('Anki export is disabled in Dictionary settings', second: 4);
        return false;
      }
      final dictionaryMedia = await _loadAnkiDictionaryMedia(
        content['dictionaryMedia'],
      );
      final audioPreferences =
          await MiningPreferences.getAnkiAudioPreferences();
      final wordAudio = await AnkiAudioService().fetchTermAudio(
        term: result.term.expression,
        reading: result.term.reading,
        preferences: audioPreferences,
      );
      final draft = await const AnkiCardBuilder().build(
        result: result,
        context: miningContext,
        profile: profile,
        renderedContent: content,
        dictionaryMedia: dictionaryMedia,
        wordAudio: wordAudio,
      );
      final noteId =
          await AnkiConnectService(
            endpoint: await MiningPreferences.getAnkiEndpoint(),
          ).exportDraft(
            draft,
            duplicateCheck: profile.duplicateCheck,
            allowDuplicate: dictionaryProfile.duplicateAction == 'allow',
            duplicateScope: profile.duplicateScope,
            checkAllModels: profile.checkAllModels,
            syncOnCreate: profile.syncOnCreate,
          );
      botToast('Added to Anki (#$noteId)', second: 3);
      return true;
    } on AnkiDuplicateException {
      botToast('Already in Anki', second: 3);
      return false;
    } catch (error) {
      botToast('Anki export failed: $error', second: 5);
      return false;
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<List<AnkiMediaFile>> _loadAnkiDictionaryMedia(Object? raw) async {
    Object? decoded = raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        return const [];
      }
    }
    if (decoded is! List) return const [];
    final files = <AnkiMediaFile>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final dictionary = item['dictionary']?.toString() ?? '';
      final path = item['path']?.toString() ?? '';
      final filename = item['filename']?.toString() ?? '';
      if (dictionary.isEmpty || path.isEmpty || filename.isEmpty) continue;
      final bytes = await HoshidictsLookupBackend.instance.getMediaFile(
        dictName: dictionary,
        mediaPath: path,
      );
      if (bytes == null || bytes.isEmpty) continue;
      files.add(
        AnkiMediaFile(
          filename: filename.split(RegExp(r'[/\\]')).last,
          bytes: bytes,
        ),
      );
    }
    return files;
  }

  void _registerHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'getEntries',
      callback: (arguments) {
        final body = _argumentMap(arguments);
        final start = (body['start'] as num?)?.toInt() ?? 0;
        final count = (body['count'] as num?)?.toInt() ?? 0;
        final safeStart = start.clamp(0, _entries.length);
        final end = (safeStart + count).clamp(safeStart, _entries.length);
        return _entries.sublist(safeStart, end);
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'lookupRedirect',
      callback: (arguments) =>
          _lookupRedirect(arguments.isEmpty ? '' : arguments.first.toString()),
    );
    controller.addJavaScriptHandler(
      handlerName: 'textSelected',
      callback: (arguments) async {
        final text = _argumentMap(arguments)['text']?.toString() ?? '';
        if (text.trim().isEmpty) return 0;
        final count = await _lookupRedirect(text);
        if (count > 0) {
          await _evaluateJavascript('redirect($count);');
        }
        return count;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'dismissPopup',
      callback: (_) {
        widget.onDismiss();
        return true;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'duplicateCheck',
      callback: (arguments) =>
          _isDuplicate(arguments.isEmpty ? '' : arguments.first.toString()),
    );
    controller.addJavaScriptHandler(
      handlerName: 'mineEntry',
      callback: (arguments) => _mine(_argumentMap(arguments)),
    );
    controller.addJavaScriptHandler(
      handlerName: 'getTermAudioSources',
      callback: (arguments) => _getTermAudioSources(_argumentMap(arguments)),
    );
    controller.addJavaScriptHandler(
      handlerName: 'playWordAudio',
      callback: (arguments) => _playWordAudio(_argumentMap(arguments)),
    );
    controller.addJavaScriptHandler(
      handlerName: 'openLink',
      callback: (arguments) async {
        if (arguments.isEmpty) return false;
        final uri = Uri.tryParse(arguments.first.toString());
        return uri != null && await launchUrl(uri);
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'navigationChanged',
      callback: (arguments) {
        final state = _argumentMap(arguments);
        widget.onNavigationChanged?.call(
          HoshiDictionaryNavigationState(
            canGoBack: state['canGoBack'] == true,
            canGoForward: state['canGoForward'] == true,
          ),
        );
        return true;
      },
    );
    for (final name in const ['tapOutside', 'swipeDismiss', 'buttonRects']) {
      controller.addJavaScriptHandler(handlerName: name, callback: (_) => null);
    }
  }

  Future<List<Map<String, String>>> _getTermAudioSources(
    Map<String, dynamic> content,
  ) async {
    final expression = content['expression']?.toString() ?? '';
    if (expression.trim().isEmpty) return const [];
    final reading = content['reading']?.toString() ?? expression;
    final preferences = await MiningPreferences.getAnkiAudioPreferences();
    final sources = await AnkiAudioService().resolveTermAudioSources(
      term: expression,
      reading: reading,
      preferences: preferences,
    );
    return [for (final source in sources) source.toJson()];
  }

  Future<bool> _playWordAudio(Map<String, dynamic> content) async {
    final url = content['url']?.toString() ?? '';
    if (url.trim().isEmpty) return false;
    try {
      final player = _audioPlayer ??= Player();
      if (content['mode']?.toString() == 'interrupt') {
        await player.stop();
      }
      await player.open(Media(url));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<CustomSchemeResponse?> _loadDictionaryMedia(
    WebResourceRequest request,
  ) async {
    final url = request.url;
    final dictionary = url.queryParameters['dictionary'];
    final path = url.queryParameters['path'];
    if (dictionary == null || path == null) return null;
    final bytes = await HoshidictsLookupBackend.instance.getMediaFile(
      dictName: dictionary,
      mediaPath: path,
    );
    if (bytes == null) return null;
    return CustomSchemeResponse(
      data: Uint8List.fromList(bytes),
      contentType: _mediaMimeType(path),
      contentEncoding: 'binary',
    );
  }

  Future<void> _render(Map<String, String> styles) async {
    await _evaluateJavascript(
      'window.dictionaryStyles = ${jsonEncode(styles)};'
      '${hoshiReplaceRenderScriptForEntries(_entries, mediaDataUris: _dictionaryMediaData, emptyMessage: _emptyMessage)}',
    );
  }

  Future<void> _replaceRender() async {
    if (!_webReady) return;
    await _evaluateJavascript(
      hoshiReplaceRenderScriptForEntries(
        _entries,
        mediaDataUris: _dictionaryMediaData,
        emptyMessage: _emptyMessage,
      ),
    );
  }

  Future<void> _evaluateJavascript(String source) {
    final controller = _controller;
    if (controller == null || !_webReady) return Future<void>.value();
    final current = _javascriptQueue.then((_) async {
      if (!mounted || _controller != controller || !_webReady) return;
      await controller.evaluateJavascript(source: source);
    });
    _javascriptQueue = current.catchError((_) {});
    return current;
  }

  Future<void> _navigateBack() =>
      _evaluateJavascript('window.navigateBack?.();');

  Future<void> _navigateForward() =>
      _evaluateJavascript('window.navigateForward?.();');

  void _scrollPopupBy(Offset delta) {
    if (!_webReady || delta == Offset.zero) return;
    unawaited(
      _evaluateJavascript(
        'window.scrollBy(${delta.dx.toStringAsFixed(2)}, '
        '${delta.dy.toStringAsFixed(2)});',
      ),
    );
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    if (!_webReady) _shellFuture = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shellFuture = _shellFuture ??= _loadShell(
      theme: theme,
      dark: _isDarkPopup(theme.brightness, widget.preferences.theme),
    );
    return FutureBuilder<_HoshiPopupData>(
      future: shellFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _shellFuture = null),
              child: const Text(
                'Dictionary popup failed to load. Tap to retry.',
              ),
            ),
          );
        }
        final data = snapshot.data!;
        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              _scrollPopupBy(event.scrollDelta);
            }
          },
          onPointerPanZoomUpdate: (event) => _scrollPopupBy(event.panDelta),
          child: InAppWebView(
            webViewEnvironment: webViewEnvironment,
            initialData: InAppWebViewInitialData(
              data: data.html,
              baseUrl: WebUri('https://hoshi-popup.local/'),
            ),
            initialSettings: InAppWebViewSettings(
              transparentBackground: true,
              resourceCustomSchemes: _usesStableCustomSchemes
                  ? const ['image']
                  : const [],
              supportZoom: false,
              disableHorizontalScroll: true,
              horizontalScrollBarEnabled: false,
              verticalScrollBarEnabled: true,
              isInspectable: kDebugMode,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
              _registerHandlers(controller);
            },
            onLoadStop: (_, _) async {
              _webReady = true;
              await _render(await _stylesFuture);
              _renderedQuery = _resultQuery;
              if (_resultQuery == widget.text.trim() && _results.isNotEmpty) {
                widget.onMatchChanged(_results.first.matched.length);
              }
              if (_requestedQuery != widget.text.trim()) {
                await _lookupAndRender(
                  widget.text,
                  notifyMatch: true,
                  initialResults: widget.initialResults,
                );
              }
            },
            onLoadResourceWithCustomScheme: _usesStableCustomSchemes
                ? (_, request) => _loadDictionaryMedia(request)
                : null,
          ),
        );
      },
    );
  }
}

Map<String, dynamic> _argumentMap(List<dynamic> arguments) {
  if (arguments.isEmpty || arguments.first is! Map) return const {};
  return Map<String, dynamic>.from(arguments.first as Map);
}

@visibleForTesting
String hoshiReplaceRenderScript(int entryCount) =>
    'window.resetHoshiAudioCaches?.();'
    'window.resetHoshiNavigation?.();'
    'window.resetHoshiDictionaryStyles?.();'
    'window.getSelection?.()?.removeAllRanges?.();'
    'window.scrollTo(0, 0);'
    'window.lookupEntries = undefined;'
    'window.entryCount = $entryCount;'
    'document.getElementById("entries-container").innerHTML = "";'
    'window.renderPopup();';

@visibleForTesting
String hoshiReplaceRenderScriptForEntries(
  List<Map<String, dynamic>> entries, {
  Map<String, Map<String, String>> mediaDataUris = const {},
  String emptyMessage = 'No dictionary results found.',
}) =>
    '(function(){'
    'window.__mangayomiHoshiRenderToken = '
    '(window.__mangayomiHoshiRenderToken || 0) + 1;'
    'window.resetHoshiAudioCaches?.();'
    'window.resetHoshiNavigation?.();'
    'window.resetHoshiDictionaryStyles?.();'
    'window.getSelection?.()?.removeAllRanges?.();'
    'window.scrollTo(0, 0);'
    'window.hoshiDictionaryMedia = ${jsonEncode(mediaDataUris)};'
    'window.lookupEntries = ${jsonEncode(entries)};'
    'window.entryCount = window.lookupEntries.length;'
    'const container = document.getElementById("entries-container");'
    'if (container) container.textContent = "";'
    'if (window.entryCount === 0) {'
    'if (container) {'
    'const empty = document.createElement("div");'
    'empty.className = "popup-empty";'
    'empty.textContent = ${jsonEncode(emptyMessage)};'
    'container.replaceChildren(empty);'
    '}'
    'return;'
    '}'
    'window.renderPopup();'
    '})();';

List<Map<String, dynamic>> hoshiPopupEntries(List<HoshiLookupResult> results) =>
    [for (final result in results) hoshiPopupEntry(result)];

typedef HoshiPopupMediaLoader =
    Future<Uint8List?> Function(String dictionary, String path);

@visibleForTesting
Future<Map<String, Map<String, String>>> hoshiPopupMediaDataUris(
  List<HoshiLookupResult> results,
  HoshiPopupMediaLoader load, {
  Map<String, Map<String, String>> existing = const {},
}) async {
  final requested = <(String, String)>{};
  for (final result in results) {
    for (final glossary in result.term.glossaries) {
      for (final path in yomitanGlossaryMediaPaths(glossary.glossary)) {
        requested.add((glossary.dictName, path));
      }
    }
  }

  final media = <String, Map<String, String>>{};
  for (final (dictionary, path) in requested) {
    final cached = existing[dictionary]?[path];
    if (cached != null) {
      (media[dictionary] ??= {})[path] = cached;
      continue;
    }
    final bytes = await load(dictionary, path);
    if (bytes == null || bytes.isEmpty) continue;
    final dataUri =
        'data:${_mediaMimeType(path)};base64,${base64Encode(bytes)}';
    (media[dictionary] ??= {})[path] = dataUri;
  }
  return media;
}

Map<String, dynamic> hoshiPopupEntry(HoshiLookupResult result) {
  final term = result.term;
  return {
    'expression': term.expression,
    'reading': term.reading,
    'matched': result.matched,
    'deinflectionTrace': [
      for (final trace in result.trace.reversed)
        {'name': trace.name, 'description': trace.description},
    ],
    'glossaries': [
      for (final glossary in term.glossaries)
        {
          'dictionary': glossary.dictName,
          'content': glossary.glossary,
          'definitionTags': glossary.definitionTags,
          'termTags': glossary.termTags,
        },
    ],
    'frequencies': [
      for (final frequency in term.frequencies)
        {
          'dictionary': frequency.dictName,
          'frequencies': [
            for (final value in frequency.frequencies)
              {'value': value.value, 'displayValue': value.displayValue},
          ],
        },
    ],
    'pitches': [
      for (final pitch in term.pitches)
        {
          'dictionary': pitch.dictName,
          'pitchPositions': pitch.pitchPositions.toSet().toList(),
          'transcriptions': pitch.transcriptions.toSet().toList(),
        },
    ],
    'rules': term.rules.split(' ').where((rule) => rule.isNotEmpty).toList(),
  };
}

String buildHoshiPopupHtml({
  required String popupCss,
  required String popupJs,
  required String selectionJs,
  required AnkiAudioPreferences audioPreferences,
  required bool allowDuplicates,
  required DictionaryPopupPreferences preferences,
  required ThemeData theme,
  required bool dark,
}) {
  final scale = preferences.fontSize / 15;
  final customCss = jsonEncode(preferences.customCss);
  final colorScheme = dark ? 'dark' : 'light';
  final scheme = theme.colorScheme;
  final background = _cssColor(
    preferences.theme == DictionaryThemePreference.black
        ? Colors.black
        : scheme.surface,
  );
  final elevatedBase = preferences.theme == DictionaryThemePreference.black
      ? const Color(0xff151515)
      : Color.alphaBlend(
          scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.42 : 0.28),
          scheme.surface,
        );
  final elevated = _cssColor(elevatedBase);
  final text = _cssColor(
    preferences.theme == DictionaryThemePreference.black
        ? Colors.white
        : scheme.onSurface,
  );
  final muted1 = _cssColor(scheme.onSurfaceVariant);
  final muted2 = _cssColor(scheme.onSurfaceVariant.withValues(alpha: 0.84));
  final muted3 = _cssColor(scheme.onSurfaceVariant.withValues(alpha: 0.70));
  final muted4 = _cssColor(scheme.onSurfaceVariant.withValues(alpha: 0.56));
  final primary = _cssColor(scheme.primary);
  final primaryContainer = _cssColor(scheme.primaryContainer);
  final onPrimaryContainer = _cssColor(scheme.onPrimaryContainer);
  final audioSources =
      audioPreferences.enabled && audioPreferences.url.trim().isNotEmpty
      ? [audioPreferences.url.trim()]
      : const <String>[];
  const nativeHandlers = [
    'getEntries',
    'lookupRedirect',
    'textSelected',
    'dismissPopup',
    'mineEntry',
    'duplicateCheck',
    'openLink',
    'getTermAudioSources',
    'playWordAudio',
    'navigationChanged',
  ];
  final html =
      '''<!DOCTYPE html>
<html style="color-scheme: $colorScheme">
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>$popupCss</style>
  <style>
    html, body {
      --popup-scale: $scale;
      --background-color: $background;
      --background-color-light: $background;
      --background-color-dark1: $elevated;
      --text-color: $text;
      --text-color-light1: $muted1;
      --text-color-light2: $muted2;
      --text-color-light3: $muted3;
      --text-color-light4: $muted4;
      --accent-color: $primary;
      --freq-tag-color: $primary;
      --pitch-tag-color: $primary;
      --expr-tag-color: $primaryContainer;
      --expr-tag-text-color: $onPrimaryContainer;
      min-height: 100%;
    }
    html { overflow-x: hidden; overflow-y: auto; }
    body { min-height: 101%; }
	    .entry, .entry * { color: var(--text-color); }
	    .dict-label, .deinflection-tag, .glossary-tag { color: var(--text-color-light1); }
	    .glossary-group {
	      background-color: $elevated;
	      color: var(--text-color);
	      box-shadow: none;
	    }
	    .glossary-content, .glossary-content * { color: var(--text-color); }
	    .tag-row, .tag-row * { color: var(--text-color-light1); }
	    .frequency-dict-label, .pitch-dict-label { color: #fff; }
	    .overlay {
	      background: var(--background-color-dark1);
	      color: var(--text-color);
	    }
	    .overlay-content, .overlay-close { color: var(--text-color); }
		    .popup-empty {
	      min-height: calc(140px * var(--popup-scale));
	      display: grid;
	      place-items: center;
	      color: var(--text-color-light2);
	      font-size: calc(14px * var(--popup-scale));
	    }
		    .button-slot { cursor: pointer; display: grid; place-items: center; color: var(--text-color-light2); }
		    .button-slot::before { content: none; }
		    .button-slot[data-state="loading"] .slot-icon,
		    .button-slot[data-state="error"] .slot-icon,
		    .button-slot[data-state="duplicate"] .slot-icon { display: none; }
		    .slot-icon {
		      display: block;
		      width: calc(23px * var(--popup-scale));
		      height: calc(23px * var(--popup-scale));
		      color: inherit;
		      overflow: visible;
		    }
		    .plus-line {
		      fill: currentColor;
		      shape-rendering: crispEdges;
		    }
		    .audio-icon { transform: translate(calc(1px * var(--popup-scale)), calc(1px * var(--popup-scale))); }
		    .audio-speaker-body { fill: currentColor; }
			    .audio-wave {
			      fill: none;
			      stroke: currentColor;
		      stroke-width: 2;
		      stroke-linecap: round;
		      stroke-linejoin: round;
		    }
		    .button-slot[data-state="loading"]::before { content: '…'; font-size: calc(18px * var(--popup-scale)); }
		    .button-slot[data-state="error"]::before { content: '!'; font-size: calc(18px * var(--popup-scale)); }
		    .button-slot[data-state="duplicate"]::before { content: '⊞'; font-size: calc(19px * var(--popup-scale)); }
	    .button-slot[data-enabled="false"] { opacity: .45; pointer-events: none; }
	  </style>
  <script>
    window.collapseMode = 'Expand All';
    window.expandFirstDictionary = true;
    window.collapsedDictionaries = [];
    window.twoColumnLayout = false;
    window.compactGlossaries = false;
    window.showExpressionTags = false;
    window.harmonicFrequency = ${preferences.showFrequencyHarmonic};
    window.deduplicatePitchAccents = true;
    window.compactPitchAccents = false;
	    window.audioSources = ${jsonEncode(audioSources)};
	    window.audioSourceType = ${jsonEncode(audioPreferences.sourceType.name)};
	    window.audioSourceLanguage = ${jsonEncode(audioPreferences.language)};
	    window.audioEnableAutoplay = false;
	    window.audioPlaybackMode = 'interrupt';
	    window.needsAudio = ${audioSources.isNotEmpty};
    window.allowDupes = $allowDuplicates;
    window.useAnkiConnect = true;
    window.enableBackgroundDuplicateChecks = false;
    window.embedMedia = false;
    window.compactGlossariesAnki = false;
    window.customCSS = $customCss;
    window.scanNonJapaneseText = true;
    window.scanLength = $hoshiPopupScanLength;
    window.swipeThreshold = 0;
    window.webkit = {messageHandlers: new Proxy({}, {get: (_, name) => ({
      postMessage: (payload) => ${jsonEncode(nativeHandlers)}.includes(String(name))
        ? window.flutter_inappwebview.callHandler(String(name), payload)
        : Promise.resolve(String(name) === 'duplicateCheck' ? false : null)
    })})};
    document.addEventListener('click', (event) => {
      const slot = event.target.closest?.('.button-slot');
	      if (!slot || slot.dataset.enabled === 'false') return;
	      event.preventDefault();
	      event.stopPropagation();
	      const index = Number(slot.dataset.entryIndex);
	      if (slot.dataset.kind === 'mine') mineEntryAtIndex(index);
	      if (slot.dataset.kind === 'audio') playEntryAudio(index);
	    }, true);
	    document.addEventListener('contextmenu', (event) => {
	      const slot = event.target.closest?.('.button-slot[data-kind="audio"]');
	      if (!slot || slot.dataset.enabled === 'false') return;
	      event.preventDefault();
	      event.stopPropagation();
	      showAudioSourceMenu(Number(slot.dataset.entryIndex), event.clientX, event.clientY);
	    }, true);
	  </script>
  <script>$selectionJs</script>
  <script>$popupJs</script>
</head>
<body>
  <div id="entries-container"></div>
  <div class="overlay"><div class="overlay-close" onclick="closeOverlay()">×</div><div class="overlay-content"></div></div>
</body>
</html>''';
  return html
      .replaceFirst(
        RegExp(r'\.button-slot\[data-state="duplicate"\]::before \{[^}]*\}'),
        '.button-slot[data-state="duplicate"]::before { content: "\\229E"; font-size: calc(19px * var(--popup-scale)); }',
      )
      .replaceFirst(
        RegExp(
          r'<div class="overlay-close" onclick="closeOverlay\(\)">.*?<div class="overlay-content">',
        ),
        '<div class="overlay-close" onclick="closeOverlay()">&times;</div><div class="overlay-content">',
      );
}

bool _isDarkPopup(
  Brightness brightness,
  DictionaryThemePreference preference,
) => switch (preference) {
  DictionaryThemePreference.light => false,
  DictionaryThemePreference.dark || DictionaryThemePreference.black => true,
  DictionaryThemePreference.system => brightness == Brightness.dark,
};

String _cssColor(Color color) {
  final rgb = color.toARGB32() & 0x00ffffff;
  return '#${rgb.toRadixString(16).padLeft(6, '0')}';
}

String _mediaMimeType(String path) =>
    switch (path.split('.').last.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'svg' => 'image/svg+xml',
      'webp' => 'image/webp',
      'avif' => 'image/avif',
      'heic' => 'image/heic',
      _ => 'image/png',
    };

bool get _usesStableCustomSchemes =>
    kIsWeb || defaultTargetPlatform != TargetPlatform.windows;

class _HoshiPopupData {
  const _HoshiPopupData({required this.html});

  final String html;
}
