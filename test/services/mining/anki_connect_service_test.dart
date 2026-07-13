import 'dart:convert';

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
              '"deck:Japanese" "expression:事件"',
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
