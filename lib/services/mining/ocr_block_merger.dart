import 'dart:math' as math;

import 'package:mangayomi/services/mining/ocr_models.dart';

/// Reconstructs OCR engine line fragments into readable text blocks.
///
/// This follows Chimahon's OwOCR stages: fragment joining, furigana filtering,
/// connected-component paragraph grouping, close-paragraph merging, and
/// Japanese right-to-left reading order.
List<OcrTextBlock> mergeOcrBlocks(
  List<OcrTextBlock> blocks, {
  required String language,
}) {
  if (blocks.isEmpty) return const [];
  var lines = _flatten(blocks);
  if (lines.isEmpty) return const [];
  lines = _deduplicate(lines);
  lines = _mergeBrokenFragments(lines);
  if (language.startsWith('ja')) lines = _filterFurigana(lines);
  var groups = _components(lines, _sameParagraph);
  groups = _mergeCloseGroups(groups);
  final merged = groups.map((group) => _toBlock(group, language)).toList();
  return _readingOrder(merged, language.startsWith('ja'));
}

List<_Line> _flatten(List<OcrTextBlock> blocks) {
  final result = <_Line>[];
  for (final block in blocks) {
    if (block.lines.length == block.lineGeometries.length) {
      for (var i = 0; i < block.lines.length; i++) {
        final text = _clean(block.lines[i]);
        final box = block.lineGeometries[i];
        if (text.isEmpty || box.xmax <= box.xmin || box.ymax <= box.ymin) {
          continue;
        }
        result.add(
          _Line(text, box, block.vertical || _vertical(box), block.language),
        );
      }
    } else {
      final text = _clean(block.text);
      if (text.isEmpty) continue;
      final box = OcrLineGeometry(
        xmin: block.xmin,
        ymin: block.ymin,
        xmax: block.xmax,
        ymax: block.ymax,
      );
      result.add(
        _Line(text, box, block.vertical || _vertical(box), block.language),
      );
    }
  }
  return result;
}

List<_Line> _deduplicate(List<_Line> lines) {
  final kept = <_Line>[];
  for (final line in [
    ...lines,
  ]..sort((a, b) => a.box.ymin.compareTo(b.box.ymin))) {
    final duplicate = kept.any(
      (other) =>
          _iou(line.box, other.box) >= 0.55 ||
          (_centerDistance(line.box, other.box) <
                  math.min(line.thickness, other.thickness) * 0.35 &&
              line.text == other.text),
    );
    if (!duplicate) kept.add(line);
  }
  return kept;
}

List<_Line> _mergeBrokenFragments(List<_Line> lines) {
  final remaining = [...lines];
  final output = <_Line>[];
  while (remaining.isNotEmpty) {
    final seed = remaining.removeAt(0);
    final group = <_Line>[seed];
    var changed = true;
    while (changed) {
      changed = false;
      for (var i = remaining.length - 1; i >= 0; i--) {
        final candidate = remaining[i];
        if (candidate.vertical != seed.vertical) continue;
        if (group.any((line) => _brokenPair(line, candidate))) {
          group.add(remaining.removeAt(i));
          changed = true;
        }
      }
    }
    output.add(group.length == 1 ? seed : _joinLine(group, seed.vertical));
  }
  return output;
}

bool _brokenPair(_Line a, _Line b) {
  if (a.vertical) {
    return _overlap(a.box.xmin, a.box.xmax, b.box.xmin, b.box.xmax) > 0.8 &&
        _overlap(a.box.ymin, a.box.ymax, b.box.ymin, b.box.ymax) < 0.4 &&
        _distance(a.box.ymin, a.box.ymax, b.box.ymin, b.box.ymax) <=
            math.max(a.charSize, b.charSize) * 0.5;
  }
  return _overlap(a.box.ymin, a.box.ymax, b.box.ymin, b.box.ymax) > 0.8 &&
      _overlap(a.box.xmin, a.box.xmax, b.box.xmin, b.box.xmax) < 0.4 &&
      _distance(a.box.xmin, a.box.xmax, b.box.xmin, b.box.xmax) <=
          math.max(a.charSize, b.charSize) * 0.5;
}

