import 'dart:typed_data';
import 'dart:ui';

/// The colours a page's background takes with the "Automatic" background:
/// [top] and [bottom] for bars above and below the page, [left] and [right]
/// for bars beside it.
///
/// Above and below, this is Mihon's automatic background, which came from
/// TachiyomiJ2K (`ImageUtil.chooseBackground`): a dark page gets a dark
/// background taken from its own dark edge, a page dark only at the top or
/// the bottom gets dark there and white at the other end, any other page
/// white. Beside the page, each side takes its own colour from that edge, as
/// a desktop window shows a page fitted to its height with bars left and
/// right.
class SmartBackground {
  const SmartBackground({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
    required this.aspectRatio,
  });

  // shiori: a page background, white as Mihon's, not a theme colour
  static const white = Color(0xFFFFFFFF);

  final Color top;
  final Color bottom;
  final Color left;
  final Color right;

  /// The page's width over its height, to tell where its bars fall.
  final double aspectRatio;

  @override
  String toString() =>
      'SmartBackground(top: $top, bottom: $bottom, left: $left, '
      'right: $right, aspectRatio: $aspectRatio)';
}

/// Picks the background for a page from [rgba], straight RGBA pixels of an
/// image [stride] pixels wide, looking only at the [width] by [height]
/// region from ([x0], [y0]): the page, or the half of a split spread shown.
SmartBackground analyzeSmartBackground(
  Uint8List rgba, {
  required int stride,
  required int width,
  required int height,
  int x0 = 0,
  int y0 = 0,
}) {
  const white = SmartBackground.white;
  final aspectRatio = height == 0 ? 1.0 : width / height;
  if (width < 50 || height < 50) {
    return SmartBackground(
      top: white,
      bottom: white,
      left: white,
      right: white,
      aspectRatio: aspectRatio,
    );
  }
  final image = _Pixels(rgba, stride, x0, y0, width, height);

  final top = 5;
  final bot = height - 5;
  final left = (width * 0.0275).toInt();
  final right = width - left;
  final midX = width ~/ 2;
  final midY = height ~/ 2;
  final offsetX = (width * 0.01).toInt();
  final leftOffsetX = left - offsetX;
  final rightOffsetX = right + offsetX;

  final topLeft = image[(left, top)];
  final topRight = image[(right, top)];
  final midLeft = image[(left, midY)];
  final midRight = image[(right, midY)];
  final topCenter = image[(midX, top)];
  final botLeft = image[(left, bot)];
  final bottomCenter = image[(midX, bot)];
  final botRight = image[(right, bot)];

  // One colour, not white, all round the page: that colour.
  final ring = [topLeft, topCenter, topRight, botRight, bottomCenter, botLeft];
  final uniform = [
    for (var i = 0; i < ring.length; i++)
      !_isWhite(ring[i]) && _isCloseTo(ring[i], ring[(i + 1) % ring.length]),
  ].every((value) => value);

  final scans = <int, _ColumnScan>{
    for (final x in [left, right, leftOffsetX, rightOffsetX])
      x: _ColumnScan(image, x, width, offsetX),
  };

  final sides = (
    left: _sideColor(
      image,
      [scans[left]!, scans[leftOffsetX]!],
      left,
      top,
      midY,
      bot,
    ),
    right: _sideColor(
      image,
      [scans[right]!, scans[rightOffsetX]!],
      right,
      top,
      midY,
      bot,
    ),
  );

  if (uniform) {
    final color = _color(topLeft);
    return SmartBackground(
      top: color,
      bottom: color,
      left: sides.left ?? color,
      right: sides.right ?? color,
      aspectRatio: aspectRatio,
    );
  }

  var darkBG =
      (_isDark(topLeft) &&
          (_isDark(botLeft) ||
              _isDark(botRight) ||
              _isDark(topRight) ||
              _isDark(midLeft) ||
              _isDark(topCenter))) ||
      (_isDark(topRight) &&
          (_isDark(botRight) ||
              _isDark(botLeft) ||
              _isDark(midRight) ||
              _isDark(topCenter)));
  final whiteCorners = [
    topLeft,
    topRight,
    botLeft,
    botRight,
  ].where(_isWhite).length;
  if (whiteCorners >= 3) darkBG = false;

  var blackColor = [
    topLeft,
    topRight,
    botLeft,
    botRight,
  ].firstWhere(_isDark, orElse: () => _white);

  var overallWhite = 0;
  var overallBlack = 0;
  var topBlackStreak = 0;
  var topWhiteStreak = 0;
  var botBlackStreak = 0;
  var botWhiteStreak = 0;
  for (final x in [left, right, leftOffsetX, rightOffsetX]) {
    final scan = scans[x]!;
    final notOffset = x == left || x == right;
    if (notOffset) {
      overallWhite += scan.whiteCount;
      overallBlack += scan.blackCount;
    }
    if (scan.topWhiteStreak != null) topWhiteStreak = scan.topWhiteStreak!;
    if (scan.topBlackStreak != null) topBlackStreak = scan.topBlackStreak!;
    if (scan.botBlackStreak != null) {
      botBlackStreak = scan.botBlackStreak!;
    } else if (scan.botWhiteStreak != null) {
      botWhiteStreak = scan.botWhiteStreak!;
    }
    final isRight = x == right || x == rightOffsetX;
    int rightDark() => _isDark(topRight)
        ? topRight
        : _isDark(botRight)
        ? botRight
        : blackColor;
    if (scan.blackCount > 22) {
      if (isRight) blackColor = rightDark();
      darkBG = true;
      overallWhite = 0;
      break;
    } else if (scan.blackStreak) {
      darkBG = true;
      if (isRight) blackColor = rightDark();
      if (scan.blackCount > 18) {
        overallWhite = 0;
        break;
      }
    } else if (scan.whiteStreak || scan.whiteCount > 22) {
      darkBG = false;
    }
  }

  final topIsBlackStreak = topBlackStreak > topWhiteStreak;
  final bottomIsBlackStreak = botBlackStreak > botWhiteStreak;
  if (overallWhite > 9 && overallWhite > overallBlack) darkBG = false;
  if (topIsBlackStreak && bottomIsBlackStreak) darkBG = true;

  final dark = _color(blackColor);
  final botCornersWhite = _isWhite(botLeft) && _isWhite(botRight);
  final topCornersWhite = _isWhite(topLeft) && _isWhite(topRight);
  final topCornersDark = _isDark(topLeft) && _isDark(topRight);
  final botCornersDark = _isDark(botLeft) && _isDark(botRight);
  final topOffsetCornersDark =
      _isDark(image[(leftOffsetX, top)]) && _isDark(image[(rightOffsetX, top)]);
  final botOffsetCornersDark =
      _isDark(image[(leftOffsetX, bot)]) && _isDark(image[(rightOffsetX, bot)]);

  final (Color, Color) vertical;
  if (darkBG && botCornersWhite) {
    vertical = (dark, white);
  } else if (darkBG && topCornersWhite) {
    vertical = (white, dark);
  } else if (darkBG) {
    vertical = (dark, dark);
  } else if (topIsBlackStreak ||
      (topCornersDark &&
          topOffsetCornersDark &&
          (_isDark(topCenter) || overallBlack > 9))) {
    vertical = (dark, white);
  } else if (bottomIsBlackStreak ||
      (botCornersDark &&
          botOffsetCornersDark &&
          (_isDark(bottomCenter) || overallBlack > 9))) {
    vertical = (white, dark);
  } else {
    vertical = (white, white);
  }

  final whole = darkBG ? dark : white;
  return SmartBackground(
    top: vertical.$1,
    bottom: vertical.$2,
    left: sides.left ?? whole,
    right: sides.right ?? whole,
    aspectRatio: aspectRatio,
  );
}

