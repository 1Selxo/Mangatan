import 'dart:math' as math;

import 'package:mangayomi/services/mining/ocr_models.dart';

/// A vertical OCR crop and the non-overlapping part whose results it owns.
///
/// Adjacent crops overlap so text crossing a seam is fully visible to at
/// least one OCR request. The core ranges divide the original image without
/// overlap, which lets [remapOcrBlocksFromTile] discard duplicate detections.
class OcrVerticalTile {
  const OcrVerticalTile({
    required this.top,
    required this.height,
    required this.coreTop,
    required this.coreBottom,
    required this.fullHeight,
  });

  final int top;
  final int height;
  final double coreTop;
  final double coreBottom;
  final int fullHeight;

  int get bottom => top + height;

  bool ownsCenter(double centerY) =>
      centerY >= coreTop &&
      (coreBottom >= fullHeight ? centerY <= coreBottom : centerY < coreBottom);
}

/// Splits an unusually tall page into OCR-sized vertical crops.
///
/// The adaptive height keeps enough horizontal resolution when cloud OCR
/// scales a crop to its input limit while avoiding excessive requests.
List<OcrVerticalTile> planVerticalOcrTiles({
  required int width,
  required int height,
  int maxTileHeight = 2400,
  int minTileHeight = 1200,
  double maxTileAspectRatio = 2.5,
}) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('OCR image dimensions must be positive');
  }
  final tileHeight = math.min(
    height,
    math.min(
      maxTileHeight,
      math.max(minTileHeight, (width * maxTileAspectRatio).round()),
    ),
  );
  if (height <= tileHeight) {
    return [
      OcrVerticalTile(
        top: 0,
        height: height,
        coreTop: 0,
        coreBottom: height.toDouble(),
        fullHeight: height,
      ),
    ];
  }

  final overlap = math.min(
    tileHeight ~/ 4,
    math.max(128, (tileHeight * 0.12).round()),
  );
  final stride = tileHeight - overlap;
  final tops = <int>[0];
  while (tops.last + tileHeight < height) {
    final next = math.min(tops.last + stride, height - tileHeight);
    if (next == tops.last) break;
    tops.add(next);
  }

  final boundaries = <double>[];
  for (var index = 0; index < tops.length - 1; index++) {
    final currentBottom = tops[index] + tileHeight;
    boundaries.add((currentBottom + tops[index + 1]) / 2);
  }
  return [
    for (var index = 0; index < tops.length; index++)
      OcrVerticalTile(
        top: tops[index],
        height: tileHeight,
        coreTop: index == 0 ? 0 : boundaries[index - 1],
        coreBottom: index == tops.length - 1
            ? height.toDouble()
            : boundaries[index],
        fullHeight: height,
      ),
  ];
}

/// Maps normalized OCR geometry from [tile] back to the full-page image.
List<OcrTextBlock> remapOcrBlocksFromTile(
  List<OcrTextBlock> blocks,
  OcrVerticalTile tile,
) {
  final mapped = <OcrTextBlock>[];
  for (final block in blocks) {
    final centerY = tile.top + ((block.ymin + block.ymax) / 2) * tile.height;
    if (!tile.ownsCenter(centerY)) continue;
    mapped.add(
      OcrTextBlock(
        xmin: block.xmin,
        ymin: _mapY(block.ymin, tile),
        xmax: block.xmax,
        ymax: _mapY(block.ymax, tile),
        lines: block.lines,
        vertical: block.vertical,
        lineGeometries: [
          for (final line in block.lineGeometries)
            OcrLineGeometry(
              xmin: line.xmin,
              ymin: _mapY(line.ymin, tile),
              xmax: line.xmax,
              ymax: _mapY(line.ymax, tile),
              rotation: line.rotation,
            ),
        ],
        language: block.language,
      ),
    );
  }
  return mapped;
}

double _mapY(double normalizedY, OcrVerticalTile tile) =>
    ((tile.top + normalizedY * tile.height) / tile.fullHeight).clamp(0.0, 1.0);
