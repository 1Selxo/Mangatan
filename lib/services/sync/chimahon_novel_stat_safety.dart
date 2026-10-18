import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';

/// Whether [candidate] lost reading recorded in [baseline] for the same day.
///
/// Chimahon's database-backed backups write `lastStatisticModified = 0`, so
/// equal clocks are the normal case, not evidence of identical rows. Both
/// Chimahon's `mergeNovelStatDay` and Mangatan's merger then combine the two
/// days field by field: counters and the maximum speed take the larger value
/// and the minimum speeds take the smaller non-zero value. A merged day that
/// absorbed more reading from the other device is therefore not a regression.
/// `lastReadingSpeed` is picked by a "who read more" proxy rather than a
/// clock, so it carries no loss signal of its own.
bool chimahonNovelStatRegressed(
  BackupNovelStat baseline,
  BackupNovelStat candidate,
) {
  if (candidate.lastStatisticModified < baseline.lastStatisticModified) {
    return true;
  }
  if (candidate.lastStatisticModified > baseline.lastStatisticModified) {
    return false;
  }
  bool minimumKept(int baseline, int candidate) =>
      baseline <= 0 || (candidate > 0 && candidate <= baseline);
  return candidate.charactersRead < baseline.charactersRead ||
      candidate.readingTime < baseline.readingTime ||
      candidate.maxReadingSpeed < baseline.maxReadingSpeed ||
      !minimumKept(baseline.minReadingSpeed, candidate.minReadingSpeed) ||
      !minimumKept(baseline.altMinReadingSpeed, candidate.altMinReadingSpeed);
}
