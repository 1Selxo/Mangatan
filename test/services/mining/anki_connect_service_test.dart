import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/services/mining/anki_connect_service.dart';
import 'package:mangayomi/services/mining/mining_models.dart';

void main() {
  test('uses non-persistent requests for repeated AnkiConnect calls', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.headers['connection'], 'close');
      expect(jsonDecode(request.body), {
        'action': 'version',
        'version': 6,
        'params': <String, dynamic>{},
      });
      return http.Response('{"result": 6, "error": null}', 200);
    });
    final service = AnkiConnectService(client: client);

    expect(await service.version(), 6);
    expect(await service.version(), 6);
    expect(calls, 2);
  });

  test(
    'allows Anki duplicates when export duplicate check is disabled',
    () async {
      final actions = <String>[];
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final action = body['action'] as String;
        actions.add(action);

        if (action == 'modelFieldNames') {
          return http.Response(
            '{"result": ["Front", "Back"], "error": null}',
            200,
          );
        }

        expect(action, 'addNote');
        final params = body['params'] as Map<String, dynamic>;
        final note = params['note'] as Map<String, dynamic>;
        final options = note['options'] as Map<String, dynamic>;
        expect(options['allowDuplicate'], isTrue);
        expect(note['fields'], {'Front': '猫', 'Back': 'cat'});
        return http.Response('{"result": 123, "error": null}', 200);
      });
      final service = AnkiConnectService(client: client);

      final noteId = await service.exportDraft(
        const AnkiCardDraft(
          deckName: 'Mining',
          modelName: 'Basic',
          expression: '猫',
          fields: {'Front': '猫', 'Back': 'cat'},
        ),
        duplicateCheck: false,
      );

      expect(noteId, 123);
      expect(actions, ['modelFieldNames', 'addNote']);
    },
  );

  test('uses Anki note validation for deck-root duplicate checks', () async {
    final actions = <String>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final action = body['action'] as String;
      actions.add(action);
      if (action == 'modelFieldNames') {
        return http.Response(
          '{"result": ["Expression", "Meaning"], "error": null}',
          200,
        );
      }
      expect(action, 'canAddNotesWithErrorDetail');
      final params = body['params'] as Map<String, dynamic>;
      final note = (params['notes'] as List).single as Map<String, dynamic>;
      expect(note['fields'], {'Expression': '事件', 'Meaning': ''});
      final options = note['options'] as Map<String, dynamic>;
      expect(options['duplicateScope'], 'deck');
      expect(options['allowDuplicate'], isFalse);
      expect(options['duplicateScopeOptions'], {
        'deckName': 'Japanese',
        'checkChildren': true,
        'checkAllModels': true,
      });
      return http.Response(
        '{"result": [{"canAdd": false, "error": "cannot create note because it is a duplicate"}], "error": null}',
        200,
      );
    });
    final service = AnkiConnectService(client: client);

    final result = await service.checkDuplicateExpression(
      deckName: 'Japanese::Mining',
      modelName: 'Mining',
      expression: '事件',
      duplicateScope: 'deckroot',
      checkAllModels: true,
    );

    expect(result.isDuplicate, isTrue);
    expect(actions, ['modelFieldNames', 'canAddNotesWithErrorDetail']);
  });

  test(
    'checks Anki duplicate rules across selected decks in one call',
    () async {
      final actions = <String>[];
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final action = body['action'] as String;
        actions.add(action);
        if (action == 'modelFieldNames') {
          return http.Response(
            '{"result": ["Expression", "Meaning"], "error": null}',
            200,
          );
        }
        expect(action, 'canAddNotesWithErrorDetail');
        final params = body['params'] as Map<String, dynamic>;
        final notes = params['notes'] as List;
        expect(notes.map((note) => (note as Map)['deckName']), [
          'Japanese::Mining',
          'Japanese::Archive',
          'Japanese::Reading',
        ]);
        for (final rawNote in notes) {
          final note = rawNote as Map<String, dynamic>;
          final options = note['options'] as Map<String, dynamic>;
          expect(options['duplicateScope'], 'deck');
          expect(
            (options['duplicateScopeOptions'] as Map)['deckName'],
            note['deckName'],
          );
        }
        return http.Response(
          '{"result": [{"canAdd": true, "error": null}, '
          '{"canAdd": false, "error": "duplicate"}, '
          '{"canAdd": true, "error": null}], "error": null}',
          200,
        );
      });

      final result = await AnkiConnectService(client: client)
          .checkDuplicateExpression(
            deckName: 'Japanese::Mining',
            modelName: 'Mining',
            expression: '事件',
            duplicateScope: 'decks',
            duplicateDeckNames: ['Japanese::Archive', 'Japanese::Reading'],
          );

      expect(result.isDuplicate, isTrue);
      expect(result.error, contains('Japanese::Archive'));
      expect(actions, ['modelFieldNames', 'canAddNotesWithErrorDetail']);
    },
  );

  test(
    'blocks an authoritative duplicate before adding media or a note',
    () async {
      final actions = <String>[];
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final action = body['action'] as String;
        actions.add(action);
        if (action == 'modelFieldNames') {
          return http.Response(
            '{"result": ["Front", "Back"], "error": null}',
            200,
          );
        }
        if (action == 'canAddNotesWithErrorDetail') {
          return http.Response(
            '{"result": [{"canAdd": false, "error": "duplicate"}], "error": null}',
            200,
          );
        }
        fail('Unexpected AnkiConnect action: $action');
      });
      final service = AnkiConnectService(client: client);

      await expectLater(
        service.exportDraft(
          const AnkiCardDraft(
            deckName: 'Mining',
            modelName: 'Basic',
            expression: '事件',
            fields: {'Front': '事件', 'Back': 'event'},
          ),
        ),
        throwsA(isA<AnkiDuplicateException>()),
      );
      expect(actions, ['modelFieldNames', 'canAddNotesWithErrorDetail']);
    },
  );

  test('surfaces non-duplicate validation failures as export errors', () async {
    final actions = <String>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final action = body['action'] as String;
      actions.add(action);
      return switch (action) {
        'modelFieldNames' => http.Response(
          '{"result": ["Front", "Back"], "error": null}',
          200,
        ),
        'canAddNotesWithErrorDetail' => http.Response(
          '{"result": [{"canAdd": false, "error": "cannot create note because it is empty"}], "error": null}',
          200,
        ),
        _ => throw StateError('Unexpected action: $action'),
      };
    });

    await expectLater(
      AnkiConnectService(client: client).exportDraft(
        const AnkiCardDraft(
          deckName: 'Mining',
          modelName: 'Basic',
          expression: '事件',
          fields: {'Front': '', 'Back': 'event'},
        ),
        allowDuplicate: true,
      ),
      throwsA(
        allOf(
          isA<AnkiConnectException>(),
          isNot(isA<AnkiDuplicateException>()),
          predicate(
            (error) => error.toString().contains('because it is empty'),
          ),
        ),
      ),
    );
    expect(actions, ['modelFieldNames', 'canAddNotesWithErrorDetail']);
  });

  test('blocks a pending card before running any media request', () async {
    final actions = <String>[];
    var preparations = 0;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final action = body['action'] as String;
      actions.add(action);
      return switch (action) {
        'modelFieldNames' => http.Response(
          '{"result": ["Front", "Back"], "error": null}',
          200,
        ),
        'canAddNotesWithErrorDetail' => http.Response(
          '{"result": [{"canAdd": false, "error": "duplicate"}], "error": null}',
          200,
        ),
        _ => throw StateError('Unexpected action: $action'),
      };
    });
    final pending = PendingAnkiCard(
      placeholderDraft: const AnkiCardDraft(
        deckName: 'Mining',
        modelName: 'Basic',
        expression: '事件',
        fields: {'Front': '事件', 'Back': ''},
      ),
      prepare: (_) async {
        preparations++;
        throw StateError('must not prepare a duplicate');
      },
    );

    await expectLater(
      AnkiConnectService(client: client).exportPending(pending),
      throwsA(isA<AnkiDuplicateException>()),
    );
    expect(preparations, 0);
    expect(actions, ['modelFieldNames', 'canAddNotesWithErrorDetail']);
  });

  test(
    'stores an animated scene first and falls back to the frozen still',
    () async {
      final actions = <String>[];
      final storedNames = <String>[];
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final action = body['action'] as String;
        actions.add(action);
        switch (action) {
          case 'modelFieldNames':
            return http.Response(
              '{"result": ["Front", "Back"], "error": null}',
              200,
            );
          case 'canAddNotesWithErrorDetail':
            return http.Response(
              '{"result": [{"canAdd": true, "error": null}], "error": null}',
              200,
            );
          case 'storeMediaFile':
            final filename =
                (body['params'] as Map<String, dynamic>)['filename'] as String;
            storedNames.add(filename);
            if (filename.endsWith('.avif')) {
              return http.Response(
                '{"result": null, "error": "storage failed"}',
                200,
              );
            }
            return http.Response('{"result": "scene.png", "error": null}', 200);
          case 'addNote':
            final note =
                (body['params'] as Map<String, dynamic>)['note']
                    as Map<String, dynamic>;
            expect(note['fields'], {
              'Front': '事件',
              'Back': '<img src="scene.png">',
            });
            return http.Response('{"result": 77, "error": null}', 200);
        }
        throw StateError('Unexpected action: $action');
      });
      final scene = AnkiScreenshotPreparation(
        filename: 'scene.avif',
        source: AnkiMediaSource.bytes(Uint8List.fromList([1, 2, 3])),
        fallbackFilename: 'scene.png',
        fallbackSource: AnkiMediaSource.bytes(Uint8List.fromList([4, 5, 6])),
        animated: true,
      );
      final pending = PendingAnkiCard(
        placeholderDraft: const AnkiCardDraft(
          deckName: 'Mining',
          modelName: 'Basic',
          expression: '事件',
          fields: {'Front': '事件', 'Back': ''},
        ),
        prepare: (_) async => PreparedAnkiCard(
          draft: AnkiCardDraft(
            deckName: 'Mining',
            modelName: 'Basic',
            expression: '事件',
            fields: const {'Front': '事件', 'Back': '<img src="scene.avif">'},
            screenshotFileName: scene.filename,
            screenshotSource: scene.source,
          ),
          screenshot: scene,
        ),
      );

      final result = await AnkiConnectService(
        client: client,
      ).exportPending(pending);

      expect(result.noteId, 77);
      expect(result.warnings.single, contains('frozen still'));
      expect(storedNames, ['scene.avif', 'scene.png']);
      expect(actions, [
        'modelFieldNames',
        'canAddNotesWithErrorDetail',
        'modelFieldNames',
        'storeMediaFile',
        'storeMediaFile',
        'addNote',
      ]);
    },
  );

  test('adds the note without an image when both media stores fail', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      switch (body['action']) {
        case 'modelFieldNames':
          return http.Response(
            '{"result": ["Front", "Back"], "error": null}',
            200,
          );
        case 'canAddNotesWithErrorDetail':
          return http.Response(
            '{"result": [{"canAdd": true, "error": null}], "error": null}',
            200,
          );
        case 'storeMediaFile':
          return http.Response(
            '{"result": null, "error": "storage failed"}',
            200,
          );
        case 'addNote':
          final note =
              (body['params'] as Map<String, dynamic>)['note']
                  as Map<String, dynamic>;
          expect(note['fields'], {'Front': '事件', 'Back': ''});
          return http.Response('{"result": 78, "error": null}', 200);
      }
      throw StateError('Unexpected action: ${body['action']}');
    });
    final scene = AnkiScreenshotPreparation(
      filename: 'scene.avif',
      source: AnkiMediaSource.bytes(Uint8List.fromList([1])),
      fallbackFilename: 'scene.png',
      fallbackSource: AnkiMediaSource.bytes(Uint8List.fromList([2])),
      animated: true,
    );
    final pending = PendingAnkiCard(
      placeholderDraft: const AnkiCardDraft(
        deckName: 'Mining',
        modelName: 'Basic',
        expression: '事件',
        fields: {'Front': '事件', 'Back': ''},
      ),
      prepare: (_) async => PreparedAnkiCard(
        draft: AnkiCardDraft(
          deckName: 'Mining',
          modelName: 'Basic',
          expression: '事件',
          fields: const {'Front': '事件', 'Back': '<img src="scene.avif">'},
          screenshotFileName: scene.filename,
          screenshotSource: scene.source,
        ),
        screenshot: scene,
      ),
    );

    final result = await AnkiConnectService(
      client: client,
    ).exportPending(pending);

    expect(result.noteId, 78);
    expect(result.warnings.single, contains('without an image'));
  });

  test('can add a known duplicate when the profile permits it', () async {
    final actions = <String>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final action = body['action'] as String;
      actions.add(action);
      if (action == 'modelFieldNames') {
        return http.Response(
          '{"result": ["Front", "Back"], "error": null}',
          200,
        );
      }
      if (action == 'canAddNotesWithErrorDetail') {
        return http.Response(
          '{"result": [{"canAdd": false, "error": "duplicate"}], "error": null}',
          200,
        );
      }
      expect(action, 'addNote');
      final params = body['params'] as Map<String, dynamic>;
      final note = params['note'] as Map<String, dynamic>;
      final options = note['options'] as Map<String, dynamic>;
      expect(options['allowDuplicate'], isTrue);
      expect(options['duplicateScope'], 'collection');
      return http.Response('{"result": 456, "error": null}', 200);
    });
    final service = AnkiConnectService(client: client);

    final noteId = await service.exportDraft(
      const AnkiCardDraft(
        deckName: 'Mining',
        modelName: 'Basic',
        expression: '事件',
        fields: {'Front': '事件', 'Back': 'event'},
      ),
      allowDuplicate: true,
      duplicateScope: 'collection',
    );

    expect(noteId, 456);
    expect(actions, [
      'modelFieldNames',
      'canAddNotesWithErrorDetail',
      'addNote',
    ]);
  });

  test(
    'finds duplicate note ids using Yomitan-compatible field queries',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        switch (body['action']) {
          case 'modelFieldNames':
            return http.Response(
              '{"result": ["Expression", "Meaning"], "error": null}',
              200,
            );
          case 'findNotes':
            expect(
              (body['params'] as Map<String, dynamic>)['query'],
              '"deck:Japanese" "note:Mining" "expression:事件"',
            );
            return http.Response('{"result": [41, 42], "error": null}', 200);
        }
        fail('Unexpected action: ${body['action']}');
      });

      final ids = await AnkiConnectService(client: client).findDuplicateNoteIds(
        deckName: 'Japanese::Mining',
        modelName: 'Mining',
        expression: '事件',
        duplicateScope: 'deckroot',
      );

      expect(ids, [41, 42]);
    },
  );

  test('finds duplicate note ids across selected decks', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      switch (body['action']) {
        case 'modelFieldNames':
          return http.Response(
            '{"result": ["Expression", "Meaning"], "error": null}',
            200,
          );
        case 'findNotes':
          expect(
            (body['params'] as Map<String, dynamic>)['query'],
            '("deck:Japanese::Mining" or "deck:Japanese::Archive") '
            '"expression:事件"',
          );
          return http.Response('{"result": [51], "error": null}', 200);
      }
      fail('Unexpected action: ${body['action']}');
    });

    final ids = await AnkiConnectService(client: client).findDuplicateNoteIds(
      deckName: 'Japanese::Mining',
      modelName: 'Mining',
      expression: '事件',
      duplicateScope: 'decks',
      duplicateDeckNames: ['Japanese::Archive'],
      checkAllModels: true,
    );

    expect(ids, [51]);
  });

  test('opens matching notes in the Anki card browser', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['action'], 'guiBrowse');
      expect(body['params'], {'query': 'nid:41,42'});
      return http.Response('{"result": [101, 102], "error": null}', 200);
    });

    final cards = await AnkiConnectService(
      client: client,
    ).browseNotes([41, 42]);

    expect(cards, [101, 102]);
  });
}
