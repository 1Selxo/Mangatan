import 'package:isar_community/isar.dart';

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
    this.lang,
    this.chapterIndex = 0,
    this.progress = 0,
    this.characterCount = 0,
    this.lastModified,
  });
}
