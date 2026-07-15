import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/services/mining/dictionary_profile_resolver.dart';

void main() {
  const japaneseFirst = DictionaryProfile(
    id: 'japanese-first',
    name: 'Japanese first',
    languageCode: 'ja',
  );
  const japaneseSecond = DictionaryProfile(
    id: 'japanese-second',
    name: 'Japanese second',
    languageCode: 'ja',
  );
  const english = DictionaryProfile(
    id: 'english',
    name: 'English',
    languageCode: 'en',
  );
  const profiles = [japaneseFirst, japaneseSecond, english];

  test('uses the exact Chimahon override key names', () {
    expect(
      DictionaryProfileResolver.mangaOverrideKey(42),
      'pref_dict_profile_manga_42',
    );
    expect(
      DictionaryProfileResolver.sourceOverrideKey(9001),
      'pref_dict_profile_source_9001',
    );
    expect(
      DictionaryProfileResolver.novelOverrideKey('book-id'),
      'pref_dict_profile_novel_book-id',
    );
  });

  test('resolves overrides in Chimahon cascade order', () {
    final resolved = DictionaryProfileResolver.resolveValues(
      profiles: profiles,
      activeProfile: english,
      mangaOverrideId: japaneseSecond.id,
      sourceOverrideId: japaneseFirst.id,
      novelOverrideId: english.id,
      sourceLanguage: 'en',
    );

    expect(resolved.profile.id, japaneseSecond.id);
    expect(resolved.level, DictionaryProfileResolutionLevel.manga);
  });

  test('stale overrides fall through and first language match wins', () {
    final resolved = DictionaryProfileResolver.resolveValues(
      profiles: profiles,
      activeProfile: english,
      mangaOverrideId: 'deleted-profile',
      sourceOverrideId: 'also-deleted',
      sourceLanguage: ' JA ',
    );

    expect(resolved.profile.id, japaneseFirst.id);
    expect(resolved.level, DictionaryProfileResolutionLevel.language);
  });

  test('blank and all languages fall back to globally active profile', () {
    for (final language in ['', 'all']) {
      final resolved = DictionaryProfileResolver.resolveValues(
        profiles: profiles,
        activeProfile: english,
        sourceLanguage: language,
      );
      expect(resolved.profile.id, english.id);
      expect(resolved.level, DictionaryProfileResolutionLevel.active);
    }
  });

  test('stale active ID falls back to first available profile', () {
    const staleActive = DictionaryProfile(
      id: 'deleted',
      name: 'Deleted',
      languageCode: 'en',
    );
    final resolved = DictionaryProfileResolver.resolveValues(
      profiles: profiles,
      activeProfile: staleActive,
    );

    expect(resolved.profile.id, japaneseFirst.id);
  });

  test('uses native Mihon source ID for compatible source override keys', () {
    final source = Source()
      ..id = mihonLocalSourceId('1234567890123456789')
      ..sourceCodeLanguage = SourceCodeLanguage.mihon
      ..additionalParams = encodeMihonSourceMetadata(
        sourceId: '1234567890123456789',
        packageName: 'org.example.source',
      );

    expect(
      DictionaryProfileResolver.overrideIdForSource(source),
      '1234567890123456789',
    );
  });

  test('does not expose a hashed ID for malformed Mihon metadata', () {
    final source = Source()
      ..id = mihonLocalSourceId('1234567890123456789')
      ..sourceCodeLanguage = SourceCodeLanguage.mihon;

    expect(DictionaryProfileResolver.overrideIdForSource(source), isNull);
  });

  test('rejects a non-Long Mihon source identity', () {
    final source = Source()
      ..id = 42
      ..sourceCodeLanguage = SourceCodeLanguage.mihon
      ..additionalParams = encodeMihonSourceMetadata(
        sourceId: 'not-a-long',
        packageName: 'org.example.source',
      );

    expect(DictionaryProfileResolver.overrideIdForSource(source), isNull);
  });

  test('uses the local Isar ID for non-Mihon sources', () {
    final source = Source()
      ..id = 42
      ..sourceCodeLanguage = SourceCodeLanguage.dart;

    expect(DictionaryProfileResolver.overrideIdForSource(source), '42');
  });

  test('normalizes source language from source or fallback', () {
    final source = Source()..lang = ' ZH ';

    expect(DictionaryProfileResolver.sourceLanguageForSource(source), 'zh');
    expect(
      DictionaryProfileResolver.sourceLanguageForSource(
        Source(),
        fallback: ' KO ',
      ),
      'ko',
    );
  });
}
