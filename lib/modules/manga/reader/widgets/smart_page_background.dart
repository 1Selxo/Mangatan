import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/manga/reader/subsampling_scale_image_view/subsampling_scale_image_view.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/manga/reader/utils/smart_background.dart';
import 'package:mangayomi/modules/manga/reader/widgets/color_filter_widget.dart';
import 'package:mangayomi/utils/extensions/others.dart';
import 'package:mangayomi/utils/log/logger.dart';
import 'package:shiori/shiori.dart';

/// Each page's background, worked out once.
final _found = Expando<Future<SmartBackground?>>('smart page background');

/// The backgrounds already worked out, to be shown from a page's first frame
/// rather than faded into from white.
final _ready = Expando<SmartBackground>('smart page background ready');

/// The "Automatic" background of [page]; null when its image cannot be read
/// yet, to be asked for again.
Future<SmartBackground?> smartBackgroundOf(UChapDataPreload page) =>
    _found[page] ??= _analyze(page).then((background) {
      if (background == null) {
        _found[page] = null;
      } else {
        _ready[page] = background;
      }
      return background;
    });

/// The pages looked at ahead of time, one after another, so the page shown
/// is never kept waiting behind them for long.
Future<void> _prefetching = Future.value();

/// Works out the backgrounds of the pages [radius] either side of [index]
/// in [pages] before they are turned to, nearest first.
void prefetchSmartBackgrounds(
  List<UChapDataPreload> pages,
  int index, {
  int radius = 3,
}) {
  for (var distance = 1; distance <= radius; distance++) {
    for (final i in [index + distance, index - distance]) {
      if (i < 0 || i >= pages.length) continue;
      final page = pages[i];
      if (_ready[page] != null || _found[page] != null) continue;
      _prefetching = _prefetching.then((_) => smartBackgroundOf(page));
    }
  }
}

/// How wide the copy of a page that is looked at is, at most: enough for
/// the edges Mihon samples, cheap to decode.
const _sampleWidth = 720;

Future<SmartBackground?> _analyze(UChapDataPreload page) async {
  if (page.isTransitionPage) return null;
  try {
    // The image file may still be on its way when the page is first shown.
    String? path;
    for (var attempt = 0; attempt < 4; attempt++) {
      if (attempt > 0) await Future.delayed(const Duration(milliseconds: 700));
      path = page.resolvedFilePath ?? await page.getLocalFilePath;
      if (path != null && await File(path).exists()) break;
      path = null;
    }
    // Decoded as the reader decodes it, so a page that shows can be read;
    // Flutter's own decoder, for the rest.
    if (path != null) {
      final found = await _analyzeFile(path, page.srcRect);
      if (found != null) return found;
    }
    final bytes = path != null
        ? await File(path).readAsBytes()
        : await page.getImageBytes;
    if (bytes == null) {
      _logMiss(page, 'no image yet');
      return null;
    }
    return await _analyzeBytes(bytes, page.srcRect);
  } catch (error) {
    _logMiss(page, error);
    return null;
  }
}

void _logMiss(UChapDataPreload page, Object reason) => AppLogger.log(
  'Automatic background: page ${page.index} not read: $reason',
  logLevel: LogLevel.warning,
);

/// The region of an image [width] by [height] that [srcRect] shows, all of
/// it without one.
Rect _regionOf(Rect? srcRect, num width, num height) {
  final whole = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  return srcRect?.intersect(whole) ?? whole;
}

/// [path] through the native decoder, at most [_sampleWidth] wide.
Future<SmartBackground?> _analyzeFile(String path, Rect? srcRect) async {
  final dims = await ffiImageDecoder.getImageDimensionsAsync(path);
  if (dims == null || dims[0] <= 0 || dims[1] <= 0) return null;
  final region = _regionOf(srcRect, dims[0], dims[1]);
  final left = region.left.round();
  final top = region.top.round();
  final right = region.right.round();
  final bottom = region.bottom.round();
  var sampleSize = 1;
  while ((right - left) ~/ (sampleSize * 2) >= _sampleWidth) {
    sampleSize *= 2;
  }
  final result = await ffiImageDecoder.decodeRegionAsync(
    DecodeParams(
      filePath: path,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      sampleSize: sampleSize,
    ),
  );
  final address = result?.pointerAddress;
  if (address == null) return null;
  final width = (right - left) ~/ sampleSize;
  final height = (bottom - top) ~/ sampleSize;
  final pointer = Pointer<Uint8>.fromAddress(address);
  try {
    final rgba = Uint8List.fromList(pointer.asTypedList(width * height * 4));
    return analyzeSmartBackground(
      rgba,
      stride: width,
      width: width,
      height: height,
    );
  } finally {
    calloc.free(pointer);
  }
}

