import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/utils/extensions/others.dart';

void main() {
  group('readerImageCacheFileKey', () {
    test('matches the provider key for a loopback Mihon proxy page', () {
      // CustomExtendedNetworkImageProvider stores this page under the md5 of
      // the port-less URL. OCR must find that same file.
      expect(
        readerImageCacheFileKey('http://127.0.0.1:54007/image/abc123?x=1'),
        keyToMd5('http://127.0.0.1/image/abc123?x=1'),
      );
    });

    test('is stable across bridge ports', () {
      expect(
        readerImageCacheFileKey('http://127.0.0.1:63886/image/token'),
        readerImageCacheFileKey('http://localhost:54595/image/token'),
      );
    });

    test('trims the URL like the reader does before caching', () {
      expect(
        readerImageCacheFileKey('  https://example.com/page/1.webp \n'),
        keyToMd5('https://example.com/page/1.webp'),
      );
    });

    test('leaves ordinary page URLs unchanged', () {
      const url = 'https://127.0.0.1.example.com:8443/image/1.png';
      expect(readerImageCacheFileKey(url), keyToMd5(url));
      expect(
        readerImageCacheFileKey('http://127.0.0.1:54007/video/abc'),
        keyToMd5('http://127.0.0.1:54007/video/abc'),
      );
    });
  });
}
