import 'dart:typed_data';

import 'package:mangayomi/services/hoshidicts/dictionary_storage.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';
import 'package:mangayomi/src/rust/api/hoshidicts/native.dart' as hoshidicts;

class HoshidictsLookupBackend {
  HoshidictsLookupBackend._();

  static final HoshidictsLookupBackend instance = HoshidictsLookupBackend._();

  // Hovering commonly revisits nearby words, so retain a small LRU without
  // holding an entire subtitle or chapter's materialized glossary data.
  static const _maxCachedLookups = 32;

  hoshidicts.HoshiLookupSession? _session;
  Future<hoshidicts.HoshiLookupSession>? _initializing;
  bool _configured = false;
  int _queryGeneration = 0;
  final Map<_LookupRequest, List<HoshiLookupResult>> _lookupCache = {};
  final Map<_LookupRequest, Future<List<HoshiLookupResult>>> _lookupsInFlight =
      {};
  List<HoshiDictionaryStyle>? _cachedStyles;
  Future<List<HoshiDictionaryStyle>>? _stylesInFlight;

  bool get hasSession => _session != null;

  Future<HoshiImportResult> importDictionary({
    required String zipPath,
    required String outputDir,
    bool lowRam = false,
  }) {
    return hoshidicts.importDictionary(
      zipPath: zipPath,
      outputDir: outputDir,
      lowRam: lowRam,
    );
  }

  Future<void> rebuildQuery({
    required List<String> termPaths,
    List<String> freqPaths = const [],
    List<String> pitchPaths = const [],
  }) async {
    final pending = _initializing;
    if (pending != null) await pending;
    _configured = false;
    _invalidateQueryCaches();

    late final Future<hoshidicts.HoshiLookupSession> rebuilding;
    rebuilding =
        _rebuildQuery(
          termPaths: termPaths,
          freqPaths: freqPaths,
          pitchPaths: pitchPaths,
        ).whenComplete(() {
          if (identical(_initializing, rebuilding)) _initializing = null;
        });
    _initializing = rebuilding;
    await rebuilding;
  }

  Future<void> reloadFromStorage() async {
    _configured = false;
    _invalidateQueryCaches();
    await _ensureSession();
  }

  Future<List<HoshiLookupResult>> lookup(
    String text, {
    int maxResults = 10,
    int scanLength = 20,
  }) async {
    final query = text.trim();
    if (query.isEmpty || maxResults <= 0 || scanLength <= 0) {
      return const [];
    }

    final request = _LookupRequest(query, maxResults, scanLength);
    final cached = _lookupCache.remove(request);
    if (cached != null) {
      _lookupCache[request] = cached;
      return cached;
    }

    final pending = _lookupsInFlight[request];
    if (pending != null) return pending;

    final generation = _queryGeneration;
    final lookup = _performLookup(request, generation);
    _lookupsInFlight[request] = lookup;
    return lookup;
  }

  Future<List<HoshiDictionaryStyle>> getStyles() async {
    final cached = _cachedStyles;
    if (cached != null) return cached;
    final pending = _stylesInFlight;
    if (pending != null) return pending;

    final generation = _queryGeneration;
    final styles = _loadStyles(generation);
    _stylesInFlight = styles;
    return styles;
  }

  Future<Uint8List?> getMediaFile({
    required String dictName,
    required String mediaPath,
  }) async {
    if (dictName.isEmpty || mediaPath.isEmpty) return null;
    return hoshidicts.getMediaFile(
      session: await _ensureSession(),
      dictName: dictName,
      mediaPath: mediaPath,
    );
  }

  void clearSession() {
    _session = null;
    _initializing = null;
    _configured = false;
    _invalidateQueryCaches();
  }

  Future<hoshidicts.HoshiLookupSession> _ensureSession() async {
    final session = _session;
    if (session != null && _configured) return session;

    final pending = _initializing;
    if (pending != null) return pending;

    late final Future<hoshidicts.HoshiLookupSession> initialization;
    initialization = _initializeFromStorage().whenComplete(() {
      if (identical(_initializing, initialization)) {
        _initializing = null;
      }
    });
    _initializing = initialization;
    return initialization;
  }

  Future<hoshidicts.HoshiLookupSession> _initializeFromStorage() async {
    final paths = await DictionaryStorage.instance.paths();
    return _rebuildQuery(
      termPaths: paths.termPaths,
      freqPaths: paths.frequencyPaths,
      pitchPaths: paths.pitchPaths,
    );
  }

  Future<hoshidicts.HoshiLookupSession> _rebuildQuery({
    required List<String> termPaths,
    required List<String> freqPaths,
    required List<String> pitchPaths,
  }) async {
    final session = _session ??= await hoshidicts.createLookupSession();
    await hoshidicts.rebuildQuery(
      session: session,
      termPaths: termPaths,
      freqPaths: freqPaths,
      pitchPaths: pitchPaths,
    );
    _configured = true;
    return session;
  }

  Future<List<HoshiLookupResult>> _performLookup(
    _LookupRequest request,
    int generation,
  ) async {
    try {
      final results = List<HoshiLookupResult>.unmodifiable(
        await hoshidicts.lookup(
          session: await _ensureSession(),
          text: request.text,
          maxResults: request.maxResults,
          scanLength: BigInt.from(request.scanLength),
        ),
      );
      if (generation == _queryGeneration) {
        _lookupCache[request] = results;
        while (_lookupCache.length > _maxCachedLookups) {
          _lookupCache.remove(_lookupCache.keys.first);
        }
      }
      return results;
    } finally {
      if (generation == _queryGeneration) _lookupsInFlight.remove(request);
    }
  }

  Future<List<HoshiDictionaryStyle>> _loadStyles(int generation) async {
    try {
      final styles = List<HoshiDictionaryStyle>.unmodifiable(
        await hoshidicts.getStyles(session: await _ensureSession()),
      );
      if (generation == _queryGeneration) _cachedStyles = styles;
      return styles;
    } finally {
      if (generation == _queryGeneration) _stylesInFlight = null;
    }
  }

  void _invalidateQueryCaches() {
    _queryGeneration++;
    _lookupCache.clear();
    _lookupsInFlight.clear();
    _cachedStyles = null;
    _stylesInFlight = null;
  }
}

class _LookupRequest {
  const _LookupRequest(this.text, this.maxResults, this.scanLength);

  final String text;
  final int maxResults;
  final int scanLength;

  @override
  bool operator ==(Object other) =>
      other is _LookupRequest &&
      other.text == text &&
      other.maxResults == maxResults &&
      other.scanLength == scanLength;

  @override
  int get hashCode => Object.hash(text, maxResults, scanLength);
}
