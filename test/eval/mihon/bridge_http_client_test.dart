import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/eval/mihon/bridge_http_client.dart';

void main() {
  group('Mihon bridge HTTP client', () {
    test('normalizes APKBridge base URLs', () {
      expect(
        normalizeMihonBridgeBaseUrl('192.168.1.20'),
        'http://192.168.1.20:8080',
      );
      expect(
        normalizeMihonBridgeBaseUrl('http://192.168.1.20:3710/dalvik/'),
        'http://192.168.1.20:3710',
      );
      expect(
        mihonBridgeDalvikUri('http://192.168.1.20/').toString(),
        'http://192.168.1.20:8080/dalvik',
      );
      expect(
        mihonBridgeDalvikUri('https://bridge.example/base///').toString(),
        'https://bridge.example/dalvik',
      );
      expect(
        normalizeMihonBridgeBaseUrl('https://bridge.mangayomi.30062022.xyz/'),
        'https://bridge.mangayomi.30062022.xyz',
      );
      expect(
        mihonBridgeDalvikUri(
          'https://bridge.mangayomi.30062022.xyz/',
        ).toString(),
        'https://bridge.mangayomi.30062022.xyz/dalvik',
      );
      expect(
        () => mihonBridgeDalvikUri('ftp://192.168.1.20'),
        throwsFormatException,
      );
    });

    test('recognizes only local bridge endpoints as loopback', () {
      expect(isLoopbackMihonBridge('http://127.0.0.1:3710'), isTrue);
      expect(isLoopbackMihonBridge('http://localhost:3710'), isTrue);
      expect(isLoopbackMihonBridge('http://[::1]:3710'), isTrue);
      expect(isLoopbackMihonBridge('http://192.168.1.20:3710'), isFalse);
    });

    test(
      'retries transient local transport failures with bounded delays',
      () async {
        var requests = 0;
        final delays = <Duration>[];
        final client = MockClient((request) async {
          requests++;
          if (requests <= mihonBridgeRetryDelays.length) {
            throw http.ClientException('connection refused', request.url);
          }
          return http.Response('ok', 200);
        });

        final response = await postMihonBridge(
          client,
          Uri.parse('http://127.0.0.1:3710/dalvik'),
          retryTransientFailures: true,
          delay: (duration) async => delays.add(duration),
        );

        expect(response.body, 'ok');
        expect(requests, mihonBridgeRetryDelays.length + 1);
        expect(delays, mihonBridgeRetryDelays);
      },
    );

    test('does not retry a remote bridge or application error', () async {
      var remoteRequests = 0;
      final remoteClient = MockClient((request) async {
        remoteRequests++;
        throw http.ClientException('connection refused', request.url);
      });

      await expectLater(
        postMihonBridge(
          remoteClient,
          Uri.parse('http://192.168.1.20:3710/dalvik'),
        ),
        throwsA(isA<http.ClientException>()),
      );
      expect(remoteRequests, 1);

      var applicationRequests = 0;
      final applicationClient = MockClient((request) async {
        applicationRequests++;
        throw const FormatException('invalid response');
      });
      await expectLater(
        postMihonBridge(
          applicationClient,
          Uri.parse('http://127.0.0.1:3710/dalvik'),
          retryTransientFailures: true,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(applicationRequests, 1);
    });

    test('turns an HTML response into an actionable bridge error', () async {
      final client = MockClient(
        (request) async => http.Response(
          '<html>not APKBridge</html>',
          200,
          headers: const {'content-type': 'text/html'},
        ),
      );

      await expectLater(
        postMihonBridge(client, Uri.parse('http://192.168.1.20:8080/dalvik')),
        throwsA(
          isA<MihonBridgeResponseException>()
              .having(
                (error) => error.message,
                'message',
                contains('not APKBridge'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('port 8080'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('hosted HTTPS bridges'),
              ),
        ),
      );
    });
  });
}
