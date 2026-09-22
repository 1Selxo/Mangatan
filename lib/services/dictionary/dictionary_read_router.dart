import 'dart:typed_data';

import 'package:mangayomi/services/dictionary/dictionary_read_backend.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';

class DictionaryReadRouter implements DictionaryReadBackend {
  DictionaryReadRouter({
    required this.local,
    required this.remote,
    this.remoteEnabled = false,
  });

  final DictionaryReadBackend local;
  final DictionaryReadBackend remote;
  bool remoteEnabled;

  DictionaryReadBackend get _selected => remoteEnabled ? remote : local;

  @override
  Future<List<HoshiLookupResult>> lookup(
    String text, {
    int maxResults = 10,
    int scanLength = 20,
    String? language,
    DictionaryProfile? profile,
  }) => _selected.lookup(
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
  }) => _selected.lookupDictionary(
    text,
    dictionary: dictionary,
    maxResults: maxResults,
    scanLength: scanLength,
    language: language,
    profile: profile,
  );

  @override
  Future<List<HoshiLookupResult>> lookupKanji(
    String text, {
    DictionaryProfile? profile,
  }) => _selected.lookupKanji(text, profile: profile);

  @override
  Future<List<HoshiDictionaryStyle>> getStyles({DictionaryProfile? profile}) =>
      _selected.getStyles(profile: profile);

  @override
  Future<Uint8List?> getMediaFile({
    required String dictName,
    required String mediaPath,
    DictionaryProfile? profile,
  }) => _selected.getMediaFile(
    dictName: dictName,
    mediaPath: mediaPath,
    profile: profile,
  );
}
