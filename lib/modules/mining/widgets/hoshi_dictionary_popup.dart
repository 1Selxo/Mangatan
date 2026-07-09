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
import 'package:mangayomi/services/hoshidicts/hoshidicts_backend.dart';
import 'package:mangayomi/services/mining/anki_audio_service.dart';
import 'package:mangayomi/services/mining/anki_card_builder.dart';
import 'package:mangayomi/services/mining/anki_connect_service.dart';
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

class HoshiDictionaryPopup extends StatefulWidget {
  const HoshiDictionaryPopup({
    super.key,
    required this.text,
    this.miningContext,
    this.initialResults,
    required this.preferences,
    required this.onMatchChanged,
  });

  final String text;
  final FutureOr<MiningContext?> miningContext;
  final Future<List<HoshiLookupResult>>? initialResults;
  final DictionaryPopupPreferences preferences;
  final ValueChanged<int> onMatchChanged;

  @override
  State<HoshiDictionaryPopup> createState() => _HoshiDictionaryPopupState();
}

class _HoshiDictionaryPopupState extends State<HoshiDictionaryPopup> {
  Future<_HoshiPopupData>? _shellFuture;
  late final Future<Map<String, String>> _stylesFuture;
  InAppWebViewController? _controller;
  List<HoshiLookupResult> _results = const [];
  List<Map<String, dynamic>> _entries = const [];
  bool _exporting = false;
  bool _webReady = false;
  int _lookupGeneration = 0;
  Future<void> _javascriptQueue = Future<void>.value();
  Player? _audioPlayer;
  String? _requestedQuery;
  String? _resultQuery;

  @override
  void initState() {
    super.initState();
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
    if (oldWidget.text != widget.text) {
      unawaited(
        _lookupAndRender(
          widget.text,
          notifyMatch: true,
          initialResults: widget.initialResults,
        ),
      );
    } else if (oldWidget.initialResults != widget.initialResults) {
      if (_resultQuery == widget.text.trim()) {
        if (_results.isNotEmpty) {
          widget.onMatchChanged(_results.first.matched.length);
        }
      } else {
        unawaited(
          _lookupAndRender(
            widget.text,
            notifyMatch: true,
            initialResults: widget.initialResults,
          ),
        );
      }
    }
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
    ]);
    return _HoshiPopupData(
      html: buildHoshiPopupHtml(
        popupCss: values[0] as String,
        popupJs: values[1] as String,
        selectionJs: values[2] as String,
        audioPreferences: values[3] as AnkiAudioPreferences,
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

  void _setResults(List<HoshiLookupResult> results) {
    _results = results;
    _entries = hoshiPopupEntries(results);
  }

  Future<void> _lookupAndRender(
    String text, {
    required bool notifyMatch,
    Future<List<HoshiLookupResult>>? initialResults,
  }) async {
    final generation = ++_lookupGeneration;
    final query = text.trim();
    _requestedQuery = query;
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
    _setResults(results);
    _resultQuery = query;
    if (notifyMatch && results.isNotEmpty) {
      widget.onMatchChanged(results.first.matched.length);
    }
    if (!unchanged) await _replaceRender();
  }

  Future<int> _lookupRedirect(String query) async {
    final results = await HoshidictsLookupBackend.instance.lookup(
      query,
      maxResults: hoshiPopupMaxResults,
      scanLength: hoshiPopupScanLength,
    );
    _setResults(results);
    _resultQuery = query.trim();
    return _entries.length;
  }

  Future<bool> _isDuplicate(String expression) async {
    try {
      final profile = await MiningPreferences.getAnkiProfile();
      if (!profile.ankiEnabled || !profile.duplicateCheck) return false;
      final service = AnkiConnectService(
        endpoint: await MiningPreferences.getAnkiEndpoint(),
      );
      final notes = await service.findDuplicateExpressions(
        deckName: profile.deckName,
        expression: expression,
      );
      return notes.isNotEmpty;
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
      final profile = await MiningPreferences.getAnkiProfile();
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
            syncOnCreate: profile.syncOnCreate,
          );
      botToast('Added to Anki (#$noteId)', second: 3);
      return true;
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
          await controller.evaluateJavascript(source: 'redirect($count);');
        }
        return count;
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
      '${hoshiReplaceRenderScriptForEntries(_entries)}',
    );
  }

  Future<void> _replaceRender() async {
    if (!_webReady) return;
    await _evaluateJavascript(hoshiReplaceRenderScriptForEntries(_entries));
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
    'window.lookupEntries = undefined;'
    'window.entryCount = $entryCount;'
    'document.getElementById("entries-container").innerHTML = "";'
    'window.renderPopup();';

@visibleForTesting
String hoshiReplaceRenderScriptForEntries(List<Map<String, dynamic>> entries) =>
    '(function(){'
    'window.__mangayomiHoshiRenderToken = '
    '(window.__mangayomiHoshiRenderToken || 0) + 1;'
    'window.resetHoshiAudioCaches?.();'
    'window.lookupEntries = ${jsonEncode(entries)};'
    'window.entryCount = window.lookupEntries.length;'
    'const container = document.getElementById("entries-container");'
    'if (container) container.textContent = "";'
    'if (window.entryCount === 0) {'
    'if (container) container.innerHTML = '
    '"<div class=\\"popup-empty\\">No dictionary results found.</div>";'
    'return;'
    '}'
    'window.renderPopup();'
    '})();';

List<Map<String, dynamic>> hoshiPopupEntries(List<HoshiLookupResult> results) =>
    [for (final result in results) hoshiPopupEntry(result)];

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
    'mineEntry',
    'openLink',
    'getTermAudioSources',
    'playWordAudio',
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
    window.allowDupes = false;
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
        '.button-slot[data-state="duplicate"]::before { content: "\\2713"; font-size: calc(19px * var(--popup-scale)); }',
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
