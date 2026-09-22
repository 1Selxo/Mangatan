import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/hachidori/hachidori_protocol.dart';

void main() {
  group('Hachidori link addresses', () {
    test('normalizes local, host, port, and full WebSocket inputs', () {
      expect(
        HachidoriLinkAddress.parse(''),
        const HachidoriLinkAddress(
          uri: 'ws://127.0.0.1:8771/link',
          display: 'this computer',
        ),
      );
      expect(
        HachidoriLinkAddress.parse('hachidori.local'),
        const HachidoriLinkAddress(
          uri: 'ws://hachidori.local:8771/link',
          display: 'hachidori.local',
        ),
      );
      expect(
        HachidoriLinkAddress.parse('192.168.1.20:9000'),
        const HachidoriLinkAddress(
          uri: 'ws://192.168.1.20:9000/link',
          display: '192.168.1.20:9000',
        ),
      );
      expect(
        HachidoriLinkAddress.parse('ws://example.test:8771/link'),
        const HachidoriLinkAddress(
          uri: 'ws://example.test:8771/link',
          display: 'example.test',
        ),
      );
      expect(
        HachidoriLinkAddress.parse('localhost'),
        const HachidoriLinkAddress(
          uri: 'ws://127.0.0.1:8771/link',
          display: 'this computer',
        ),
      );
    });

    test('rejects unsupported schemes, paths, and missing hosts', () {
      for (final value in const [
        'https://example.test',
        'wss://example.test/link',
        'ws://example.test/host',
        'ws:///link',
        'example.test/other',
      ]) {
        expect(
          () => HachidoriLinkAddress.parse(value),
          throwsA(isA<FormatException>()),
          reason: value,
        );
      }
    });
  });
}
