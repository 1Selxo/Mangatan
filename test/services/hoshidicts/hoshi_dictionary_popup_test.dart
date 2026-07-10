import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/mining/widgets/hoshi_dictionary_popup.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('converts lookup results to Hoshi popup entry schema', () {
    final result = HoshiLookupResult(
      matched: '食べた',
      deinflected: '食べる',
      trace: const [
        HoshiTransformGroup(name: 'past', description: 'past tense'),
      ],
      preprocessorSteps: 0,
      term: HoshiTermResult(
        expression: '食べる',
        reading: 'たべる',
        rules: 'v1 vt',
        score: 1,
        glossaries: const [
          HoshiGlossaryEntry(
            dictName: 'JMdict',
            glossary: 'to eat',
            definitionTags: 'v1 vt',
            termTags: 'ichi1',
          ),
        ],
        frequencies: const [
          HoshiFrequencyEntry(
            dictName: 'Jiten',
            frequencies: [HoshiFrequency(value: 120, displayValue: '120')],
          ),
        ],
        pitches: [
          HoshiPitchEntry(
            dictName: 'NHK',
            pitchPositions: Int32List.fromList([2, 2]),
            transcriptions: const ['heiban', 'heiban'],
          ),
        ],
      ),
    );

    final entry = hoshiPopupEntry(result);

    expect(entry['expression'], '食べる');
    expect(entry['rules'], ['v1', 'vt']);
    expect(entry['deinflectionTrace'], [
      {'name': 'past', 'description': 'past tense'},
    ]);
    expect((entry['glossaries'] as List).single, {
      'dictionary': 'JMdict',
      'content': 'to eat',
      'definitionTags': 'v1 vt',
      'termTags': 'ichi1',
    });
    expect(((entry['pitches'] as List).single as Map)['pitchPositions'], [2]);
  });

  test('builds the browser document around Hoshi renderer assets', () {
    const preferences = DictionaryPopupPreferences(
      width: 540,
      height: 450,
      fontSize: 15,
      theme: DictionaryThemePreference.dark,
      eInkMode: false,
      paginatedScrolling: false,
      customCss: '.entry { outline: none; }',
      showFrequencyHarmonic: true,
      showFrequencyAverage: false,
      showPitchNumber: true,
      showPitchText: true,
    );

    final html = buildHoshiPopupHtml(
      popupCss: '/* upstream popup css */',
      popupJs: 'window.renderPopup = function() {};',
      selectionJs: 'window.hoshiSelection = {};',
      audioPreferences: AnkiAudioPreferences.defaults,
      preferences: preferences,
      theme: ThemeData.dark(),
      dark: true,
    );

    expect(html, contains('color-scheme: dark'));
    expect(html, contains('/* upstream popup css */'));
    expect(html, contains('window.renderPopup = function() {};'));
    expect(html, contains('window.hoshiSelection = {};'));
    expect(html, contains("window.collapseMode = 'Expand All'"));
    expect(html, contains('window.harmonicFrequency = true'));
    expect(hoshiPopupMaxResults, 3);
    expect(hoshiPopupScanLength, 24);
    expect(html, contains('window.scanLength = 24;'));
    expect(html, contains('window.audioSources = [];'));
    expect(html, contains('flutter_inappwebview.callHandler'));
    expect(html, contains('getTermAudioSources'));
    expect(html, contains('playWordAudio'));
    expect(html, contains('.plus-line'));
    expect(html, contains('.audio-icon'));
    expect(html, contains('.audio-speaker-body'));
    expect(html, isNot(contains('\u{1F50A}')));
  });

  test('injects enabled audio preferences into popup document', () {
    const preferences = DictionaryPopupPreferences(
      width: 540,
      height: 450,
      fontSize: 15,
      theme: DictionaryThemePreference.light,
      eInkMode: false,
      paginatedScrolling: false,
      customCss: '',
      showFrequencyHarmonic: true,
      showFrequencyAverage: false,
      showPitchNumber: true,
      showPitchText: true,
    );

    final html = buildHoshiPopupHtml(
      popupCss: '/* upstream popup css */',
      popupJs: 'window.renderPopup = function() {};',
      selectionJs: 'window.hoshiSelection = {};',
      audioPreferences: const AnkiAudioPreferences(
        enabled: true,
        sourceType: AnkiAudioSourceType.customJson,
        url: 'http://localhost:5050/?term={term}&reading={reading}',
        timeout: Duration(seconds: 5),
        language: 'ja',
      ),
      preferences: preferences,
      theme: ThemeData.light(),
      dark: false,
    );

    expect(
      html,
      contains(
        'window.audioSources = ["http://localhost:5050/?term={term}&reading={reading}"];',
      ),
    );
    expect(html, contains('window.audioSourceType = "customJson";'));
    expect(html, contains('window.needsAudio = true;'));
    expect(
      html,
      contains("showAudioSourceMenu(Number(slot.dataset.entryIndex)"),
    );
  });

  test('resets popup audio caches when replacing lookup results', () {
    expect(
      hoshiReplaceRenderScript(2),
      startsWith('window.resetHoshiAudioCaches?.();'),
    );
    expect(
      hoshiReplaceRenderScriptForEntries(const []),
      contains('window.resetHoshiAudioCaches?.();'),
    );
  });

  test(
    'embeds dictionary images when WebView custom schemes are unavailable',
    () async {
      final result = HoshiLookupResult(
        matched: 'コンビニ',
        deinflected: 'コンビニ',
        trace: const [],
        preprocessorSteps: 0,
        term: const HoshiTermResult(
          expression: 'コンビニ',
          reading: '',
          rules: '',
          score: 1,
          glossaries: [
            HoshiGlossaryEntry(
              dictName: '深辞海',
              glossary:
                  '{"type":"structured-content","content":{"tag":"img","path":"yomitan_images/3494.jpg"}}',
              definitionTags: '',
              termTags: '',
            ),
          ],
          frequencies: [],
          pitches: [],
        ),
      );

      final media = await hoshiPopupMediaDataUris([result], (
        dictionary,
        path,
      ) async {
        expect(dictionary, '深辞海');
        expect(path, 'yomitan_images/3494.jpg');
        return Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);
      });

      expect(
        media['深辞海']?['yomitan_images/3494.jpg'],
        'data:image/jpeg;base64,/9j/2Q==',
      );
      final script = hoshiReplaceRenderScriptForEntries(
        hoshiPopupEntries([result]),
        mediaDataUris: media,
      );
      expect(script, contains('window.hoshiDictionaryMedia'));
      expect(script, contains('data:image/jpeg;base64,/9j/2Q=='));
    },
  );

  test('keeps frequency and pitch labels white on accent tags', () {
    const preferences = DictionaryPopupPreferences(
      width: 540,
      height: 450,
      fontSize: 15,
      theme: DictionaryThemePreference.light,
      eInkMode: false,
      paginatedScrolling: false,
      customCss: '',
      showFrequencyHarmonic: true,
      showFrequencyAverage: false,
      showPitchNumber: true,
      showPitchText: true,
    );

    final html = buildHoshiPopupHtml(
      popupCss: '/* upstream popup css */',
      popupJs: 'window.renderPopup = function() {};',
      selectionJs: 'window.hoshiSelection = {};',
      audioPreferences: AnkiAudioPreferences.defaults,
      preferences: preferences,
      theme: ThemeData.light(),
      dark: false,
    );
    final globalColorRule = html.indexOf('.entry, .entry *');
    final tagRowColorRule = html.indexOf('.tag-row, .tag-row *');
    final labelColorRule = html.indexOf(
      '.frequency-dict-label, .pitch-dict-label { color: #fff; }',
    );

    expect(labelColorRule, isNonNegative);
    expect(labelColorRule, greaterThan(globalColorRule));
    expect(labelColorRule, greaterThan(tagRowColorRule));
  });

  test('bundles the upstream Hoshi renderer and license', () async {
    final popup = await rootBundle.loadString('assets/hoshi_popup/popup.js');
    final css = await rootBundle.loadString('assets/hoshi_popup/popup.css');
    final license = await rootBundle.loadString('assets/hoshi_popup/LICENSE');

    expect(popup, contains('window.renderPopup = function()'));
    expect(popup, contains('SPDX-License-Identifier: GPL-3.0-or-later'));
    expect(popup, contains('plus-icon'));
    expect(popup, contains('M10 3h3v17h-3zM3 10h17v3H3z'));
    expect(popup, contains('audio-speaker-body'));
    expect(popup, contains('M3 9v6h4l5 4V5L7 9H3z'));
    expect(popup, contains('window.resetHoshiAudioCaches = resetAudioCaches'));
    expect(
      popup,
      contains('window.hoshiDictionaryMedia?.[dictionary]?.[path]'),
    );
    expect(popup, contains("node.type === 'image' || node.tag === 'img'"));
    expect(popup, contains('function hasPopupTextSelection()'));
    expect(popup, contains('function rememberPopupTextSelection()'));
    expect(
      popup,
      contains(
        "document.addEventListener('selectionchange', rememberPopupTextSelection);",
      ),
    );
    expect(
      popup,
      contains(
        'const selectedText = rememberPopupTextSelection() || lastSelection;',
      ),
    );
    expect(popup, contains('if (hasPopupTextSelection())'));
    expect(popup, contains('const audioKey = audioCacheKey(entry);'));
    expect(popup, contains('audioUrls[audioKey]'));
    expect(popup, isNot(contains('audioUrls[idx]')));
    expect(popup, isNot(contains('audioUrls[entryIndex]')));
    expect(css, contains('.glossary-group'));
    expect(css, contains('.glossary-content .gloss-sc-summary::marker'));
    expect(css, contains('.pronunciation-mora'));
    expect(license, contains('GNU GENERAL PUBLIC LICENSE'));
  });
}
