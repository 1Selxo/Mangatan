import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/browse/extension/widgets/source_preference_widget.dart';

void main() {
  group('Mihon bridge protocol', () {
    test('keeps native 64-bit source ids as strings', () {
      final encoded = encodeMihonSourceMetadata(
        sourceId: '7066619062139039107',
        packageName: 'eu.kanade.tachiyomi.animeextension.all.jellyfin',
      );
      final metadata = MihonSourceMetadata.fromAdditionalParams(encoded);

      expect(metadata?.sourceId, '7066619062139039107');
      expect(
        metadata?.packageName,
        'eu.kanade.tachiyomi.animeextension.all.jellyfin',
      );
    });

    test('tracks whether a dynamic factory child is currently available', () {
      final encoded = encodeMihonSourceMetadata(
        sourceId: '7066619062139039107',
        packageName: 'eu.kanade.tachiyomi.animeextension.all.jellyfin',
        factoryAvailable: false,
      );

      expect(
        MihonSourceMetadata.fromAdditionalParams(encoded)?.factoryAvailable,
        isFalse,
      );
    });

    test('groups sibling sources from the same APK package', () {
      final first = _source('1100359934660540567');
      final second = _source('5716273013801838310');
      final unrelated = _source(
        '42',
        packageName: 'eu.kanade.tachiyomi.animeextension.all.other',
      );

      expect(belongsToSameMihonExtension(first, second), isTrue);
      expect(belongsToSameMihonExtension(first, unrelated), isFalse);
    });

    test('adds source selection and changed preference context', () {
      final source = _source('5716273013801838310');
      final preference = SourcePreference(
        key: 'host_url',
        editTextPreference: EditTextPreference(value: 'http://jellyfin'),
      );

      final payload = mihonPreferencePayload(source, [
        preference,
      ], changedPreferenceKey: 'host_url');

      expect(payload.first['key'], 'host_url');
      expect(payload.last, {
        'key': mihonBridgeContextKey,
        'sourceId': '5716273013801838310',
        'changedPreferenceKey': 'host_url',
      });
    });

    test('merges a selected list value by entry value', () {
      final previous = SourcePreference(
        key: 'library_pref',
        listPreference: ListPreference(
          valueIndex: 1,
          entries: ['Anime', 'Movies'],
          entryValues: ['anime-id', 'movie-id'],
        ),
      );
      final fresh = SourcePreference(
        key: 'library_pref',
        listPreference: ListPreference(
          valueIndex: -1,
          entries: ['Movies', 'Anime', 'Shows'],
          entryValues: ['movie-id', 'anime-id', 'shows-id'],
        ),
      );

      final merged = mergeMihonPreferenceValues([fresh], [previous]);

      expect(merged.single.listPreference?.valueIndex, 0);
      expect(merged.single.listPreference?.entries, contains('Shows'));
    });

    test('keeps a bridge-validated changed value', () {
      final previous = SourcePreference(
        key: 'host_url',
        editTextPreference: EditTextPreference(value: 'not a URL'),
      );
      final fresh = SourcePreference(
        key: 'host_url',
        editTextPreference: EditTextPreference(value: 'http://jellyfin'),
      );

      final merged = mergeMihonPreferenceValues(
        [fresh],
        [previous],
        preserveFreshKeys: {'host_url'},
      );

      expect(merged.single.editTextPreference?.value, 'http://jellyfin');
    });

    test('preserves an unselected empty list index', () {
      final preference = ListPreference.fromJson({
        'valueIndex': -1,
        'entries': <String>[],
        'entryValues': <String>[],
      });

      expect(preference.valueIndex, -1);
    });

    testWidgets('renders an empty dynamic list without indexing it', (
      tester,
    ) async {
      final preference = SourcePreference(
        key: 'library_pref',
        listPreference: ListPreference(
          title: 'Select media library',
          summary: 'Currently not logged in',
          valueIndex: -1,
          entries: const [],
          entryValues: const [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourcePreferenceWidget(
              sourcePreference: [preference],
              source: _source('1100359934660540567')..id = 1,
            ),
          ),
        ),
      );

      expect(find.text('Select media library'), findsOneWidget);
      expect(find.text('Currently not logged in'), findsOneWidget);
    });
  });
}

Source _source(
  String sourceId, {
  String packageName = 'eu.kanade.tachiyomi.animeextension.all.jellyfin',
}) => Source()
  ..sourceCodeLanguage = SourceCodeLanguage.mihon
  ..sourceCodeUrl = 'https://example.test/apk/jellyfin.apk'
  ..repo = Repo(jsonUrl: 'https://example.test/index.min.json')
  ..additionalParams = encodeMihonSourceMetadata(
    sourceId: sourceId,
    packageName: packageName,
  );
