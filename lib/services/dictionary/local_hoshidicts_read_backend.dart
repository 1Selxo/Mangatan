import 'dart:typed_data';

import 'package:mangayomi/services/dictionary/dictionary_read_backend.dart';
import 'package:mangayomi/services/hoshidicts/hoshidicts_backend.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';

class LocalHoshidictsReadBackend implements DictionaryReadBackend {
  LocalHoshidictsReadBackend([HoshidictsLookupBackend? backend])
    : _backend = backend ?? HoshidictsLookupBackend.instance;

  final HoshidictsLookupBackend _backend;

  @override
  Future<List<HoshiLookupResult>> lookup(
    String text, {
    int maxResults = 10,
    int scanLength = 20,
    String? language,
    DictionaryProfile? profile,
  }) => _backend.lookup(
    text,
    maxResults: maxResults,
    scanLength: scanLength,
    language: language,
    profile: profile,
  );

  @override
  Future<List<HoshiLookupResult>> lookupDictionary(
    String text, {
    required String dictionary,
    int maxResults = 10,
    int scanLength = 20,
    String? language,
    DictionaryProfile? profile,
  }) async {
    final results = await lookup(
      text,
      maxResults: maxResults,
      scanLength: scanLength,
      language: language,
      profile: profile,
    );
    return List<HoshiLookupResult>.unmodifiable(
      results.map((result) {
        final glossaries = result.term.glossaries
            .where((entry) => entry.dictName == dictionary)
            .toList(growable: false);
        if (glossaries.isEmpty) return null;
        return HoshiLookupResult(
          matched: result.matched,
          deinflected: result.deinflected,
          trace: result.trace,
          preprocessorSteps: result.preprocessorSteps,
          term: HoshiTermResult(
            expression: result.term.expression,
            reading: result.term.reading,
            rules: result.term.rules,
            score: result.term.score,
            glossaries: glossaries,
            frequencies: result.term.frequencies,
            pitches: result.term.pitches,
          ),
        );
      }).nonNulls,
    );
  }

  @override
  Future<List<HoshiLookupResult>> lookupKanji(
    String text, {
    DictionaryProfile? profile,
  }) => _backend.lookupKanji(text, profile: profile);

  @override
  Future<List<HoshiDictionaryStyle>> getStyles({DictionaryProfile? profile}) =>
      _backend.getStyles(profile: profile);

  @override
  Future<Uint8List?> getMediaFile({
    required String dictName,
    required String mediaPath,
    DictionaryProfile? profile,
  }) => _backend.getMediaFile(
    dictName: dictName,
    mediaPath: mediaPath,
    profile: profile,
  );
}
