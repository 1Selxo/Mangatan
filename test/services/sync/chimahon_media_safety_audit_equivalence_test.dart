import 'dart:math';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupEpisode.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupHistory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupTracking.pb.dart';
import 'package:mangayomi/services/sync/chimahon_child_identity.dart';
import 'package:mangayomi/services/sync/chimahon_media_safety_audit.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:mangayomi/utils/chapter_recognition.dart';
import 'package:protobuf/protobuf.dart';

import 'legacy/legacy_chimahon_media_safety_audit.dart';

/// The media safety audit reports exactly what it reported before the
/// performance changes: the same codes with the same affected entries, in the
/// same order, for both failures and observations.
///
/// Inputs are random libraries for two devices that share most entries. The
/// proposal is the real merge, sometimes tampered with afterwards, so both the
/// passing and the failing paths run. Some records carry unknown fields.
void main() {
  test('reports the same as the audit before the change', () {
    var withFailures = 0;
    var clean = 0;
    for (var seed = 0; seed < 400; seed++) {
      final random = Random(seed);
      final generator = _Generator(random);
      final remote = generator.library();
      final local = generator.library(basedOn: remote);
      final remoteWinsTies = random.nextBool();
      BackupMihon proposed;
      try {
        proposed = const ChimahonSyncMerger().merge(
          local: local,
          remote: remote,
          remoteWinsRecordTies: remoteWinsTies,
        );
      } catch (_) {
        proposed = local.deepCopy();
      }
      if (random.nextInt(3) == 0) generator.tamper(proposed);

      final current = _run(
        (fail, observe) => const ChimahonMediaSafetyAudit().audit(
          remote: remote.deepCopy(),
          local: local.deepCopy(),
          proposed: proposed.deepCopy(),
          remoteWinsTies: remoteWinsTies,
          fail: fail,
          observe: observe,
        ),
      );
      final legacy = _run(
        (fail, observe) => const LegacyChimahonMediaSafetyAudit().audit(
          remote: remote.deepCopy(),
          local: local.deepCopy(),
          proposed: proposed.deepCopy(),
          remoteWinsTies: remoteWinsTies,
          fail: fail,
          observe: observe,
        ),
      );
      expect(current, legacy, reason: 'seed $seed');
      if (current.any(
        (line) => line.startsWith('fail ') && !line.endsWith(':'),
      )) {
        withFailures++;
      } else {
        clean++;
      }
    }
    // Both outcomes must be well represented for the comparison to mean
    // anything.
    expect(withFailures, greaterThan(40));
    expect(clean, greaterThan(40));
  });

  test('canonical child numbers round as a one-element Float32List', () {
    final random = Random(7);
    final values = <double?>[
      null,
      0,
      -1,
      -0.0,
      1.1,
      54.3,
      1e-40,
      3.4028235e38,
      double.nan,
      double.infinity,
      for (var i = 0; i < 2000; i++) (random.nextDouble() - 0.2) * 2000,
    ];
    for (final value in values) {
      for (final name in ['Chapter 12.5', 'Vol.2 Ch.7', 'Extra', '']) {
        final expected = Float32List.fromList([
          normalizeSourceChapterNumber(value) ??
              fallbackChapterNumberFromName(name),
        ]).single;
        final actual = chimahonCanonicalChildNumber(
          name: name,
          sourceNumber: value,
        );
        if (expected.isNaN) {
          expect(actual.isNaN, isTrue);
        } else {
          expect(actual, expected);
        }
      }
    }
  });
}

typedef _Report = void Function(String, Iterable<String>);

List<String> _run(void Function(_Report fail, _Report observe) audit) {
  final lines = <String>[];
  try {
    audit(
      (code, affected) => lines.add('fail $code:${affected.join('|')}'),
      (code, affected) => lines.add('observe $code:${affected.join('|')}'),
    );
  } catch (error) {
    lines.add('threw ${error.runtimeType}: $error');
  }
  return lines;
}

class _Generator {
  _Generator(this.random);

  final Random random;

  bool chance(int percent) => random.nextInt(100) < percent;
  T pick<T>(List<T> values) => values[random.nextInt(values.length)];
  Int64 clock() => Int64(100 + random.nextInt(20));

