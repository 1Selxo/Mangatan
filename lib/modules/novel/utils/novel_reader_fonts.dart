import 'package:google_fonts/google_fonts.dart';
import 'package:mangayomi/modules/novel/utils/novel_custom_fonts.dart';

class NovelReaderFontOption {
  final String label;
  final String? key;
  const NovelReaderFontOption(this.label, this.key);
}

const novelReaderFontOptions = [
  NovelReaderFontOption('Default', null),
  NovelReaderFontOption('OpenDyslexic', 'OpenDyslexic'),
  NovelReaderFontOption('Lexend', 'Lexend'),
  NovelReaderFontOption('Atkinson Hyperlegible', 'AtkinsonHyperlegible'),
];

/// Resolves a stored font key to the actual font family name flutter_html
/// should render with. OpenDyslexic is bundled as a local asset (declared
/// in pubspec.yaml under the same family name), the others are resolved via
/// google_fonts the same way the app-wide font picker already does.
///
/// Imported fonts resolve to their deterministic family name; callers must
/// also call [ensureNovelCustomFontLoaded] so the engine registers the file.
String? resolveNovelFontFamily(String? key) {
  final customFile = novelCustomFontFileName(key);
  if (customFile != null) return novelCustomFontFamilyName(customFile);
  switch (key) {
    case 'OpenDyslexic':
      return 'OpenDyslexic';
    case 'Lexend':
      return GoogleFonts.lexend().fontFamily;
    case 'AtkinsonHyperlegible':
      return GoogleFonts.atkinsonHyperlegible().fontFamily;
    default:
      return null;
  }
}
