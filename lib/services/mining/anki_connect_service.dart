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

class AnkiDuplicateException extends AnkiConnectException {
  AnkiDuplicateException(String expression, [String? detail])
    : super(
        detail == null || detail.isEmpty
            ? 'A card for "$expression" already exists.'
            : detail,
      );
}

class AnkiCanAddResult {
  const AnkiCanAddResult({required this.canAdd, this.error});

  final bool canAdd;
  final String? error;

  bool get isDuplicate => !canAdd;
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

  Future<List<int>> findDuplicateNoteIds({
    required String deckName,
    required String modelName,
    required String expression,
    String duplicateScope = 'deck',
  }) async {
    final fields = await modelFieldNames(modelName);
    if (fields.isEmpty || expression.trim().isEmpty) return const [];
    final escapedDeck = _escapeSearch(deckName);
    final rootDeck = _escapeSearch(deckName.split('::').first);
    final escapedExpression = _escapeSearch(expression);
    final scope = switch (duplicateScope) {
      'collection' => '',
      'deckroot' => '"deck:$rootDeck" ',
      _ => '"deck:$escapedDeck" ',
    };
    return findNotes(
      '$scope"${fields.first.toLowerCase()}:$escapedExpression"',
    );
  }

  Future<List<int>> browseNotes(List<int> noteIds) async {
    if (noteIds.isEmpty) return const [];
    final result = await invoke(
      'guiBrowse',
      params: {'query': 'nid:${noteIds.join(',')}'},
    );
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
    String duplicateScope = 'deck',
    bool checkAllModels = false,
  }) async {
    final result = await invoke(
      'addNote',
      params: {
        'note': {
          'deckName': draft.deckName,
          'modelName': draft.modelName,
          'fields': draft.fields,
          'tags': draft.tags,
          'options': _duplicateOptions(
            deckName: draft.deckName,
            allowDuplicate: allowDuplicate,
            duplicateScope: duplicateScope,
            checkAllModels: checkAllModels,
          ),
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

  /// Uses Anki's own duplicate validator, matching Hoshi Reader and Yomitan.
  /// This is more accurate than a text search because Anki evaluates the
  /// actual model's first field and configured duplicate scope.
  Future<AnkiCanAddResult> canAddDraft(
    AnkiCardDraft draft, {
    String duplicateScope = 'deck',
    bool checkAllModels = false,
  }) async {
    final normalized = await _normalizeFieldsForModel(draft);
    return _canAddNormalizedDraft(
      normalized,
      duplicateScope: duplicateScope,
      checkAllModels: checkAllModels,
    );
  }

  Future<AnkiCanAddResult> checkDuplicateExpression({
    required String deckName,
    required String modelName,
    required String expression,
    String duplicateScope = 'deck',
    bool checkAllModels = false,
  }) async {
    final fields = await modelFieldNames(modelName);
    if (fields.isEmpty) return const AnkiCanAddResult(canAdd: true);
    return _canAddNormalizedDraft(
      AnkiCardDraft(
        deckName: deckName,
        modelName: modelName,
        expression: expression,
        fields: {
          for (final field in fields)
            field: field == fields.first ? expression : '',
        },
      ),
      duplicateScope: duplicateScope,
      checkAllModels: checkAllModels,
    );
  }

  Future<int> exportDraft(
    AnkiCardDraft draft, {
    bool duplicateCheck = true,
    bool allowDuplicate = false,
    String duplicateScope = 'deck',
    bool checkAllModels = false,
    bool syncOnCreate = false,
  }) async {
    final normalized = await _normalizeFieldsForModel(draft);
    if (duplicateCheck) {
      final status = await _canAddNormalizedDraft(
        normalized,
        duplicateScope: duplicateScope,
        checkAllModels: checkAllModels,
      );
      if (!status.canAdd && !allowDuplicate) {
        throw AnkiDuplicateException(normalized.expression, status.error);
      }
    }
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
    final noteId = await addNote(
      normalized,
      allowDuplicate: allowDuplicate || !duplicateCheck,
      duplicateScope: duplicateScope,
      checkAllModels: checkAllModels,
    );
    if (syncOnCreate) await sync();
    return noteId;
  }

  Future<AnkiCanAddResult> _canAddNormalizedDraft(
    AnkiCardDraft draft, {
    required String duplicateScope,
    required bool checkAllModels,
  }) async {
    final result = await invoke(
      'canAddNotesWithErrorDetail',
      params: {
        'notes': [
          {
            'deckName': draft.deckName,
            'modelName': draft.modelName,
            'fields': draft.fields,
            'tags': draft.tags,
            'options': _duplicateOptions(
              deckName: draft.deckName,
              allowDuplicate: false,
              duplicateScope: duplicateScope,
              checkAllModels: checkAllModels,
            ),
          },
        ],
      },
    );
    if (result is! List || result.isEmpty || result.first is! Map) {
      throw const AnkiConnectException(
        'AnkiConnect returned an invalid duplicate-check response.',
      );
    }
    final first = result.first as Map;
    return AnkiCanAddResult(
      canAdd: first['canAdd'] == true,
      error: first['error']?.toString(),
    );
  }

  static Map<String, dynamic> _duplicateOptions({
    required String deckName,
    required bool allowDuplicate,
    required String duplicateScope,
    required bool checkAllModels,
  }) {
    final normalizedScope = switch (duplicateScope) {
      'collection' => 'collection',
      'deckroot' => 'deckroot',
      _ => 'deck',
    };
    final options = <String, dynamic>{
      'allowDuplicate': allowDuplicate,
      'duplicateScope': normalizedScope == 'collection' ? 'collection' : 'deck',
    };
    if (normalizedScope != 'collection' || checkAllModels) {
      options['duplicateScopeOptions'] = <String, dynamic>{
        if (normalizedScope != 'collection')
          'deckName': normalizedScope == 'deckroot'
              ? deckName.split('::').first
              : deckName,
        if (normalizedScope != 'collection')
          'checkChildren': normalizedScope == 'deckroot',
        'checkAllModels': checkAllModels,
      };
    }
    return options;
  }

  static String _escapeSearch(String value) => value.replaceAll('"', '');

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
