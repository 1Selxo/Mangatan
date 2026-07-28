import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/statistics/immersion_stats_storage.dart';
import 'package:mangayomi/services/sync/chimahon_novel_progress_adapter.dart';

/// Records a successfully mined Anki card into immersion statistics.
///
/// Chimahon buckets cards by media type and attributes them to the title being
/// read, so the per-title statistics view can show how many cards came from
/// each book. Manga rows use the library ID; novel rows use Chimahon's stable
/// book ID.
abstract final class AnkiStatsRecorder {
  /// Called after a card is added or overwritten, matching Chimahon's call
  /// sites. Failures are swallowed: losing a statistics row must never surface
  /// as a mining error after the card has already been created.
  static Future<void> recordCard({
    required MiningContext context,
    required DictionaryProfile profile,
  }) async {
    try {
      await ImmersionStatsStorage.addAnkiCard(
        type: _statsType(context.mediaType),
        profileId: profile.id,
        titleId: _titleId(context),
      );
    } catch (_) {
      // Statistics are advisory; the card itself already exists.
    }
  }

  /// Chimahon only distinguishes manga from everything else, which it counts as
  /// novel cards. Anime and unknown sources therefore land in `novelCards`,
  /// exactly as they do there.
  static String? _statsType(MiningMediaType mediaType) =>
      mediaType == MiningMediaType.manga ? 'manga' : null;

  static String? _titleId(MiningContext context) {
    final novelId = context.novelId;
    if (novelId != null && novelId.isNotEmpty) return novelId;

    final mangaId = context.mangaId;
    if (mangaId == null) return null;
    // A local EPUB read through the manga pipeline still belongs to its
    // Chimahon book identity, so prefer that when one exists.
    final progress = isar.epubBookProgress
        .filter()
        .mangaIdEqualTo(mangaId)
        .findFirstSync();
    if (progress != null) {
      final stableId = const ChimahonNovelProgressAdapter()
          .stableLocalIdOrNull(progress);
      if (stableId != null) return stableId;
    }
    return mangaId.toString();
  }
}
