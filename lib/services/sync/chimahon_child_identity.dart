import 'package:fixnum/fixnum.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupEpisode.pb.dart';
import 'package:mangayomi/utils/chapter_recognition.dart';

double chimahonCanonicalChildNumber({
  required String name,
  required double? sourceNumber,
}) =>
    normalizeSourceChapterNumber(sourceNumber) ??
    fallbackChapterNumberFromName(name);

String chimahonChapterIdentity(BackupChapter chapter) =>
    chimahonChapterIdentityValues(
      url: chapter.url,
      name: chapter.name,
      chapterNumber: chapter.chapterNumber,
    );

String chimahonChapterIdentityValues({
  required String url,
  required String name,
  required double? chapterNumber,
}) =>
    '$url|$name|${chimahonCanonicalChildNumber(name: name, sourceNumber: chapterNumber)}';

String chimahonEpisodeIdentity(BackupEpisode episode) =>
    chimahonEpisodeIdentityValues(
      url: episode.url,
      name: episode.name,
      episodeNumber: episode.episodeNumber,
    );

String chimahonEpisodeIdentityValues({
  required String url,
  required String name,
  required double? episodeNumber,
}) =>
    '$url|$name|${chimahonCanonicalChildNumber(name: name, sourceNumber: episodeNumber)}';

/// Normalizes Mihon's negative unknown-number sentinel and consolidates only
/// rows that consequently become the exact same chapter identity.
List<BackupChapter> canonicalizeChimahonChapters(
  Iterable<BackupChapter> chapters,
) {
  final byIdentity = <String, BackupChapter>{};
  for (final chapter in chapters) {
    final canonical = chapter.deepCopy();
    if (chapter.hasChapterNumber()) {
      canonical.chapterNumber = chimahonCanonicalChildNumber(
        name: chapter.name,
        sourceNumber: chapter.chapterNumber,
      );
    }
    final key = chimahonChapterIdentity(canonical);
    final existing = byIdentity[key];
    byIdentity[key] = existing == null
        ? canonical
        : _mergeChapterAliases(existing, canonical);
  }
  return byIdentity.values.toList(growable: false);
}

/// Episode equivalent of [canonicalizeChimahonChapters].
List<BackupEpisode> canonicalizeChimahonEpisodes(
  Iterable<BackupEpisode> episodes,
) {
  final byIdentity = <String, BackupEpisode>{};
  for (final episode in episodes) {
    final canonical = episode.deepCopy();
    if (episode.hasEpisodeNumber()) {
      canonical.episodeNumber = chimahonCanonicalChildNumber(
        name: episode.name,
        sourceNumber: episode.episodeNumber,
      );
    }
    final key = chimahonEpisodeIdentity(canonical);
    final existing = byIdentity[key];
    byIdentity[key] = existing == null
        ? canonical
        : _mergeEpisodeAliases(existing, canonical);
  }
  return byIdentity.values.toList(growable: false);
}

BackupChapter _mergeChapterAliases(BackupChapter left, BackupChapter right) {
  final rightWins = _rightRecordWins(
    left.version,
    left.lastModifiedAt,
    right.version,
    right.lastModifiedAt,
  );
  final winner = rightWins ? right : left;
  final loser = rightWins ? left : right;
  final merged = winner.deepCopy()..unknownFields.clear();
  merged
    ..mergeUnknownFields(loser.unknownFields)
    ..mergeUnknownFields(winner.unknownFields);
  merged
    ..chapterNumber = chimahonCanonicalChildNumber(
      name: winner.name,
      sourceNumber: winner.chapterNumber,
    )
    ..lastPageRead = _maxInt64(left.lastPageRead, right.lastPageRead)
    ..read = left.read || right.read
    ..bookmark = left.bookmark || right.bookmark;
  return merged;
}

BackupEpisode _mergeEpisodeAliases(BackupEpisode left, BackupEpisode right) {
  final rightWins = _rightRecordWins(
    left.version,
    left.lastModifiedAt,
    right.version,
    right.lastModifiedAt,
  );
  final winner = rightWins ? right : left;
  final loser = rightWins ? left : right;
  final merged = winner.deepCopy()..unknownFields.clear();
  merged
    ..mergeUnknownFields(loser.unknownFields)
    ..mergeUnknownFields(winner.unknownFields);
  merged
    ..episodeNumber = chimahonCanonicalChildNumber(
      name: winner.name,
      sourceNumber: winner.episodeNumber,
    )
    ..lastSecondSeen = _maxInt64(left.lastSecondSeen, right.lastSecondSeen)
    ..seen = left.seen || right.seen
    ..bookmark = left.bookmark || right.bookmark;
  return merged;
}

bool _rightRecordWins(
  Int64 leftVersion,
  Int64 leftModified,
  Int64 rightVersion,
  Int64 rightModified,
) {
  final leftVersioned = leftVersion != Int64.ZERO;
  final rightVersioned = rightVersion != Int64.ZERO;
  if (leftVersioned && rightVersioned && leftVersion != rightVersion) {
    return rightVersion > leftVersion;
  }
  if (!leftVersioned || !rightVersioned) {
    if (leftModified != rightModified) return rightModified > leftModified;
    if (leftVersioned != rightVersioned) return rightVersioned;
  }
  return true;
}

Int64 _maxInt64(Int64 left, Int64 right) => left >= right ? left : right;
