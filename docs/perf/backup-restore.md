# Backup and restore performance

Creating a backup, reading one, previewing what restoring it would do, and
restoring it (replace and merge) on a large library. The rule is the same as
in `docs/performance.md`: behavior must not change, only speed.

## What is measured

`test/perf/backup_restore_benchmark_test.dart` runs on a real Isar database
with 400 manga, 60 anime and 40 browsed (non-favorite) entries of 150
chapters each (75,000 chapters), 1,380 history rows, 1,840 updates, 8,333
downloads, categories, tracks, track preferences, 24 sources with source
preferences, custom buttons and per-entry chapter settings. The full backup
holds 460 entries and is a 25 MB JSON file, 1.2 MB zipped.

| Bench | What it runs |
|---|---|
| `backup_create_all` | `writeMangayomiBackupZip` with every part (also the pre-import safety backup) |
| `backup_create_library` | the same with library, categories and chapters only |
| `backup_decode` | `readMangayomiBackupJson`, the decompress and parse step of `decodeMangayomiBackup` |
| `backup_preview_mangayomi` | `previewMangayomiBackup` against a library that already holds the backup's entries |
| `restore_replace` | `restoreBackupProvider` (replace) |
| `restore_merge` | `restoreBackupProvider(merge: true)` into a library holding half of the backup |

Each bench reports the median and 90th percentile of the wall time and of
the longest stall of the calling isolate (a 1 ms periodic timer; no
threshold applied).

```sh
MANGATAN_PERF=1 flutter test test/perf/backup_restore_benchmark_test.dart
```

`MANGATAN_PERF_RUNS` (default 12, after 3 warm-up runs) and
`MANGATAN_PERF_OUT=<file>` work as in the other benchmarks.

## Optimizations

| Id | Change | File |
|---|---|---|
| R1 | Replace restore: find each update's chapter in a map keyed by (manga id, chapter name), built once with the first chapter in id order, instead of a linear search of all chapters per update | `restore.dart` |
| R2 | Replace restore: read each manga once while linking chapters, instead of once per chapter | `restore.dart` |
| M1 | Merge restore: read an entry's existing chapter URLs through the `mangaId` index as a URL property query, instead of a full-table filter scan that loads whole chapters | `restore.dart` |
| M2 | Merge restore: find each update's chapter in a per-entry map (chapter name to lowest-id chapter, read through the index once per entry) instead of a full-table filter query per update | `restore.dart` |
| M3 | Merge restore: read each new manga once while linking chapters | `restore.dart` |
| P1 | Mangayomi and Tachiyomi previews: existing chapter URLs through the index as a property query (as M1) | `backup_format.dart` |
| I2 | Decompress and parse a Mangayomi backup on a background isolate (`readMangayomiBackupJson`); the file is still opened on the UI isolate first, so a missing file fails before the password prompt as before | `backup_decoder.dart` |

Why these are exact:

- R1: `tempChapters` is in id order and the old code took `firstOrNull`; the
  map keeps the first chapter per key (`putIfAbsent`), with records comparing
  `null` names the same way `==` did.
- M2: the old `findByMangaIdAndName` is a filter query, which scans in id
  order and returns the lowest id. The map keeps the lowest id per name
  (`null` included). No chapter is written during the update loop, so the
  per-entry map stays valid.
- M1, P1: the index equality returns the same rows as the
  `mangaIdEqualTo` filter; only the set of non-null URLs is used.
- R2, M3: no manga is written while chapters are linked; the link stores
  only the id.
- I2: the same code runs in `Isolate.run`; errors are rethrown to the caller,
  which catches every error the same way.

## Equivalence evidence

`test/modules/more/data_and_storage/backup_restore_equivalence_test.dart`
runs the current code and a verbatim copy of the previous code
(`legacy_backup_restore.dart`) on two identically seeded databases and
compares every table, row by row with its links. The data covers duplicate
chapter names in one entry, chapters without name or URL, orphaned chapters,
updates, downloads and history pointing nowhere, a browsed anime season
included through its parent, same-named categories of different item types,
and (for merge) stale chapters left under the ids the merge gives its new
entries. It checks replace restore, merge restore with and without category
and source decisions, both previews, and that the isolate decode returns the
same JSON as inline decoding and still fails on missing or corrupt files.

Mutation check, one at a time, each made the test fail:

- R1 with "last chapter wins": replace restore fails.
- M2 with "highest id wins": merge restore fails.
- M1 with an incomplete URL set: merge restore fails.
- P1 with an incomplete URL set: both previews fail.

## Results

Median (p90) of 15 runs, milliseconds, same machine and session. The machine
was shared with other agents, so run-to-run noise is large (the create rows,
which no change touches, moved by about 100 ms between runs).

| Bench | Before | After | Longest stall before | Longest stall after |
|---|---|---|---|---|
| restore, replace | 1186 (1621) | 681 (1014) | same as total | same as total |
| restore, merge | 2204 (2611) | 499 (592) | same as total | same as total |
| preview, Mangayomi | 816 (1012) | 327 (478) | same as total | same as total |
| read backup file | 328 (449) | 340 (1393) | 328 (449) | 9 (33) |
| create backup, everything | 703 (1025) | 812 (945) | 357 (605) | 429 (541) |
| create backup, library only | 979 (1159) | 904 (1281) | 634 (732) | 484 (713) |

Phase timing before the change (one run, merge into the half library):
chapter linking 400 ms and update lookups 900–1000 ms in merge; update
lookups 110–430 ms and chapter linking 180 ms in replace. After it, merge
spends about 220–320 ms writing chapters and replace about 180 ms; both are
Isar writes.

## Measured but not changed

- Writing the archive on a background isolate was tried. The longest stall
  while creating a backup didn't improve beyond the noise, because it comes
  from collecting rows and `jsonEncode` (about 100 ms each), not from
  compressing, which yields between steps. It was dropped.
- Streaming the JSON with `JsonUtf8Encoder` instead of
  `jsonEncode` + `writeAsString` would skip a 25 MB string, but it writes
  lone surrogates differently from `utf8.encode`, so the backup bytes could
  change.
- Compressing with `dart:io`'s zlib would be much faster but produces
  different archive bytes.
- Collecting the backup rows off the UI isolate would need a second Isar
  instance in a background isolate and the repositories rebound to it; not
  attempted in this pass.
- The restore's per-row `putSync` calls already save links once (a second
  `saveSync` is a no-op), and `putAllSync` loops over the same call, so
  batching them gains nothing.
- The Tachiyomi/Mihon restore (`restoreTachiBkBackupData`) was not
  benchmarked: it runs the Chimahon pending-restore store, mining settings,
  immersion statistics and the Mihon factory refresh, which need the native
  bridge and storage. Its preview is covered by P1.

## Verification state

- Done and covered by the equivalence test: R1, R2 (replace restore runs in
  the test), M1, M2, M3, P1, I2. R2 and M3 have no dedicated mutation check.
- `flutter analyze`: no issues. `git diff --check`: clean.
- The equivalence test passes. The full `flutter test` suite was started but
  stopped before finishing when this pass was wrapped up; it still has to be
  run.
- Ablation (all minus one) was started and stopped after the before and after
  runs; only those two are recorded above.
