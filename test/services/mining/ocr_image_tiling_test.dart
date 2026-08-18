import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/ocr_image_tiling.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';

void main() {
  test('keeps ordinary pages in one OCR request', () {
    final tiles = planVerticalOcrTiles(width: 1200, height: 1800);

    expect(tiles, hasLength(1));
    expect(tiles.single.top, 0);
    expect(tiles.single.height, 1800);
    expect(tiles.single.coreBottom, 1800);
  });

  test('covers tall pages with overlapping crops and continuous cores', () {
    final tiles = planVerticalOcrTiles(width: 800, height: 6000);

    expect(tiles.length, greaterThan(1));
    expect(tiles.first.top, 0);
    expect(tiles.last.bottom, 6000);
    for (var index = 0; index < tiles.length - 1; index++) {
      expect(tiles[index].bottom, greaterThan(tiles[index + 1].top));
      expect(tiles[index].coreBottom, tiles[index + 1].coreTop);
    }
  });

  test('remaps owned tile blocks and rejects overlap duplicates', () {
    const tile = OcrVerticalTile(
      top: 800,
      height: 1000,
      coreTop: 900,
      coreBottom: 1700,
      fullHeight: 4000,
    );
    final blocks = [
      _block('duplicate', top: 0.02, bottom: 0.08),
      _block('owned', top: 0.18, bottom: 0.22),
    ];

    final remapped = remapOcrBlocksFromTile(blocks, tile);

    expect(remapped, hasLength(1));
    expect(remapped.single.text, 'owned');
    expect(remapped.single.ymin, closeTo(0.245, 0.000001));
    expect(remapped.single.ymax, closeTo(0.255, 0.000001));
    expect(
      remapped.single.lineGeometries.single.ymin,
      closeTo(0.245, 0.000001),
    );
  });
}

OcrTextBlock _block(
  String text, {
  required double top,
  required double bottom,
}) => OcrTextBlock(
  xmin: 0.1,
  ymin: top,
  xmax: 0.3,
  ymax: bottom,
  lines: [text],
  lineGeometries: [
    OcrLineGeometry(xmin: 0.1, ymin: top, xmax: 0.3, ymax: bottom),
  ],
  language: 'ja',
);
