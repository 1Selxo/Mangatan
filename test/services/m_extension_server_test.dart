import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/m_extension_server.dart';

void main() {
  group('embedded iOS Mihon bridge response', () {
    test('accepts a valid loopback port', () {
      expect(
        embeddedMihonBaseUrlFromResponse({
          'port': 49321,
          'baseUrl': 'http://127.0.0.1:49321',
        }),
        'http://127.0.0.1:49321',
      );
    });

    test('constructs the URL when native code only returns a port', () {
      expect(
        embeddedMihonBaseUrlFromResponse({'port': 8080}),
        'http://127.0.0.1:8080',
      );
    });

    test('rejects remote, invalid, and mismatched responses', () {
      expect(
        embeddedMihonBaseUrlFromResponse({
          'port': 8080,
          'baseUrl': 'https://bridge.example',
        }),
        isNull,
      );
      expect(
        embeddedMihonBaseUrlFromResponse({
          'port': 8080,
          'baseUrl': 'http://127.0.0.1:8081',
        }),
        isNull,
      );
      expect(embeddedMihonBaseUrlFromResponse({'port': 0}), isNull);
      expect(embeddedMihonBaseUrlFromResponse({'port': 70000}), isNull);
    });
  });
}
