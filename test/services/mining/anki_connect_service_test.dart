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
}