  void maybeUnknown(GeneratedMessage message) {
    if (!chance(20)) return;
    final fields = UnknownFieldSet()
      ..mergeVarintField(900 + random.nextInt(3), Int64(random.nextInt(4)));
    if (chance(50)) {
      fields.mergeLengthDelimitedField(910, [random.nextInt(255)]);
    }
    message.mergeUnknownFields(fields);
  }

  BackupChapter chapter(int index) {
    final value = BackupChapter(
      url: '/c$index',
      name: pick(['Chapter $index', 'Ch. $index', 'Extra $index']),
      scanlator: pick([null, 'Group', 'Other']),
      read: chance(50) ? random.nextBool() : null,
      bookmark: chance(20) ? true : null,
      lastPageRead: chance(50) ? Int64(random.nextInt(30)) : null,
      dateFetch: chance(60) ? clock() : null,
      chapterNumber: pick<double?>([null, index.toDouble(), -1, index + 0.5]),
      sourceOrder: chance(60) ? Int64(random.nextInt(5)) : null,
      lastModifiedAt: clock(),
      version: Int64(random.nextInt(4)),
      memo: chance(15) ? [random.nextInt(9)] : null,
    );
    maybeUnknown(value);
    return value;
  }

  BackupEpisode episode(int index) {
    final value = BackupEpisode(
      url: '/e$index',
      name: 'Episode $index',
      seen: chance(50) ? random.nextBool() : null,
      lastSecondSeen: chance(50) ? Int64(random.nextInt(900)) : null,
      dateFetch: chance(60) ? clock() : null,
      episodeNumber: pick<double?>([null, index.toDouble(), -1]),
      sourceOrder: chance(60) ? Int64(random.nextInt(5)) : null,
      lastModifiedAt: clock(),
      version: Int64(random.nextInt(4)),
    );
    maybeUnknown(value);
    return value;
  }

  BackupHistory history(String url) => BackupHistory(
    url: url,
    lastRead: clock(),
    readDuration: Int64(random.nextInt(50)),
  );

  BackupTracking tracking() => BackupTracking(
    syncId: 1 + random.nextInt(2),
    libraryId: Int64(random.nextInt(3)),
    mediaId: Int64(10 + random.nextInt(3)),
    lastChapterRead: random.nextInt(10).toDouble(),
  );

  BackupManga manga(int index) {
    final chapters = [
      for (var i = 0; i < random.nextInt(6); i++) chapter(random.nextInt(8)),
    ];
    final value = BackupManga(
      source: Int64(1),
      url: '/m$index',
      title: 'Manga $index',
      favorite: chance(80) ? random.nextBool() : null,
      favoriteModifiedAt: chance(70) ? clock() : null,
      lastModifiedAt: clock(),
      version: Int64(random.nextInt(4)),
      customTitle: chance(30) ? pick(['Mine', 'Theirs']) : null,
      viewer: chance(30) ? random.nextInt(3) : null,
      chapterFlags: chance(30) ? random.nextInt(3) : null,
      updateStrategy: chance(20) ? random.nextInt(2) : null,
      notes: chance(20) ? pick(['note', 'other']) : null,
      viewerFlags: chance(20) ? random.nextInt(3) : null,
      initialized: chance(30) ? random.nextBool() : null,
      memo: chance(15) ? [random.nextInt(9)] : null,
      excludedScanlators: [
        if (chance(25)) pick(['Group', 'Other']),
      ],
      chapters: chapters,
      history: [
        for (final c in chapters)
          if (chance(30)) history(c.url),
      ],
      tracking: [if (chance(25)) tracking()],
      categories: [if (chance(50)) Int64(random.nextInt(3))],
    );
    maybeUnknown(value);
    return value;
  }

