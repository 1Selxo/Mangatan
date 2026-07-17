import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/webview_url.dart';

void main() {
  group('resolveSourceUrl', () {
    test('preserves an absolute source URL', () {
      expect(
        resolveSourceUrl(
          baseUrl: 'https://source.example',
          url: 'https://cdn.example/title?chapter=1#page',
        ),
        'https://cdn.example/title?chapter=1#page',
      );
    });

    test('joins a root-relative URL without duplicate slashes', () {
      expect(
        resolveSourceUrl(baseUrl: 'https://source.example/', url: '/title/1'),
        'https://source.example/title/1',
      );
    });

    test('joins a relative URL when the base has no trailing slash', () {
      expect(
        resolveSourceUrl(baseUrl: 'https://source.example', url: 'title/1'),
        'https://source.example/title/1',
      );
    });

    test('retains query and fragment components', () {
      expect(
        resolveSourceUrl(
          baseUrl: 'https://source.example',
          url: '/title/1?lang=kr#reader',
        ),
        'https://source.example/title/1?lang=kr#reader',
      );
    });
  });
}
