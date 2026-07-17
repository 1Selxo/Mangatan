import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mangayomi/services/mining/mokuro_parser.dart';

class MokuroDocument {
  const MokuroDocument({
    required this.uri,
    required this.bytes,
    required this.volume,
  });

  final Uri uri;
  final Uint8List bytes;
  final MokuroVolume volume;
}

/// Loads the pre-generated OCR published by the Mokuro Mihon extension.
///
/// A volume is shared by every page in a chapter, so successful responses are
/// cached by URL to avoid downloading and parsing the same `.mokuro` file for
/// each page the reader preloads.
class MokuroExtensionOcrClient {
  MokuroExtensionOcrClient({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const catalogUrl = 'https://mokuro.moe/catalog';
  static const _requestTimeout = Duration(seconds: 30);
  static const _maxCachedVolumes = 6;
  static final Map<Uri, Future<MokuroDocument?>> _documentCache = {};

  final http.Client _client;
  final bool _ownsClient;

  static Uri? volumeUri({
    required String sourceName,
    required String chapterUrl,
  }) {
    if (sourceName.trim().toLowerCase() != 'mokuro') return null;

    final separator = chapterUrl.indexOf('|');
    if (separator <= 0 || separator == chapterUrl.length - 1) return null;
    final seriesPath = chapterUrl.substring(0, separator);
    final volumeName = chapterUrl.substring(separator + 1);

    // Uri path segments match OkHttp's addPathSegment used by Chimahon. In
    // particular, slashes within an extension-provided name remain encoded.
    return Uri(
      scheme: 'https',
      host: 'mokuro.moe',
      pathSegments: ['mokuro-reader', seriesPath, '$volumeName.mokuro'],
    );
  }

  Future<MokuroVolume?> fetchVolume({
    required String sourceName,
    required String chapterUrl,
    void Function(bool loading)? onLoadingChanged,
  }) async {
    final document = await fetchDocument(
      sourceName: sourceName,
      chapterUrl: chapterUrl,
      onLoadingChanged: onLoadingChanged,
    );
    return document?.volume;
  }

  /// Returns both the parsed volume and its original bytes. Keeping the raw
  /// response lets downloads persist a byte-identical `.mokuro` sidecar
  /// without dropping fields that this parser does not currently use.
  Future<MokuroDocument?> fetchDocument({
    required String sourceName,
    required String chapterUrl,
    void Function(bool loading)? onLoadingChanged,
  }) async {
    final uri = volumeUri(sourceName: sourceName, chapterUrl: chapterUrl);
    if (uri == null) return null;

    final cached = _documentCache[uri];
    if (cached != null) return _resolve(uri, cached);

    onLoadingChanged?.call(true);
    final pending = _fetch(uri);
    _documentCache[uri] = pending;
    _trimCache(uri);
    try {
      return await _resolve(uri, pending);
    } finally {
      onLoadingChanged?.call(false);
    }
  }

  static Future<MokuroDocument?> _resolve(
    Uri uri,
    Future<MokuroDocument?> pending,
  ) async {
    try {
      final document = await pending;
      if (document == null && identical(_documentCache[uri], pending)) {
        _documentCache.remove(uri);
      }
      return document;
    } catch (_) {
      if (identical(_documentCache[uri], pending)) {
        _documentCache.remove(uri);
      }
      return null;
    }
  }

  Future<MokuroDocument?> _fetch(Uri uri) async {
    final response = await _client
        .get(uri, headers: const {'Referer': catalogUrl})
        .timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    try {
      // mokuro.moe serves these files as application/octet-stream without a
      // charset. Decode the JSON bytes explicitly so http does not fall back
      // to Latin-1 and corrupt Japanese text.
      final bytes = response.bodyBytes;
      final volume = const MokuroParser().parse(utf8.decode(bytes));
      if (volume.pages.isEmpty) return null;
      return MokuroDocument(uri: uri, bytes: bytes, volume: volume);
    } catch (_) {
      return null;
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  static void clearCache() => _documentCache.clear();

  static void _trimCache(Uri current) {
    while (_documentCache.length > _maxCachedVolumes) {
      final oldest = _documentCache.keys.firstWhere(
        (uri) => uri != current,
        orElse: () => current,
      );
      if (oldest == current) return;
      _documentCache.remove(oldest);
    }
  }
}
