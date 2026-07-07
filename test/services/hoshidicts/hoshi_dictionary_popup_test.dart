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
    expect(html, contains('flutter_inappwebview.callHandler'));
  });

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
    expect(css, contains('.glossary-group'));
    expect(css, contains('.glossary-content .gloss-sc-summary::marker'));
    expect(css, contains('.pronunciation-mora'));
    expect(license, contains('GNU GENERAL PUBLIC LICENSE'));
  });
}
