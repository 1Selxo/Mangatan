import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/services/mining/anki_connect_service.dart';

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
}
