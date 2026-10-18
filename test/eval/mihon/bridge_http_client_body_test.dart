import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/eval/mihon/bridge_http_client.dart';

/// The exact bytes the bridge receives must not depend on when the request
/// bodies are encoded.
void main() {
  test('sends byte-identical full, handle and retry bodies', () async {
    const firstId =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
    const secondId =
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
    final uri = Uri.parse('https://exact-body.example/dalvik');
    final bodies = <String>[];
    final client = MockClient((request) async {
      bodies.add(request.body);
      if (bodies.length == 3) {
        return http.Response('{"error":"gone","code":409}', 409);
      }
      return http.Response(
        '{}',
        200,
        headers: {
          'x-mangatan-extension-id': bodies.length < 3 ? firstId : secondId,
        },
      );
    });
    Map<String, Object?> body() => {
      'method': 'getDetailsManga',
      'mangaData': {'url': '/series/1', 'title': 'Ünïcode "quoted"'},
      'preferences': [
        {'key': 'a', 'value': 1},
      ],
      'data': 'apk-${'x' * 100}',
      'page': 2,
    };

    await postMihonBridge(client, uri, body: body());
    await postMihonBridge(client, uri, body: body());
    await postMihonBridge(client, uri, body: body());

    final full = jsonEncode(body());
    final small = jsonEncode(
      Map<String, Object?>.of(body())
        ..remove('data')
        ..['extensionId'] = firstId,
    );
    expect(bodies, [full, small, small, full]);
  });

  test('sends a string body unchanged', () async {
    final uri = Uri.parse('https://string-body.example/dalvik');
    final bodies = <String>[];
    final client = MockClient((request) async {
      bodies.add(request.body);
      return http.Response('{}', 200);
    });
    const raw = '{"method":"getPopularManga",  "data":"apk-bytes"}';

    await postMihonBridge(client, uri, body: raw);

    expect(bodies, [raw]);
  });

  group('recognizes HTML responses', () {
    Future<bool> rejectsAsHtml(String responseBody) async {
      final client = MockClient(
        (request) async => http.Response(
          responseBody,
          200,
          headers: const {'content-type': 'application/json'},
        ),
      );
      try {
        await postMihonBridge(
          client,
          Uri.parse('http://192.168.1.20:8080/dalvik'),
        );
        return false;
      } on MihonBridgeResponseException {
        return true;
      }
    }

    test('after a long run of whitespace', () async {
      expect(await rejectsAsHtml('${' \n\t' * 400}<HTML><body>'), isTrue);
      expect(await rejectsAsHtml('${' ' * 255}<!DOCTYPE HTML><html>'), isTrue);
      expect(await rejectsAsHtml('${' ' * 250}<!doctype htm'), isFalse);
    });

    test('in any letter case, and only at the start', () async {
      expect(await rejectsAsHtml('<!DoCtYpE hTmL>'), isTrue);
      expect(await rejectsAsHtml('<HtMl>'), isTrue);
      expect(await rejectsAsHtml('{"html":"<html>"}'), isFalse);
      expect(await rejectsAsHtml('x<html>'), isFalse);
      expect(await rejectsAsHtml(''), isFalse);
      expect(await rejectsAsHtml('   '), isFalse);
    });
  });
}