/// The colour beside the page at one side, from the side's columns, by the
/// rules Mihon decides each column by: dark when mostly or in a long run
/// dark, white when mostly or in a long run white. One colour, not white,
/// down the whole side is that colour. Null when the side says neither.
Color? _sideColor(
  _Pixels image,
  List<_ColumnScan> scans,
  int x,
  int top,
  int midY,
  int bot,
) {
  final edge = [image[(x, top)], image[(x, midY)], image[(x, bot)]];
  if (edge.every((pixel) => !_isWhite(pixel)) &&
      _isCloseTo(edge[0], edge[1]) &&
      _isCloseTo(edge[1], edge[2])) {
    return _color(edge[1]);
  }
  final dark = scans.any((scan) => scan.blackCount > 22 || scan.blackStreak);
  final light = scans.any((scan) => scan.whiteStreak || scan.whiteCount > 22);
  if (dark && !light) {
    final darkPixel = edge.firstWhere(_isDark, orElse: () => _black);
    return _color(darkPixel);
  }
  if (light && !dark) return SmartBackground.white;
  return null;
}

/// One column of the page sampled top to bottom about 25 times, with each
/// pixel's neighbour further out, counting the white and dark ones and their
/// runs, as Mihon's automatic background does.
class _ColumnScan {
  _ColumnScan(_Pixels image, int x, int width, int offsetX) {
    final step = image.height ~/ 25;
    final neighbour = (x < width / 2 ? x - offsetX : x + offsetX).clamp(
      0,
      width - 1,
    );
    var whiteRun = 0;
    var blackRun = 0;
    var index = 0;
    for (var y = 0; y < image.height; y += step, index++) {
      final pixel = image[(x, y)];
      if (_isWhite(pixel)) {
        whiteRun++;
        whiteCount++;
        if (whiteRun > 14) whiteStreak = true;
        if (whiteRun > 6 && whiteRun >= index - 1) topWhiteStreak = whiteRun;
      } else {
        whiteRun = 0;
        if (_isDark(pixel) && _isDark(image[(neighbour, y)])) {
          blackCount++;
          blackRun++;
          if (blackRun >= 14) blackStreak = true;
          continue;
        }
      }
      if (blackRun > 6 && blackRun >= index - 1) topBlackStreak = blackRun;
      blackRun = 0;
    }
    if (blackRun > 6) {
      botBlackStreak = blackRun;
    } else if (whiteRun > 6) {
      botWhiteStreak = whiteRun;
    }
  }

