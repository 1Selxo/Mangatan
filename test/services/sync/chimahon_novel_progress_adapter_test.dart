import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/services/sync/chimahon_novel_progress_adapter.dart';

void main() {
  const adapter = ChimahonNovelProgressAdapter();

  EpubBookProgress progress({int modified = 100}) => EpubBookProgress(
    mangaId: 1,
    archivePath: '/books/volume.epub',
    title: '  Koyomimonogatari ',
    author: ' NISIOISIN ',
    chapterIndex: 4,
    progress: 0.25,
    characterCount: 1234,
    lastModified: modified,
  );

  test('exports the exact Chimahon bookmark tuple and stable identity', () {
    final backup = adapter.export(progress());

    expect(backup.id, '76e76b4aba7622e007300e36978b4a10');
    expect(backup.chapterIndex, 4);
    expect(backup.progress, 0.25);
    expect(backup.characterCount, 1234);
    expect(backup.lastModified, Int64(100));
  });

  test('restore uses whole-record timestamp ordering and keeps ties local', () {
    final local = progress();
    final remote = BackupNovel(
      id: adapter.stableId(title: local.title, author: local.author),
      title: local.title,
      author: local.author,
      chapterIndex: 7,
      progress: 0.75,
      characterCount: 4321,
      lastModified: Int64(101),
    );

    expect(adapter.applyIfNewer(local, remote), isTrue);
    expect(
      (local.chapterIndex, local.progress, local.characterCount),
      (7, 0.75, 4321),
    );

    remote
      ..chapterIndex = 9
      ..lastModified = Int64(101);
    expect(adapter.applyIfNewer(local, remote), isFalse);
    expect(local.chapterIndex, 7);
  });
}
