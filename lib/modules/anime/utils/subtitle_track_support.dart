import 'package:media_kit/media_kit.dart';

const bitmapSubtitleCodecs = <String>{
  'hdmv_pgs_subtitle',
  'dvd_subtitle',
  'dvb_subtitle',
  'xsub',
};

bool isBitmapSubtitleCodec(String? codec) {
  return bitmapSubtitleCodecs.contains(codec?.trim().toLowerCase());
}

Future<String?> activeSubtitleCodec(Player player) async {
  final fallback = player.state.track.subtitle.codec;
  final platform = player.platform;
  if (platform is! NativePlayer) return fallback;
  try {
    final codec = await platform.getProperty('current-tracks/sub/codec');
    if (codec.trim().isNotEmpty) return codec.trim();
  } catch (_) {}
  return fallback;
}

Future<bool> updateNativeSubtitleVisibility(Player player) async {
  final bitmap = isBitmapSubtitleCodec(await activeSubtitleCodec(player));
  final platform = player.platform;
  if (platform is NativePlayer) {
    await platform.setProperty('sub-visibility', bitmap ? 'yes' : 'no');
  }
  return bitmap;
}
