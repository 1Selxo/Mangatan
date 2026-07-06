import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

class AnkiAudioService {
  // ignore: prefer_initializing_formals
  AnkiAudioService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<AnkiMediaFile?> fetchTermAudio({
    required String term,
    required String reading,
    required AnkiAudioPreferences preferences,
  }) async {
    if (!preferences.enabled || preferences.url.trim().isEmpty) return null;
    final client = _client ?? http.Client();
    try {
      final sourceUri = _templateUri(
        preferences.url,
        term: term,
        reading: reading,
        language: preferences.language,
      );
      return switch (preferences.sourceType) {
        AnkiAudioSourceType.customUrl => _downloadAudio(
          client,
          sourceUri,
          term: term,
          reading: reading,
          timeout: preferences.timeout,
        ),
        AnkiAudioSourceType.customJson => _fetchCustomJson(
          client,
          sourceUri,
          term: term,
          reading: reading,
          timeout: preferences.timeout,
        ),
      };
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<AnkiMediaFile?> _fetchCustomJson(
    http.Client client,
    Uri sourceUri, {
    required String term,
    required String reading,
    required Duration timeout,
  }) async {
    final response = await client.get(sourceUri).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['type'] != 'audioSourceList') return null;
    final rawSources = decoded['audioSources'];
    if (rawSources is! List) return null;
    for (final source in rawSources) {
      if (source is! Map) continue;
      final rawUrl = source['url']?.toString();
      if (rawUrl == null || rawUrl.trim().isEmpty) continue;
      final audioUri = sourceUri.resolve(rawUrl);
      final media = await _downloadAudio(
        client,
        audioUri,
        term: term,
        reading: reading,
        timeout: timeout,
      );
      if (media != null) return media;
    }
    return null;
  }

  Future<AnkiMediaFile?> _downloadAudio(
    http.Client client,
    Uri uri, {
    required String term,
    required String reading,
    required Duration timeout,
  }) async {
    final response = await client.get(uri).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final contentType = response.headers['content-type'] ?? '';
    if (!_looksLikeAudio(contentType, response.bodyBytes)) return null;
    final extension = _audioExtension(contentType, uri);
    return AnkiMediaFile(
      filename: _safeAudioFilename(term, reading, extension),
      bytes: Uint8List.fromList(response.bodyBytes),
    );
  }

  Uri _templateUri(
    String template, {
    required String term,
    required String reading,
    required String language,
  }) {
    final values = {'term': term, 'reading': reading, 'language': language};
    final raw = template.replaceAllMapped(RegExp(r'\{([^}]*)\}'), (match) {
      final key = match.group(1);
      return key != null && values.containsKey(key) ? values[key]! : match[0]!;
    });
    return Uri.parse(raw);
  }

  bool _looksLikeAudio(String contentType, List<int> bytes) {
    final type = contentType.toLowerCase();
    if (type.startsWith('audio/')) return true;
    if (bytes.length >= 3 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33) {
      return true;
    }
    if (bytes.length >= 4) {
      final magic = String.fromCharCodes(bytes.take(4)).toLowerCase();
      return magic == 'oggs' || magic == 'riff';
    }
    return false;
  }

  String _audioExtension(String contentType, Uri uri) {
    final type = contentType.split(';').first.trim().toLowerCase();
    final pathExtension = uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.last.split('.').last.toLowerCase();
    if (pathExtension.length >= 2 && pathExtension.length <= 5) {
      return pathExtension;
    }
    return switch (type) {
      'audio/mpeg' || 'audio/mp3' => 'mp3',
      'audio/ogg' || 'audio/opus' => 'ogg',
      'audio/wav' || 'audio/wave' || 'audio/x-wav' => 'wav',
      'audio/webm' => 'webm',
      'audio/mp4' || 'audio/aac' => 'm4a',
      _ => 'mp3',
    };
  }

  String _safeAudioFilename(String term, String reading, String extension) {
    final base = [term, reading]
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .replaceAll(RegExp(r'[\\/:*?"<>|\[\]]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final prefix = base.isEmpty ? 'mangayomi-audio' : base;
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}.$extension';
  }
}
