import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/utils/platform_utils.dart';

void main() {
  test('word audio is enabled by default', () {
    expect(AnkiAudioPreferences.defaults.enabled, isTrue);
  });

  test('dictionary lookup trigger falls back to left click', () {
    expect(
      dictionaryLookupTriggerFromName(null),
      DictionaryLookupTrigger.leftClick,
    );
    expect(
      dictionaryLookupTriggerFromName('invalid'),
      DictionaryLookupTrigger.leftClick,
    );
    expect(
      dictionaryLookupTriggerFromName('middleClick'),
      DictionaryLookupTrigger.middleClick,
    );
  });

  test('page tap zones are disabled by default on desktop', () {
    expect(Settings().usePageTapZones, !isDesktop);
  });

  test('EPUB reading layout is persisted in settings JSON', () {
    final settings = Settings()..novelEpubReadingLayout = 2;
    final json = settings.toJson();

    expect(json['novelEpubReadingLayout'], 2);
    expect(Settings.fromJson(json).novelEpubReadingLayout, 2);
  });

  test('paragraph spacing defaults to zero and persists in settings JSON', () {
    final defaults = Settings();
    expect(defaults.novelReaderParagraphSpacing, 0.0);

    final settings = Settings()..novelReaderParagraphSpacing = 1.2;
    final json = settings.toJson();

    expect(json['novelReaderParagraphSpacing'], 1.2);
    expect(Settings.fromJson(json).novelReaderParagraphSpacing, 1.2);
  });

  test('legacy compact paragraph setting migrates to its closest value', () {
    final legacyJson = Settings().toJson()
      ..remove('novelReaderParagraphSpacing')
      ..['novelRemoveExtraParagraphSpacing'] = true;

    expect(Settings.fromJson(legacyJson).novelReaderParagraphSpacing, 0.25);
  });
}