/// [bytes] through Flutter's decoder, at most [_sampleWidth] wide.
Future<SmartBackground?> _analyzeBytes(Uint8List bytes, Rect? srcRect) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final fullWidth = descriptor.width;
  final codec = await descriptor.instantiateCodec(
    targetWidth: min(fullWidth, _sampleWidth),
  );
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final width = image.width;
  final height = image.height;
  image.dispose();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  if (data == null) return null;
  // Half of a split spread: only that half.
  var region = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  if (srcRect != null && fullWidth > 0) {
    final scale = width / fullWidth;
    region = Rect.fromLTRB(
      srcRect.left * scale,
      srcRect.top * scale,
      srcRect.right * scale,
      srcRect.bottom * scale,
    ).intersect(region);
  }
  return analyzeSmartBackground(
    data.buffer.asUint8List(),
    stride: width,
    x0: region.left.round(),
    y0: region.top.round(),
    width: region.width.round(),
    height: region.height.round(),
  );
}

/// The "Automatic" background behind [child], picked from [pages], the
/// pages shown left to right: see [SmartBackground]. Bars beside the pages
/// take each side's colour, the left from the left page and the right from
/// the right one; bars above and below take the top and bottom colours.
/// It fades from page to page, filtered as the pages are.
class SmartPageBackground extends ConsumerStatefulWidget {
  const SmartPageBackground({
    super.key,
    required this.pages,
    required this.child,
  });

  final List<UChapDataPreload> pages;
  final Widget child;

  @override
  ConsumerState<SmartPageBackground> createState() =>
      _SmartPageBackgroundState();
}

/// The last background shown, for a page whose own is not known yet: a run
/// of dark pages stays dark rather than flashing white between them.
LinearGradient _lastShown = _plain;

class _SmartPageBackgroundState extends ConsumerState<SmartPageBackground> {
  List<SmartBackground?> _backgrounds = const [];
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _complete =>
      _backgrounds.length == widget.pages.length &&
      _backgrounds.every((background) => background != null);

  @override
  void didUpdateWidget(covariant SmartPageBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    final samePages =
        oldWidget.pages.length == widget.pages.length &&
        [
          for (var i = 0; i < widget.pages.length; i++)
            identical(oldWidget.pages[i], widget.pages[i]),
        ].every((same) => same);
    if (!samePages) _load();
  }

  Future<void> _load({int retry = 0}) async {
    final generation = ++_generation;
    _backgrounds = [for (final page in widget.pages) _ready[page]];
    if (_complete) return;
    final backgrounds = await Future.wait(widget.pages.map(smartBackgroundOf));
    if (!mounted || generation != _generation) return;
    setState(() => _backgrounds = backgrounds);
    // A page not read yet, such as one still downloading, is asked for
    // again a few times rather than left on the last colour shown.
    if (!_complete && retry < 5) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && generation == _generation) _load(retry: retry + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gradient = _complete
            ? _gradient(_backgrounds.cast(), constraints.biggest)
            : _lastShown;
        _lastShown = gradient;
        return Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<LinearGradient>(
              tween: _GradientTween(end: gradient),
              duration: ShioriMotion.enter,
              builder: (context, gradient, _) =>
                  ReaderBackgroundFill(gradient: gradient),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

/// White, as Mihon starts; four stops like every other background here, so
/// one fades into the next.
const _plain = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    SmartBackground.white,
    SmartBackground.white,
    SmartBackground.white,
    SmartBackground.white,
  ],
);

LinearGradient _gradient(List<SmartBackground> pages, Size view) {
  // Pages side by side are as high as each other; their widths add up.
  final aspectRatio = pages.fold(0.0, (sum, page) => sum + page.aspectRatio);
  final barsBeside = view.height > 0 && aspectRatio < view.width / view.height;
  if (barsBeside) {
    final left = pages.first.left;
    final right = pages.last.right;
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [left, left, right, right],
    );
  }
  // Above and below a spread, a colour both pages agree on.
  Color agreed(Iterable<Color> colors) =>
      colors.toSet().length == 1 ? colors.first : SmartBackground.white;
  final top = agreed(pages.map((page) => page.top));
  final bottom = agreed(pages.map((page) => page.bottom));
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [top, top, bottom, bottom],
  );
}

/// Fades one background into the next.
class _GradientTween extends Tween<LinearGradient> {
  _GradientTween({required LinearGradient end}) : super(begin: end, end: end);

  @override
  LinearGradient lerp(double t) => LinearGradient.lerp(begin, end, t)!;
}