  int whiteCount = 0;
  int blackCount = 0;
  bool whiteStreak = false;
  bool blackStreak = false;
  int? topWhiteStreak;
  int? topBlackStreak;
  int? botWhiteStreak;
  int? botBlackStreak;
}

const _white = 0xFFFFFFFF;
const _black = 0xFF000000;

/// A region of straight RGBA pixels, read as ARGB integers.
class _Pixels {
  _Pixels(this.rgba, this.stride, this.x0, this.y0, this.width, this.height);

  final Uint8List rgba;
  final int stride;
  final int x0;
  final int y0;
  final int width;
  final int height;

  int operator []((int, int) at) {
    final x = at.$1.clamp(0, width - 1) + x0;
    final y = at.$2.clamp(0, height - 1) + y0;
    final i = (y * stride + x) * 4;
    return (rgba[i + 3] << 24) |
        (rgba[i] << 16) |
        (rgba[i + 1] << 8) |
        rgba[i + 2];
  }
}

int _r(int argb) => (argb >> 16) & 0xFF;
int _g(int argb) => (argb >> 8) & 0xFF;
int _b(int argb) => argb & 0xFF;
int _a(int argb) => (argb >> 24) & 0xFF;

bool _isDark(int argb) =>
    _r(argb) < 40 && _g(argb) < 40 && _b(argb) < 40 && _a(argb) > 200;

bool _isWhite(int argb) => _r(argb) + _g(argb) + _b(argb) > 740;

bool _isCloseTo(int a, int b) =>
    (_r(a) - _r(b)).abs() < 30 &&
    (_g(a) - _g(b)).abs() < 30 &&
    (_b(a) - _b(b)).abs() < 30;

Color _color(int argb) => Color(argb | 0xFF000000);
