import 'dart:async';
import 'dart:typed_data';

import 'package:mangayomi/services/dictionary/dictionary_read_backend.dart';
import 'package:mangayomi/services/hachidori/hachidori_models.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';

class HachidoriDictionaryBackend implements DictionaryReadBackend {
  HachidoriDictionaryBackend(this._client) {
    _events = _client.libraryEvents.listen((_) => clearCaches());
  }

  static const _maxLookupCacheEntries = 32;
  static const _maxMediaCacheEntries = 64;

  final HachidoriReadClient _client;
  late final StreamSubscription<HachidoriLibraryEvent> _events;
  final Map<_LookupKey, List<HoshiLookupResult>> _lookupCache = {};
  final Map<_LookupKey, Future<List<HoshiLookupResult>>> _lookupsInFlight = {};
  final Map<String, List<HoshiLookupResult>> _kanjiCache = {};
  final Map<String, Future<List<HoshiLookupResult>>> _kanjiInFlight = {};
  final Map<_MediaKey, Uint8List?> _mediaCache = {};
  final Map<_MediaKey, Future<Uint8List?>> _mediaInFlight = {};
  List<HoshiDictionaryStyle>? _stylesCache;
  Future<List<HoshiDictionaryStyle>>? _stylesInFlight;
  int _cacheGeneration = 0;

  @override
  Future<List<HoshiLookupResult>> lookup(
    String text, {
    int maxResults = 10,
    int scanLength = 20,
    String? language,
    DictionaryProfile? profile,
  }) {
    final query = text.trim();
    if (query.isEmpty || maxResults <= 0 || scanLength <= 0) {
      return Future.value(const []);
    }
    return _lookup(
      _LookupKey(query, null, maxResults, scanLength),
      () => _client.lookup(
        query,
        maxResults: maxResults,
        scanLength: scanLength,
        options: _lookupOptions,
      ),
    );
  }

  @override
  Future<List<HoshiLookupResult>> lookupDictionary(
    String text, {
    required String dictionary,
    int maxResults = 10,
    int scanLength = 20,
    String? language,
    DictionaryProfile? profile,
  }) {
    final query = text.trim();
    final dictionaryName = dictionary.trim();
    if (query.isEmpty ||
        dictionaryName.isEmpty ||
        maxResults <= 0 ||
        scanLength <= 0) {
      return Future.value(const []);
    }
    return _lookup(
      _LookupKey(query, dictionaryName, maxResults, scanLength),
      () => _client.lookupDictionary(
        query,
        dictionary: dictionaryName,
        maxResults: maxResults,
        scanLength: scanLength,
        options: _lookupOptions,
      ),
    );
  }

  Future<List<HoshiLookupResult>> _lookup(
    _LookupKey key,
    Future<List<HoshiLookupResult>> Function() load,
  ) {
    final cached = _lookupCache.remove(key);
    if (cached != null) {
      _lookupCache[key] = cached;
      return Future.value(cached);
    }
    final pending = _lookupsInFlight[key];
    if (pending != null) return pending;

    final generation = _cacheGeneration;
    late final Future<List<HoshiLookupResult>> future;
    future = load()
        .then((results) {
          final frozen = List<HoshiLookupResult>.unmodifiable(results);
          if (generation == _cacheGeneration) {
            _lookupCache[key] = frozen;
            while (_lookupCache.length > _maxLookupCacheEntries) {
              _lookupCache.remove(_lookupCache.keys.first);
            }
          }
          return frozen;
        })
        .whenComplete(() {
          if (identical(_lookupsInFlight[key], future)) {
            _lookupsInFlight.remove(key);
          }
        });
    _lookupsInFlight[key] = future;
    return future;
  }

  @override
  Future<List<HoshiLookupResult>> lookupKanji(
    String text, {
    DictionaryProfile? profile,
  }) {
    final query = text.trim();
    if (query.isEmpty) return Future.value(const []);
    final cached = _kanjiCache.remove(query);
    if (cached != null) {
      _kanjiCache[query] = cached;
      return Future.value(cached);
    }
    final pending = _kanjiInFlight[query];
    if (pending != null) return pending;

    final generation = _cacheGeneration;
    late final Future<List<HoshiLookupResult>> future;
    future = _client
        .lookupKanji(query)
        .then((results) {
          final frozen = List<HoshiLookupResult>.unmodifiable(results);
          if (generation == _cacheGeneration) {
            _kanjiCache[query] = frozen;
            while (_kanjiCache.length > _maxLookupCacheEntries) {
              _kanjiCache.remove(_kanjiCache.keys.first);
            }
          }
          return frozen;
        })
        .whenComplete(() {
          if (identical(_kanjiInFlight[query], future)) {
            _kanjiInFlight.remove(query);
          }
        });
    _kanjiInFlight[query] = future;
    return future;
  }