_Line _joinLine(List<_Line> lines, bool vertical) {
  lines.sort(
    (a, b) => vertical
        ? a.centerY.compareTo(b.centerY)
        : a.centerX.compareTo(b.centerX),
  );
  return _Line(
    _clean(lines.map((line) => line.text).join()),
    _union(lines.map((line) => line.box)),
    vertical,
    lines.first.language,
  );
}

List<_Line> _filterFurigana(List<_Line> lines) {
  if (lines.length < 2) return lines;
  return lines.where((line) {
    for (final other in lines) {
      if (identical(line, other) || line.vertical != other.vertical) continue;
      if (line.thickness >= other.thickness * 0.58) continue;
      final mainOverlap = line.vertical
          ? _overlap(
              line.box.ymin,
              line.box.ymax,
              other.box.ymin,
              other.box.ymax,
            )
          : _overlap(
              line.box.xmin,
              line.box.xmax,
              other.box.xmin,
              other.box.xmax,
            );
      final crossDistance = line.vertical
          ? _distance(
              line.box.xmin,
              line.box.xmax,
              other.box.xmin,
              other.box.xmax,
            )
          : _distance(
              line.box.ymin,
              line.box.ymax,
              other.box.ymin,
              other.box.ymax,
            );
      if (mainOverlap > 0.5 && crossDistance <= other.thickness * 0.8) {
        return false;
      }
    }
    return true;
  }).toList();
}

bool _sameParagraph(_Line a, _Line b) {
  if (a.vertical != b.vertical) return false;
  final ratio =
      math.max(a.thickness, b.thickness) /
      math.max(0.0001, math.min(a.thickness, b.thickness));
  if (ratio > 1.8) return false;
  final union = _union([a.box, b.box]);
  final density =
      (_area(a.box) + _area(b.box)) / math.max(0.000001, _area(union));
  if (density < 0.48) return false;
  if (a.vertical) {
    return _distance(a.box.xmin, a.box.xmax, b.box.xmin, b.box.xmax) <=
            math.max(a.thickness, b.thickness) * 1.25 &&
        _overlap(a.box.ymin, a.box.ymax, b.box.ymin, b.box.ymax) > 0.25;
  }
  return _distance(a.box.ymin, a.box.ymax, b.box.ymin, b.box.ymax) <=
          math.max(a.thickness, b.thickness) * 1.25 &&
      _overlap(a.box.xmin, a.box.xmax, b.box.xmin, b.box.xmax) > 0.25;
}

List<List<_Line>> _mergeCloseGroups(List<List<_Line>> groups) {
  return _components(groups, (a, b) {
    final av = a.first.vertical;
    if (av != b.first.vertical) return false;
    final ab = _union(a.map((line) => line.box));
    final bb = _union(b.map((line) => line.box));
    final charSize = math.max(
      a.map((line) => line.charSize).reduce(math.max),
      b.map((line) => line.charSize).reduce(math.max),
    );
    if (av) {
      final ratio = math.min(ab.width, bb.width) / math.max(ab.width, bb.width);
      return ratio > 0.6 &&
          _distance(ab.xmin, ab.xmax, bb.xmin, bb.xmax) <= charSize * 2 &&
          _overlap(ab.ymin, ab.ymax, bb.ymin, bb.ymax) > 0.7;
    }
    final ratio =
        math.min(ab.height, bb.height) / math.max(ab.height, bb.height);
    return ratio > 0.6 &&
        _distance(ab.ymin, ab.ymax, bb.ymin, bb.ymax) <= charSize * 2 &&
        _overlap(ab.xmin, ab.xmax, bb.xmin, bb.xmax) > 0.7;
  }).map((component) => component.expand((group) => group).toList()).toList();
}

