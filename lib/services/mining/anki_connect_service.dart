import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mangayomi/services/mining/mining_models.dart';

class AnkiConnectException implements Exception {
  final String message;
  const AnkiConnectException(this.message);

  @override
  String toString() => message;
}

class AnkiConnectService {
  final Uri endpoint;
  final http.Client? _injectedClient;

  AnkiConnectService({Uri? endpoint, http.Client? client})
    : endpoint = endpoint ?? Uri.parse('http://127.0.0.1:8765'),
      _injectedClient = client;

  Future<dynamic> invoke(
    String action, {
    Map<String, dynamic> params = const {},
  }) async {
    // AnkiConnect closes idle HTTP/1.1 sockets without advertising it. Dart's
    // pooled client can then reuse that stale socket and fail on the next
    // request with Windows error 10053. Use a one-shot connection by default.
    final client = _injectedClient ?? http.Client();
    late final http.Response response;
    try {
      response = await client
          .post(
            endpoint,
            headers: const {
              'content-type': 'application/json',
              'connection': 'close',
            },
            body: jsonEncode({
              'action': action,
              'version': 6,
              'params': params,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      throw AnkiConnectException(
        'Could not reach AnkiConnect at $endpoint. Make sure Anki is open and the AnkiConnect add-on is installed. ($error)',
      );
    } finally {
      if (_injectedClient == null) client.close();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AnkiConnectException(
        'AnkiConnect HTTP ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final error = decoded['error'];
    if (error != null) {
      throw AnkiConnectException(error.toString());
    }
    return decoded['result'];
  }

  Future<int> version() async {
    final result = await invoke('version');
    return result is int ? result : int.tryParse(result.toString()) ?? 0;
  }

  Future<List<String>> deckNames() async {
    final result = await invoke('deckNames');
    return (result as List).map((item) => item.toString()).toList();
  }

  Future<List<String>> modelNames() async {
    final result = await invoke('modelNames');
    return (result as List).map((item) => item.toString()).toList();
  }

  Future<List<String>> modelFieldNames(String modelName) async {
    if (modelName.trim().isEmpty) return const [];
    final result = await invoke(
      'modelFieldNames',
      params: {'modelName': modelName},
    );
    return (result as List).map((item) => item.toString()).toList();
  }

  Future<List<int>> findNotes(String query) async {
    final result = await invoke('findNotes', params: {'query': query});
    return (result as List).map((item) => item as int).toList();
  }

  Future<String?> storeMediaFile({
    required String filename,
    required Uint8List data,
  }) async {
    final result = await invoke(
      'storeMediaFile',
      params: {'filename': filename, 'data': base64Encode(data)},
    );
    return result?.toString();
  }

  Future<int> addNote(
    AnkiCardDraft draft, {
    bool allowDuplicate = false,
  }) async {
    final result = await invoke(
      'addNote',
      params: {
        'note': {
          'deckName': draft.deckName,
          'modelName': draft.modelName,
          'fields': draft.fields,
          'tags': draft.tags,
          'options': {
            'allowDuplicate': allowDuplicate,
            'duplicateScope': 'deck',
            'duplicateScopeOptions': {
              'deckName': draft.deckName,
              'checkChildren': false,
              'checkAllModels': false,
            },
          },
        },
      },
    );
    if (result == null) {
      throw const AnkiConnectException('AnkiConnect did not return a note id.');
    }
    return result as int;
  }

  Future<void> sync() async {
    await invoke('sync');
  }

  Future<List<int>> findDuplicateExpressions({
    required String deckName,
    required String expression,
  }) {
    final escapedDeck = deckName.replaceAll('"', r'\"');
    final escapedExpression = expression.replaceAll('"', r'\"');
    return findNotes('deck:"$escapedDeck" "$escapedExpression"');
  }

  Future<int> exportDraft(
    AnkiCardDraft draft, {
    bool duplicateCheck = true,
    bool syncOnCreate = false,
  }) async {
    final normalized = await _normalizeFieldsForModel(draft);
    for (final media in normalized.mediaFiles) {
      await storeMediaFile(filename: media.filename, data: media.bytes);
    }
    if (normalized.screenshotBytes != null &&
        normalized.screenshotFileName != null) {
      await storeMediaFile(
        filename: normalized.screenshotFileName!,
        data: normalized.screenshotBytes!,
      );
    }
    if (duplicateCheck) {
      final existing = await findDuplicateExpressions(
        deckName: normalized.deckName,
        expression: normalized.expression,
      );
      if (existing.isNotEmpty) {
        throw AnkiConnectException(
          'A card for "${normalized.expression}" already exists.',
        );
      }
    }
    final noteId = await addNote(normalized, allowDuplicate: !duplicateCheck);
    if (syncOnCreate) await sync();
    return noteId;
  }

  Future<AnkiCardDraft> _normalizeFieldsForModel(AnkiCardDraft draft) async {
    final modelFields = await modelFieldNames(draft.modelName);
    if (modelFields.isEmpty) return draft;
    return AnkiCardDraft(
      deckName: draft.deckName,
      modelName: draft.modelName,
      expression: draft.expression,
      fields: {
        for (final field in modelFields) field: draft.fields[field] ?? '',
      },
      tags: draft.tags,
      screenshotFileName: draft.screenshotFileName,
      screenshotBytes: draft.screenshotBytes,
      mediaFiles: draft.mediaFiles,
    );
  }
}
