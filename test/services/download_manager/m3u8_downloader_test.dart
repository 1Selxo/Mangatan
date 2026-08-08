import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/download_manager/m3u8/m3u8_downloader.dart';

void main() {
  test('resolves ordinary playlist references relative to the playlist', () {
    expect(
      resolveM3u8Reference(
        'https://cdn.example/video/master.m3u8',
        'segments/1.ts',
      ),
      'https://cdn.example/video/segments/1.ts',
    );
    expect(
      resolveM3u8Reference(
        'https://cdn.example/video/master.m3u8',
        '/segments/1.ts',
      ),
      'https://cdn.example/segments/1.ts',
    );
  });

  test('roots Mihon video proxy references at the video route', () {
    expect(
      resolveM3u8Reference(
        'http://127.0.0.1:54758/video/master-token',
        'video/variant-token.m3u8',
      ),
      'http://127.0.0.1:54758/video/variant-token.m3u8',
    );
    expect(
      resolveM3u8Reference(
        'http://127.0.0.1:54758/video/master-token.m3u8',
        '/video/segment-token.ts',
      ),
      'http://127.0.0.1:54758/video/segment-token.ts',
    );
  });

  test('selects the highest-bandwidth master playlist variant', () {
    const body = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000
low/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2400000
high/index.m3u8
''';

    expect(
      selectM3u8VariantUrl('https://cdn.example/master.m3u8', body),
      'https://cdn.example/high/index.m3u8',
    );
    expect(
      selectM3u8VariantUrl(
        'https://cdn.example/media.m3u8',
        '#EXTM3U\n#EXTINF:4,\nsegment.ts\n',
      ),
      isNull,
    );
  });
}
