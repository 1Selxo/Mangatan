import 'package:mangayomi/services/mining/ocr_block_merger.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';

/// Reading-order and sentence-assembly helpers for OCR text blocks.
///
/// A block holds its lines as separate strings. When we reconstruct the
/// sentence for display, copy, dictionary lookup, or Anki mining, spaced
/// languages need a single space between lines while CJK/spaceless languages
/// are concatenated verbatim (Mangatan issue #30). All consumers must use the
/// same joining and the same offset mapping so highlight/lookup offsets stay
/// aligned with the assembled sentence.

/// Returns the block's line indices in natural reading order.
///
/// Vertical Japanese columns read right-to-left; horizontal lines read
/// top-to-bottom. Falls back to the stored order when geometry is unavailable.
List<int> orderedBlockLineIndices(OcrTextBlock block) {
  final indices = List.generate(block.lines.length, (index) => index);
  if (block.lines.length <= 1 ||
      block.lineGeometries.length != block.lines.length) {
    return indices;
  }
  if (block.vertical) {
    indices.sort((a, b) {
      final ax = block.lineGeometries[a].xmin + block.lineGeometries[a].xmax;
      final bx = block.lineGeometries[b].xmin + block.lineGeometries[b].xmax;
      return bx.compareTo(ax);
    });
  } else {
    indices.sort(
      (a, b) =>
          block.lineGeometries[a].ymin.compareTo(block.lineGeometries[b].ymin),
    );
  }
  return indices;
}

/// The block's lines in reading order.
List<String> orderedBlockLines(OcrTextBlock block) =>
    orderedBlockLineIndices(block).map((index) => block.lines[index]).toList();

/// The block reconstructed into a single sentence in reading order.
///
/// Uses [joinOcrLines] so spaced languages get one space between lines and
/// spaceless languages are concatenated.
String orderedBlockSentence(OcrTextBlock block) =>
    joinOcrLines(orderedBlockLines(block), language: block.language);

/// Maps a raw character offset (into the naive concatenation of [block.lines]
/// in stored order) onto the offset within [orderedBlockSentence].
///
/// Accounts for both reading-order reshuffling and any separators inserted by
/// [joinOcrLines], so a tap position resolves to the correct character in the
/// assembled sentence.
int toOrderedOffset(OcrTextBlock block, int rawOffset) {
  var start = 0;
  var rawLine = 0;
  var inLine = 0;
  for (var index = 0; index < block.lines.length; index++) {
    if (rawOffset < start + block.lines[index].length) {
      rawLine = index;
      inLine = rawOffset - start;
      break;
    }
    start += block.lines[index].length;
  }
  final order = orderedBlockLineIndices(block);
  final preceding = order.takeWhile((index) => index != rawLine).toList();
  if (preceding.isEmpty) return inLine;
  // Rebuild the assembled prefix (ordered preceding lines + the current line)
  // and measure it: this yields the exact offset including inserted spaces
  // without re-deriving joinOcrLines' whitespace rules here.
  final prefixLines = [
    ...preceding.map((i) => block.lines[i]),
    block.lines[rawLine],
  ];
  final assembledPrefix = joinOcrLines(prefixLines, language: block.language);
  final currentLine = block.lines[rawLine];
  final currentStartInPrefix = assembledPrefix.length - currentLine.length;
  return currentStartInPrefix + inLine;
}
