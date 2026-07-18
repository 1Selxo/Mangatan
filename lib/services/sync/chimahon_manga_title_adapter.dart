import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';

/// Chimahon stores the source title in protobuf field 3 and an optional local
/// display-title override in field 800.
class ChimahonMangaTitles {
  const ChimahonMangaTitles({
    required this.sourceTitle,
    required this.displayTitle,
  });

  final String sourceTitle;
  final String displayTitle;

  String? get customTitle => displayTitle == sourceTitle ? null : displayTitle;
}

class ChimahonMangaTitleAdapter {
  const ChimahonMangaTitleAdapter();

  ChimahonMangaTitles fromBackup(BackupManga manga) {
    final sourceTitle = manga.title;
    return ChimahonMangaTitles(
      sourceTitle: sourceTitle,
      displayTitle: manga.hasCustomTitle() ? manga.customTitle : sourceTitle,
    );
  }

  ChimahonMangaTitles fromManga(Manga manga) {
    final sourceTitle = manga.sourceTitle ?? manga.name ?? '';
    return ChimahonMangaTitles(
      sourceTitle: sourceTitle,
      displayTitle: manga.name ?? sourceTitle,
    );
  }
}
