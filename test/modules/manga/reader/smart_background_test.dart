import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/manga/reader/utils/smart_background.dart';

const _w = 400, _h = 600;
const _white = Color(0xFFFFFFFF);

/// A [_w] by [_h] page, each pixel coloured by [paint].
Uint8List _page(Color Function(int x, int y) paint) {
  final rgba = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final c = paint(x, y);
      final i = (y * _w + x) * 4;
      rgba
        ..[i] = (c.r * 255).round()
        ..[i + 1] = (c.g * 255).round()
        ..[i + 2] = (c.b * 255).round()
        ..[i + 3] = 255;
    }
  }
  return rgba;
}

SmartBackground _analyze(Uint8List rgba) =>
    analyzeSmartBackground(rgba, stride: _w, width: _w, height: _h);

/// A grey drawing in the middle, the margins in [margin].
Color Function(int, int) _drawnOn(Color margin) =>
    (x, y) => x > 60 && x < _w - 60 && y > 60 && y < _h - 60
    ? const Color(0xFF808080)
    : margin;

void main() {
  test('a page with white margins is white all round', () {
    final bg = _analyze(_page(_drawnOn(_white)));
    expect([bg.top, bg.bottom, bg.left, bg.right], everyElement(_white));
    expect(bg.aspectRatio, closeTo(_w / _h, 1e-9));
  });

  test('a dark scene goes dark, in the page\'s own dark', () {
    const dark = Color(0xFF101010);
    final bg = _analyze(_page(_drawnOn(dark)));
    expect([bg.top, bg.bottom, bg.left, bg.right], everyElement(dark));
  });

  test('a page dark at the top only is dark above and white below', () {
    final bg = _analyze(
      _page((x, y) => y < _h * 0.4 ? const Color(0xFF000000) : _white),
    );
    expect(bg.top, const Color(0xFF000000));
    expect(bg.bottom, _white);
  });

  test('each side beside the page takes its own edge', () {
    // Black down the left edge, white down the right.
    final bg = _analyze(
      _page((x, y) => x < _w / 2 ? const Color(0xFF000000) : _white),
    );
    expect(bg.left, const Color(0xFF000000));
    expect(bg.right, _white);
  });

  test('one non-white colour all round the page is that colour', () {
    const sepia = Color(0xFFC8B48C);
    final bg = _analyze(_page(_drawnOn(sepia)));
    expect([bg.top, bg.bottom, bg.left, bg.right], everyElement(sepia));
  });

  test('a small image stays white', () {
    final bg = analyzeSmartBackground(
      Uint8List(40 * 40 * 4),
      stride: 40,
      width: 40,
      height: 40,
    );
    expect([bg.top, bg.bottom, bg.left, bg.right], everyElement(_white));
  });

  test('a region reads only its part of the image', () {
    // The left half is the dark page of a split spread.
    final rgba = _page((x, y) => x < _w / 2 ? const Color(0xFF000000) : _white);
    final half = analyzeSmartBackground(
      rgba,
      stride: _w,
      width: _w ~/ 2,
      height: _h,
    );
    expect([
      half.top,
      half.bottom,
      half.left,
      half.right,
    ], everyElement(const Color(0xFF000000)));
  });
}