  BackupAnime anime(int index) {
    final episodes = [
      for (var i = 0; i < random.nextInt(5); i++) episode(random.nextInt(6)),
    ];
    final seasons = chance(40);
    final value = BackupAnime(
      source: Int64(2),
      url: '/a$index',
      title: 'Anime $index',
      favorite: chance(80) ? random.nextBool() : null,
      favoriteModifiedAt: chance(70) ? clock() : null,
      lastModifiedAt: clock(),
      version: Int64(random.nextInt(4)),
      episodeFlags: chance(30) ? random.nextInt(3) : null,
      updateStrategy: chance(20) ? random.nextInt(2) : null,
      viewerFlags: chance(20) ? random.nextInt(3) : null,
      excludedScanlators: [
        if (chance(25)) pick(['Group', 'Other']),
      ],
      id: seasons ? Int64(1 + index) : null,
      parentId: seasons && index > 0 && chance(50) ? Int64(1) : null,
      seasonFlags: seasons && chance(60) ? Int64(random.nextInt(4)) : null,
      seasonNumber: seasons && chance(60) ? random.nextInt(3).toDouble() : null,
      seasonSourceOrder: seasons && chance(50)
          ? Int64(random.nextInt(3))
          : null,
      fetchType: chance(40) ? random.nextInt(2) : null,
      backgroundUrl: seasons && chance(40) ? 'bg$index' : null,
      episodes: episodes,
      history: [
        for (final e in episodes)
          if (chance(30)) history(e.url),
      ],
      tracking: [if (chance(25)) tracking()],
      categories: [if (chance(50)) Int64(random.nextInt(3))],
    );
    maybeUnknown(value);
    return value;
  }

  List<BackupCategory> categories() {
    final names = ['Reading', 'Later', 'Done', 'Paused']..shuffle(random);
    return [
      for (var i = 0; i < 3; i++)
        BackupCategory(name: names[i], order: Int64(i)),
    ];
  }

  /// A library; with [basedOn], one that shares most entries with it and
  /// edited some of them.
  BackupMihon library({BackupMihon? basedOn}) {
    if (basedOn == null) {
      return BackupMihon(
        backupManga: [for (var i = 0; i < 1 + random.nextInt(5); i++) manga(i)],
        backupAnime: [for (var i = 0; i < random.nextInt(4); i++) anime(i)],
        backupCategories: categories(),
        backupAnimeCategories: categories(),
      );
    }
    final result = basedOn.deepCopy();
    for (var i = 0; i < result.backupManga.length; i++) {
      if (chance(40)) {
        final edited = manga(i);
        if (chance(50)) {
          edited.chapters
            ..clear()
            ..addAll(result.backupManga[i].chapters.map((c) => c.deepCopy()));
        }
        result.backupManga[i] = edited;
      }
    }
    for (var i = 0; i < result.backupAnime.length; i++) {
      if (chance(40)) result.backupAnime[i] = anime(i);
    }
    if (chance(30)) result.backupManga.add(manga(10 + random.nextInt(3)));
    if (chance(20) && result.backupManga.isNotEmpty) {
      result.backupManga.removeAt(random.nextInt(result.backupManga.length));
    }
    if (chance(20)) result.backupAnime.add(anime(10));
    if (chance(30)) {
      result.backupCategories
        ..clear()
        ..addAll(categories());
    }
    return result;
  }

  /// Changes [proposed] the way a faulty merge might.
  void tamper(BackupMihon proposed) {
    final manga = proposed.backupManga;
    final anime = proposed.backupAnime;
    switch (random.nextInt(9)) {
      case 0 when manga.isNotEmpty:
        manga[random.nextInt(manga.length)].title = 'Changed';
      case 1 when manga.isNotEmpty:
        final chapters = manga[random.nextInt(manga.length)].chapters;
        if (chapters.isNotEmpty) chapters.removeAt(0);
      case 2 when manga.isNotEmpty:
        manga[random.nextInt(manga.length)].customTitle = 'Tampered';
      case 3 when manga.isNotEmpty:
        manga[random.nextInt(manga.length)].unknownFields.clear();
      case 4 when manga.isNotEmpty:
        maybeUnknown(manga[random.nextInt(manga.length)]);
        manga.last.mergeUnknownFields(
          UnknownFieldSet()..mergeVarintField(920, Int64(1)),
        );
      case 5 when manga.isNotEmpty:
        final chapters = manga[random.nextInt(manga.length)].chapters;
        if (chapters.isNotEmpty) {
          chapters.first
            ..memo = [42]
            ..sourceOrder = Int64(99);
        }
      case 6 when anime.isNotEmpty:
        anime[random.nextInt(anime.length)]
          ..seasonFlags = Int64(7)
          ..backgroundUrl = 'tampered';
      case 7 when anime.isNotEmpty:
        final episodes = anime[random.nextInt(anime.length)].episodes;
        if (episodes.isNotEmpty) episodes.first.unknownFields.clear();
      case 8 when manga.isNotEmpty:
        manga.removeAt(random.nextInt(manga.length));
      default:
        if (manga.isNotEmpty) manga.first.excludedScanlators.add('Tampered');
    }
  }
}