  @override
  Future<List<HoshiDictionaryStyle>> getStyles({DictionaryProfile? profile}) {
    final cached = _stylesCache;
    if (cached != null) return Future.value(cached);
    final pending = _stylesInFlight;
    if (pending != null) return pending;

    final generation = _cacheGeneration;
    late final Future<List<HoshiDictionaryStyle>> future;
    future = _client
        .styles()
        .then((styles) {
          final frozen = List<HoshiDictionaryStyle>.unmodifiable(styles);
          if (generation == _cacheGeneration) _stylesCache = frozen;
          return frozen;
        })
        .whenComplete(() {
          if (identical(_stylesInFlight, future)) _stylesInFlight = null;
        });
    _stylesInFlight = future;
    return future;
  }

  @override
  Future<Uint8List?> getMediaFile({
    required String dictName,
    required String mediaPath,
    DictionaryProfile? profile,
  }) {
    if (dictName.isEmpty || mediaPath.isEmpty) return Future.value();
    final key = _MediaKey(dictName, mediaPath);
    if (_mediaCache.containsKey(key)) {
      final cached = _mediaCache.remove(key);
      _mediaCache[key] = cached;
      return Future.value(cached);
    }
    final pending = _mediaInFlight[key];
    if (pending != null) return pending;

    final generation = _cacheGeneration;
    late final Future<Uint8List?> future;
    future = _client
        .media(dictionary: dictName, path: mediaPath)
        .then((bytes) {
          final frozen = bytes == null ? null : Uint8List.fromList(bytes);
          if (generation == _cacheGeneration) {
            _mediaCache[key] = frozen;
            while (_mediaCache.length > _maxMediaCacheEntries) {
              _mediaCache.remove(_mediaCache.keys.first);
            }
          }
          return frozen;
        })
        .onError((error, stackTrace) {
          clearCaches();
          Error.throwWithStackTrace(
            error ?? StateError('Remote media request failed.'),
            stackTrace,
          );
        })
        .whenComplete(() {
          if (identical(_mediaInFlight[key], future)) {
            _mediaInFlight.remove(key);
          }
        });
    _mediaInFlight[key] = future;
    return future;
  }

  HachidoriLookupOptions get _lookupOptions {
    final raw = _client.state.snapshot['options'];
    if (raw is! Map) return const HachidoriLookupOptions();
    final frequencyDictionary = raw['frequencyDictionary'];
    final primaryReading = raw['primaryReading'];
    final order = raw['frequencyOrder'];
    return HachidoriLookupOptions(
      frequencyDictionary: frequencyDictionary is String
          ? frequencyDictionary
          : '',
      frequencyOrder: HachidoriFrequencyOrder.values.firstWhere(
        (candidate) => candidate.name == order,
        orElse: () => HachidoriFrequencyOrder.auto,
      ),
      primaryReading: primaryReading is String ? primaryReading : '',
    );
  }

  void clearCaches() {
    _cacheGeneration++;
    _lookupCache.clear();
    _lookupsInFlight.clear();
    _kanjiCache.clear();
    _kanjiInFlight.clear();
    _stylesCache = null;
    _stylesInFlight = null;
    _mediaCache.clear();
    _mediaInFlight.clear();
  }

  void dispose() {
    clearCaches();
    unawaited(_events.cancel());
  }
}

class _LookupKey {
  const _LookupKey(
    this.text,
    this.dictionary,
    this.maxResults,
    this.scanLength,
  );

  final String text;
  final String? dictionary;
  final int maxResults;
  final int scanLength;

  @override
  bool operator ==(Object other) =>
      other is _LookupKey &&
      text == other.text &&
      dictionary == other.dictionary &&
      maxResults == other.maxResults &&
      scanLength == other.scanLength;

  @override
  int get hashCode => Object.hash(text, dictionary, maxResults, scanLength);
}

class _MediaKey {
  const _MediaKey(this.dictionary, this.path);

  final String dictionary;
  final String path;

  @override
  bool operator ==(Object other) =>
      other is _MediaKey &&
      dictionary == other.dictionary &&
      path == other.path;

  @override
  int get hashCode => Object.hash(dictionary, path);
}