List<List<T>> _components<T>(List<T> items, bool Function(T, T) connects) {
  final used = List<bool>.filled(items.length, false);
  final result = <List<T>>[];
  for (var i = 0; i < items.length; i++) {
    if (used[i]) continue;
    used[i] = true;
    final indices = <int>[i];
    for (var cursor = 0; cursor < indices.length; cursor++) {
      final current = indices[cursor];
      for (var j = 0; j < items.length; j++) {
        if (!used[j] && connects(items[current], items[j])) {
          used[j] = true;
          indices.add(j);
        }
      }
    }
    result.add(indices.map((index) => items[index]).toList());
  }
  return result;
}

OcrTextBlock _toBlock(List<_Line> lines, String language) {
  final vertical =
      lines.map((line) => line.vertical).where((v) => v).length * 2 >=
      lines.length;
  lines.sort(
    (a, b) => vertical
        ? b.centerX.compareTo(a.centerX)
        : a.centerY.compareTo(b.centerY),
  );
  final box = _union(lines.map((line) => line.box));
  return OcrTextBlock(
    xmin: box.xmin,
    ymin: box.ymin,
    xmax: box.xmax,
    ymax: box.ymax,
    lines: lines.map((line) => line.text).toList(),
    vertical: vertical,
    lineGeometries: lines.map((line) => line.box).toList(),
    language: language,
  );
}

List<OcrTextBlock> _readingOrder(List<OcrTextBlock> blocks, bool japanese) {
  blocks.sort((a, b) {
    final overlap = _overlap(a.ymin, a.ymax, b.ymin, b.ymax);
    if (overlap > 0.2) {
      return japanese ? b.xmin.compareTo(a.xmin) : a.xmin.compareTo(b.xmin);
    }
    return a.ymin.compareTo(b.ymin);
  });
  return blocks;
}

String _clean(String value) =>
    value.replaceAll(RegExp(r'[\r\n\t]+'), '').trim();
bool _vertical(OcrLineGeometry box) => box.height > box.width * 1.25;
double _area(OcrLineGeometry box) => box.width * box.height;
double _distance(double a0, double a1, double b0, double b1) =>
    math.max(0, math.max(a0, b0) - math.min(a1, b1));
double _overlap(double a0, double a1, double b0, double b1) {
  final intersection = math.max(0, math.min(a1, b1) - math.max(a0, b0));
  return intersection / math.max(0.000001, math.min(a1 - a0, b1 - b0));
}

double _iou(OcrLineGeometry a, OcrLineGeometry b) {
  final width = math.max(
    0,
    math.min(a.xmax, b.xmax) - math.max(a.xmin, b.xmin),
  );
  final height = math.max(
    0,
    math.min(a.ymax, b.ymax) - math.max(a.ymin, b.ymin),
  );
  final intersection = width * height;
  return intersection / math.max(0.000001, _area(a) + _area(b) - intersection);
}

double _centerDistance(OcrLineGeometry a, OcrLineGeometry b) => math.sqrt(
  math.pow((a.xmin + a.xmax - b.xmin - b.xmax) / 2, 2) +
      math.pow((a.ymin + a.ymax - b.ymin - b.ymax) / 2, 2),
);
OcrLineGeometry _union(Iterable<OcrLineGeometry> boxes) {
  final list = boxes.toList();
  return OcrLineGeometry(
    xmin: list.map((box) => box.xmin).reduce(math.min),
    ymin: list.map((box) => box.ymin).reduce(math.min),
    xmax: list.map((box) => box.xmax).reduce(math.max),
    ymax: list.map((box) => box.ymax).reduce(math.max),
  );
}

extension on OcrLineGeometry {
  double get width => xmax - xmin;
  double get height => ymax - ymin;
}

class _Line {
  const _Line(this.text, this.box, this.vertical, this.language);
  final String text;
  final OcrLineGeometry box;
  final bool vertical;
  final String language;
  double get thickness => vertical ? box.width : box.height;
  double get charSize =>
      (vertical ? box.height : box.width) / math.max(1, text.length);
  double get centerX => (box.xmin + box.xmax) / 2;
  double get centerY => (box.ymin + box.ymax) / 2;
}
