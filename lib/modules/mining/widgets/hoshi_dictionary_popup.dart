import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/services/hoshidicts/hoshidicts_backend.dart';
import 'package:mangayomi/services/mining/anki_card_builder.dart';
import 'package:mangayomi/services/mining/anki_connect_service.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';
import 'package:url_launcher/url_launcher.dart';

class HoshiDictionaryPopup extends StatefulWidget {
  const HoshiDictionaryPopup({
    super.key,
    required this.text,
    required this.miningContext,
    required this.preferences,
    required this.onMatchChanged,
  });

  final String text;
  final MiningContext miningContext;
  final DictionaryPopupPreferences preferences;
  final ValueChanged<int> onMatchChanged;

  @override
  State<HoshiDictionaryPopup> createState() => _HoshiDictionaryPopupState();
}

class _HoshiDictionaryPopupState extends State<HoshiDictionaryPopup> {
  late Future<_HoshiPopupData> _future = _load();
  InAppWebViewController? _controller;
  List<HoshiLookupResult> _results = const [];
  List<Map<String, dynamic>> _entries = const [];
  bool _exporting = false;

  @override
  void didUpdateWidget(covariant HoshiDictionaryPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.preferences != widget.preferences) {
      _future = _load();
    }
  }

  Future<_HoshiPopupData> _load() async {
    final dark = _isDarkPopup(context, widget.preferences.theme);
    final values = await Future.wait<dynamic>([
      rootBundle.loadString('assets/hoshi_popup/popup.css'),
      rootBundle.loadString('assets/hoshi_popup/popup.js'),
      rootBundle.loadString('assets/hoshi_popup/selection.js'),
      HoshidictsLookupBackend.instance.lookup(
        widget.text.trim(),
        maxResults: 20,
        scanLength: 80,
      ),
      HoshidictsLookupBackend.instance.getStyles().catchError(
        (_) => <HoshiDictionaryStyle>[],
      ),
    ]);
    final results = values[3] as List<HoshiLookupResult>;
    _setResults(results);
    if (results.isNotEmpty) {
      widget.onMatchChanged(results.first.matched.length);
    }
    final styles = values[4] as List<HoshiDictionaryStyle>;
    return _HoshiPopupData(
      html: buildHoshiPopupHtml(
        popupCss: values[0] as String,
        popupJs: values[1] as String,
        selectionJs: values[2] as String,
        preferences: widget.preferences,
        dark: dark,
      ),
      styles: {for (final style in styles) style.dictName: style.styles},
    );
  }

  void _setResults(List<HoshiLookupResult> results) {
    _results = results;
    _entries = hoshiPopupEntries(results);
  }

  Future<int> _lookupRedirect(String query) async {
    final results = await HoshidictsLookupBackend.instance.lookup(
      query,
      maxResults: 20,
      scanLength: 80,
    );
    _setResults(results);
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
      final profile = await MiningPreferences.getAnkiProfile();
      if (!profile.ankiEnabled) {
        botToast('Anki export is disabled in Dictionary settings', second: 4);
        return false;
      }
      final draft = await const AnkiCardBuilder().build(
        result: result,
        context: widget.miningContext,
        profile: profile,
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
      handlerName: 'openLink',
      callback: (arguments) async {
        if (arguments.isEmpty) return false;
        final uri = Uri.tryParse(arguments.first.toString());
        return uri != null && await launchUrl(uri);
      },
    );
    for (final name in const [
      'tapOutside',
      'swipeDismiss',
      'buttonRects',
      'playWordAudio',
    ]) {
      controller.addJavaScriptHandler(handlerName: name, callback: (_) => null);
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

  Future<void> _render(_HoshiPopupData data) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.evaluateJavascript(
      source:
          'window.dictionaryStyles = ${jsonEncode(data.styles)};'
          'window.entryCount = ${_entries.length};'
          'window.renderPopup();',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HoshiPopupData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lookup failed: ${snapshot.error}'));
        }
        final data = snapshot.data!;
        if (_entries.isEmpty) {
          return const Center(child: Text('No dictionary results found.'));
        }
        return InAppWebView(
          webViewEnvironment: webViewEnvironment,
          initialData: InAppWebViewInitialData(
            data: data.html,
            baseUrl: WebUri('https://hoshi-popup.local/'),
          ),
          initialSettings: InAppWebViewSettings(
            transparentBackground: true,
            resourceCustomSchemes: const ['image'],
            supportZoom: false,
            disableHorizontalScroll: true,
            horizontalScrollBarEnabled: false,
            isInspectable: kDebugMode,
          ),
          onWebViewCreated: (controller) {
            _controller = controller;
            _registerHandlers(controller);
          },
          onLoadStop: (_, _) => _render(data),
          onLoadResourceWithCustomScheme: (_, request) =>
              _loadDictionaryMedia(request),
        );
      },
    );
  }
}

Map<String, dynamic> _argumentMap(List<dynamic> arguments) {
  if (arguments.isEmpty || arguments.first is! Map) return const {};
  return Map<String, dynamic>.from(arguments.first as Map);
}

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
  required DictionaryPopupPreferences preferences,
  required bool dark,
}) {
  final scale = preferences.fontSize / 15;
  final customCss = jsonEncode(preferences.customCss);
  final colorScheme = dark ? 'dark' : 'light';
  return '''<!DOCTYPE html>
<html style="color-scheme: $colorScheme">
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>$popupCss</style>
  <style>
    html, body { --popup-scale: $scale; }
    .button-slot { cursor: pointer; display: grid; place-items: center; color: var(--text-color-light2); }
    .button-slot::before { content: '+'; font: 500 calc(25px * var(--popup-scale))/1 sans-serif; }
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
    window.audioSources = [];
    window.audioEnableAutoplay = false;
    window.audioPlaybackMode = 'interrupt';
    window.needsAudio = false;
    window.allowDupes = false;
    window.useAnkiConnect = true;
    window.embedMedia = false;
    window.compactGlossariesAnki = false;
    window.customCSS = $customCss;
    window.scanNonJapaneseText = true;
    window.scanLength = 80;
    window.swipeThreshold = 0;
    window.webkit = {messageHandlers: new Proxy({}, {get: (_, name) => ({
      postMessage: (payload) => window.flutter_inappwebview.callHandler(String(name), payload)
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
  </script>
  <script>$selectionJs</script>
  <script>$popupJs</script>
</head>
<body>
  <div id="entries-container"></div>
  <div class="overlay"><div class="overlay-close" onclick="closeOverlay()">×</div><div class="overlay-content"></div></div>
</body>
</html>''';
}

bool _isDarkPopup(BuildContext context, DictionaryThemePreference preference) =>
    switch (preference) {
      DictionaryThemePreference.light => false,
      DictionaryThemePreference.dark || DictionaryThemePreference.black => true,
      DictionaryThemePreference.system =>
        Theme.of(context).brightness == Brightness.dark,
    };

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

class _HoshiPopupData {
  const _HoshiPopupData({required this.html, required this.styles});

  final String html;
  final Map<String, String> styles;
}
