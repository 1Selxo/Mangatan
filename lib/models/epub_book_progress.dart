import 'package:isar_community/isar.dart';
import 'package:mangayomi/utils/chimahon_novel_identity.dart';

part 'epub_book_progress.g.dart';

@collection
@Name('EpubBookProgress')
class EpubBookProgress {
  Id? id;

  @Index(unique: true, composite: [CompositeIndex('archivePath')])
  int mangaId;

  String archivePath;

  /// Chimahon book identity inputs. Its sync ID is MD5 of normalized
  /// `title|author`, so these belong to the progress record rather than a
  /// Mangatan library grouping that may contain multiple EPUB files.
  String title;

  String? author;

  /// Exact Chimahon wire identity retained for the metadata-empty fallback.
  ///
  /// Chimahon normally derives a novel ID from normalized `title|author`, but
  /// when both values are empty it uses the book's stored ID instead. Keeping
  /// that value here is the only collision-free way to round-trip such books.
  String? chimahonId;

  /// Language declared by the EPUB package. This remains nullable so a book
  /// without metadata does not accidentally match a language profile.
  String? lang;

  int chapterIndex;

  double progress;

  int characterCount;

  int? lastModified;

  EpubBookProgress({
    this.id = Isar.autoIncrement,
    required this.mangaId,
    required this.archivePath,
    required this.title,
    this.author,
    this.chimahonId,
    this.lang,
    this.chapterIndex = 0,
    this.progress = 0,
    this.characterCount = 0,
    this.lastModified,
  });

  /// Creates persisted metadata for a newly imported local EPUB.
  ///
  /// Refresh paths should keep using the existing row so its stored Chimahon
  /// ID is not changed when the EPUB's metadata changes.
  factory EpubBookProgress.forImportedEpub({
    required int mangaId,
    required String archivePath,
    required String title,
    String? author,
    String? lang,
  }) => EpubBookProgress(
    mangaId: mangaId,
    archivePath: archivePath,
    title: title,
    author: author,
    chimahonId: ChimahonNovelIdentity.newBookId(title: title, author: author),
    lang: lang,
  );
}
