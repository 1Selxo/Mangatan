import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/eval/mihon/image_proxy.dart';

void main() {
  group('Mihon image proxy URLs', () {
    test('recognizes transient loopback image URLs', () {
      expect(
        isTransientMihonImageUrl('http://127.0.0.1:39641/image/6e7a9ad0-token'),
        isTrue,
      );
      expect(
        isTransientMihonImageUrl('http://[::1]:39641/image/token'),
        isTrue,
      );
      expect(
        isTransientMihonImageUrl('http://localhost:39641/image/token'),
        isTrue,
      );
    });

    test('does not classify ordinary image URLs as transient', () {
      expect(
        isTransientMihonImageUrl('https://cdn.example/image/page.jpg'),
        isFalse,
      );
      expect(
        isTransientMihonImageUrl('http://192.168.1.20:39641/image/token'),
        isFalse,
      );
      expect(
        containsTransientMihonImageUrl([
          'https://cdn.example/001.jpg',
          'https://cdn.example/002.jpg',
        ]),
        isFalse,
      );
    });

    test('recognizes legacy Mokuro CBZ-entry URLs as transient', () {
      expect(
        isTransientMihonImageUrl(
          'https://mokuro.moe/volume.cbz#%7B%22name%22:%22001.jpg%22%7D',
        ),
        isTrue,
      );
    });

    test('persists transient URLs for metadata but never reuses them', () {
      final proxyUrls = ['http://127.0.0.1:39641/image/token'];
      final ordinaryUrls = ['https://cdn.example/001.jpg'];

      expect(canReuseCachedMihonPageUrls(proxyUrls), isFalse);
      expect(canReuseCachedMihonPageUrls(ordinaryUrls), isTrue);
      expect(canReuseCachedMihonPageUrls(const []), isFalse);
    });
  });
}
