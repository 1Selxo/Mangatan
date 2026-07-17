import 'package:flutter/widgets.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/library/widgets/library_file_drop_target.dart';
import 'package:mangayomi/services/epub_manga.dart';

typedef MangaChapterDropImporter =
    Future<void> Function(List<String> filePaths);

/// Adds desktop archive drops to an existing local manga title.
///
/// The title itself is an explicit routing choice, so EPUB classification is
/// deliberately skipped here. This keeps the drop fast and prevents a volume
/// from being redirected into a newly-created novel entry.
class MangaChapterFileDropTarget extends StatelessWidget {
  const MangaChapterFileDropTarget({
    super.key,
    required this.manga,
    required this.onImport,
    required this.child,
  });

  final Manga manga;
  final MangaChapterDropImporter onImport;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (manga.itemType != ItemType.manga ||
        manga.isLocalArchive != true ||
        manga.source == 'torrent') {
      return child;
    }

    return LibraryFileDropTarget(
      itemType: ItemType.manga,
      classifyEpub: _honorExistingManga,
      onImport: (filePaths, _) => onImport(filePaths),
      child: child,
    );
  }
}

Future<EpubContentKind> _honorExistingManga(String _) async {
  return EpubContentKind.ambiguous;
}
