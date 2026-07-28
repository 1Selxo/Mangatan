import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupStatistics.pb.dart';
import 'package:protobuf/protobuf.dart';

/// Chimahon's merge rule for the two global daily statistics collections.
///
/// These rows carry no modification clock, so neither side can be declared
/// newer, and summing them would double count a day both devices already
/// synced. Chimahon's `MangaStatsStorage.merge` / `AnkiStatsStorage.merge` take
/// the larger value per field instead, which is idempotent and never loses
/// recorded reading. Both sides' unknown fields are retained so a newer fork's
/// additions survive.
abstract final class ChimahonStatsRowMerge {
  static List<BackupMangaStats> mangaStats(
    Iterable<BackupMangaStats> local,
    Iterable<BackupMangaStats> remote,
  ) => _merge<BackupMangaStats>(
    local,
    remote,
    keyOf: mangaKey,
    combine: (winner, loser) => winner
      ..charactersRead = _max(winner.charactersRead, loser.charactersRead)
      ..readingTime = winner.readingTime > loser.readingTime
          ? winner.readingTime
          : loser.readingTime,
  );

  static List<BackupAnkiStats> ankiStats(
    Iterable<BackupAnkiStats> local,
    Iterable<BackupAnkiStats> remote,
  ) => _merge<BackupAnkiStats>(
    local,
    remote,
    keyOf: ankiKey,
    combine: (winner, loser) => winner
      ..mangaCards = _max(winner.mangaCards, loser.mangaCards)
      ..novelCards = _max(winner.novelCards, loser.novelCards),
  );

  /// Chimahon keys a manga statistics row on the day and the title.
  static String mangaKey(BackupMangaStats row) =>
      '${row.dateKey}|${row.mangaId}';

  /// Chimahon keys an Anki statistics row on the day, profile, and title. An
  /// absent `titleId` means "mined outside any title" and must not collide with
  /// a real, empty-string title ID.
  static String ankiKey(BackupAnkiStats row) =>
      '${row.dateKey}|${row.profileId}|'
      '${row.hasTitleId() ? 'id:${row.titleId}' : 'none'}';

  static List<T> _merge<T extends GeneratedMessage>(
    Iterable<T> local,
    Iterable<T> remote, {
    required String Function(T row) keyOf,
    required T Function(T winner, T loser) combine,
  }) {
    final byKey = <String, T>{};
    final order = <String>[];
    for (final row in [...local, ...remote]) {
      final key = keyOf(row);
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = row.deepCopy();
        order.add(key);
        continue;
      }
      final winner = existing.deepCopy();
      winner.mergeUnknownFields(row.unknownFields);
      byKey[key] = combine(winner, row);
    }
    return [for (final key in order) byKey[key]!];
  }

  static int _max(int a, int b) => a > b ? a : b;
}
