import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/anime/utils/subtitle_track_support.dart';

void main() {
  test('recognizes supported bitmap subtitle codecs', () {
    for (final codec in [
      'hdmv_pgs_subtitle',
      'dvd_subtitle',
      'dvb_subtitle',
      'xsub',
      'HDMV_PGS_SUBTITLE',
    ]) {
      expect(isBitmapSubtitleCodec(codec), isTrue, reason: codec);
    }
  });

  test('leaves text, unknown, and absent subtitle codecs on custom path', () {
    for (final codec in ['ass', 'subrip', 'webvtt', 'unknown', '', null]) {
      expect(isBitmapSubtitleCodec(codec), isFalse, reason: '$codec');
    }
  });
}
