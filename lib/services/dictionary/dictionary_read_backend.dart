import 'dart:typed_data';

import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';

abstract interface class DictionaryReadBackend {
  Future<List<HoshiLookupResult>> lookup(
    String text, {
    int maxResults = 10,
    int scanLength = 20,
    String? language,
    DictionaryProfile? profile,
  });

  Future<List<HoshiLookupResult>> lookupDictionary(
    String text, {
    required String dictionary,
    int maxResults = 10,
    int scanLength = 20,
    String? language,
    DictionaryProfile? profile,
  });

  Future<List<HoshiLookupResult>> lookupKanji(
    String text, {
    DictionaryProfile? profile,
  });

  Future<List<HoshiDictionaryStyle>> getStyles({DictionaryProfile? profile});

  Future<Uint8List?> getMediaFile({
    required String dictName,
    required String mediaPath,
    DictionaryProfile? profile,
  });
}
