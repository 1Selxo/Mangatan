import 'dart:math' as math;

class OcrLineGeometry {
  final double xmin;
  final double ymin;
  final double xmax;
  final double ymax;
  final double rotation;

  /// Where each character of the line sits along its reading axis, as
  /// fractions of the box: character `i` spans `glyphEdges[i]` to
  /// `glyphEdges[i + 1]`, so the list holds one more entry than the line has
  /// characters. Measured along the x axis, or the y axis when
  /// [glyphEdgesVertical]. Fractions of the box survive every rescale of it.
  ///
  /// Null when the engine reported no character or word positions; the
  /// overlay then divides the line into equal cells.
  final List<double>? glyphEdges;
  final bool glyphEdgesVertical;

  const OcrLineGeometry({
    required this.xmin,
    required this.ymin,
    required this.xmax,
    required this.ymax,
    this.rotation = 0,
    this.glyphEdges,
    this.glyphEdgesVertical = false,
  });
}

/// One recognised piece of a line, a word or a symbol, and where it sits
/// along the line's reading axis, as fractions of the line box.
typedef OcrGlyphPiece = ({String text, double start, double end});

/// Character edges for [lineText] from the positions of its [pieces], in the
/// form [OcrLineGeometry.glyphEdges] takes.
///
/// A piece with several characters shares its extent equally among them.
/// Whitespace in [lineText] that lies between pieces spans the gap between
/// them. Returns null when the pieces do not spell out [lineText], so a
/// mismatch never misplaces the text.
List<double>? ocrGlyphEdges(List<OcrGlyphPiece> pieces, String lineText) {
  if (pieces.isEmpty || lineText.isEmpty) return null;
  final starts = <double>[];
  final ends = <double>[];
  final characters = StringBuffer();
  for (var index = 0; index < pieces.length; index++) {
    final piece = pieces[index];
    final text = piece.text.replaceAll(RegExp(r'\s+'), '');
    if (text.isEmpty) continue;
    final start = piece.start.clamp(0.0, 1.0).toDouble();
    final end = piece.end.clamp(start, 1.0).toDouble();
    final length = text.length;
    if (starts.isNotEmpty && characters.length < lineText.length) {
      // A space the line text keeps between two pieces fills their gap.
      final next = lineText[characters.length];
      if (next.trim().isEmpty) {
        starts.add(ends.last);
        ends.add(math.max(ends.last, start));
        characters.write(next);
      }
    }
    for (var offset = 0; offset < length; offset++) {
      starts.add(start + (end - start) * offset / length);
      ends.add(start + (end - start) * (offset + 1) / length);
    }
    characters.write(text);
  }
  if (characters.toString() != lineText) return null;
  final edges = <double>[starts.first];
  for (var index = 0; index + 1 < starts.length; index++) {
    // Pieces may leave a gap or overlap slightly: split the difference.
    final edge = (ends[index] + starts[index + 1]) / 2;
    edges.add(math.max(edges.last, edge));
  }
  edges.add(math.max(edges.last, ends.last));
  return edges;
}

class OcrTextBlock {
  final double xmin;
  final double ymin;
  final double xmax;
  final double ymax;
  final List<String> lines;
  final bool vertical;
  final List<OcrLineGeometry> lineGeometries;
  final String language;

  const OcrTextBlock({
    required this.xmin,
    required this.ymin,
    required this.xmax,
    required this.ymax,
    required this.lines,
    this.vertical = false,
    this.lineGeometries = const [],
    this.language = '',
  });

  String get text => lines.where((line) => line.trim().isNotEmpty).join('\n');

  /// The block's lines joined into a single continuous sentence.
  ///
  /// Unlike [text], this never inserts a hard newline between merged OCR
  /// lines. A raw `\n` between auto-merged fragments makes downstream
  /// sentence extraction (Yomitan) stop at the first line and produces an
  /// incomplete Anki sentence field. Use this whenever a block is handed to a
  /// dictionary popup or mining context as the example sentence.
  String get sentence => lines.where((line) => line.trim().isNotEmpty).join();
}
