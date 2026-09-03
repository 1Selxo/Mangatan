import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mangayomi/services/mining/hayai_ocr.dart';

void main() {
  test('normalizes the Hayai endpoint exactly once', () {
    expect(
      normalizeHayaiEndpoint(Uri.parse('http://127.0.0.1:8766/')).toString(),
      'http://127.0.0.1:8766/v1/ocr',
    );
    expect(
      normalizeHayaiEndpoint(Uri.parse('https://ocr.example/v1/ocr'))
          .toString(),
      'https://ocr.example/v1/ocr',
    );
  });

  test('normalizes whitespace between CJK characters', () {
    expect(normalizeHayaiText(' 学 校\nです '), '学校です');
  });

  test('sends an optional bearer key and parses text', () async {
    final transport = _FakeClient();
    final client = HayaiOcrClient(
      endpoint: Uri.parse('http://localhost:8766'),
      apiKey: 'secret',
      client: transport,
    );

    expect(await client.recognize(Uint8List.fromList([1, 2, 3])), '日本語');
    expect(transport.request?.url.path, '/v1/ocr');
    expect(transport.request?.headers['authorization'], 'Bearer secret');
  });
}

class _FakeClient extends http.BaseClient {
  http.BaseRequest? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request;
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"text":"日 本 語"}')),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
