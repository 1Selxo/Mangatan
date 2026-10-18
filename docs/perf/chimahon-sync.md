# Chimahon sync performance

Status: one pass. The benchmark works and a baseline is recorded. Four
optimizations to the pre-upload safety audit are in, and a differential test
checks them against a verbatim copy of the old audit. Before/after figures
are below.

## What is measured

`test/perf/chimahon_sync_benchmark_test.dart` runs the Chimahon sync pipeline
through the production classes on a real Isar database. Only the transport is
replaced, by an in-memory gzip store, so no Google Drive, WebDAV or SyncYomi
server is contacted. Data comes from `test/perf/chimahon_sync_fixture.dart`:

- 400 favorite manga with 150 chapters each, 40 anime with 24 episodes each,
  12 Mihon sources, 5 categories, history, trackers on every second entry,
  and downloads.
- The remote is the projection of a second copy of the library after
  "another device" read 10 more chapters in a quarter of the entries, moved
  some entries to other categories, unfavorited a few, and added 40 new
  titles of 150 chapters.
- This device then reads 5 more chapters in other entries, so a two-way sync
  has to import and upload.
- Local protobuf payload is about 4.5 MB; the gzip remote is about 480 KB.

Fixture realism matters: the production audit rejects a payload where
`favoriteModifiedAt` is newer than the record clock, or where it is stored in
milliseconds, so the fixture keeps it in seconds and older than `updatedAt`.

Measured operations: local projection snapshot, local revision capture, codec
decode, merge, two-way preview, pre-upload safety gate, download-only plan,
importing the merged payload, the authoritative (download-only) import, a full
two-way sync with remote changes (with the engine's own phase timings), and a
sync with nothing to change. Each reports median and p90 total time and the
longest main-isolate stall.

```sh
MANGATAN_PERF=1 flutter test test/perf/chimahon_sync_benchmark_test.dart
```

`MANGATAN_PERF_RUNS` (default 12, after 3 warm-up runs) and
`MANGATAN_PERF_OUT=<file>` work as in the other benchmarks.

## Baseline (before any change)

Median of 12 runs, ms. The machine was shared with other agents, so the
noise is large (p90 is often 30–70 % above the median).

| Operation | Median | p90 |
|---|---|---|
| local projection snapshot | 308 | 374 |
| local revision capture | 625 | 826 |
| codec decode (gzip) | 62 | 116 |
| merge | 105 | 147 |
| two-way preview | 620 | 729 |
| pre-upload safety gate | 1585 | 2816 |
| download-only plan | 321 | 452 |
| import merged payload | 888 | 1051 |
| authoritative import | 1053 | 1288 |

From a 3-run pass (quieter): two-way sync with remote changes about 3.0 s.
Phases: export 147, decode 50, reconcile 142, serialize 59, encode 35,
**preUpload (safety gate) 1261**, recheck local (two exports) 355,
**import 789**, sidecars 57. A sync with nothing to change still spends about
760 ms importing and 420 ms re-exporting.

The work is synchronous, so the longest main-isolate stall equals the
operation time in almost every case.

### Where the safety gate's time goes

Timed by hand-inserting stopwatches (since removed), one gate call:

| Part | ms |
|---|---|
| preview getters (four defensive deep copies) | 60–90 |
| `ChimahonMediaSafetyAudit` | 1180–1760 |
| generic collection and local intent audits | < 4 |

Inside the media audit: season namespace and copies 66, duplicate checks
37–55 each, tombstone clocks plus identity union 262, manga transition
(remote side) 427, manga transition (local side) 333, anime 20.

## Optimizations so far

| Id | Change | File | State |
|---|---|---|---|
| S1 | Unknown-field envelope check returns `true` straight away when the winner, loser and proposal all have no unknown fields (the full check provably returns `true` then: no tag can be missing and both envelopes encode to zero bytes) | `chimahon_media_safety_audit.dart` | done |
| S2 | Chapter and episode expected projections clear their already private copy in place instead of deep-copying it again | `chimahon_media_safety_audit.dart` | done |
| S5 | Manga and anime portable projections copy every field except the child lists they are about to clear (chapters/episodes, categories, tracking, history), instead of deep-copying 150 chapters and then discarding them | `chimahon_media_safety_audit.dart` | done |
| S3 | `chimahonCanonicalChildNumber` rounds to float32 through a reused one-element `Float32List` instead of allocating one per call (same rounding) | `chimahon_child_identity.dart` | done |

First look after S1, S2, S3, S5 (3 runs, noisy): media audit 1065 ms against
1180–1760 before; the whole gate 1.1–1.6 s against 1.2–2.1 s. This is not yet a
reliable before/after figure.

## After S1, S2, S3, S5

Same benchmark, 12 runs after 3 warm-ups, on a quieter machine (load average
about 3). One run of the code before the change and two runs after, one
after the other. Median (p90), ms:

| Operation | before | after (run 1) | after (run 2) |
|---|---|---|---|
| pre-upload safety gate | 1260 (1544) | 940 (1388) | 934 (1001) |
| two-way sync with remote changes | 3283 (3971) | 3011 (3665) | 2717 (3005) |
| sync with nothing to change | 1932 (2243) | 1785 (2690) | 1426 (1816) |
| two-way preview | 465 (514) | 469 (525) | 436 (488) |
| merge | 93 (116) | 99 (127) | 86 (106) |

The safety gate, the only part these changes touch, is about 320 ms (26 %)
faster in both runs after the change. Its longest main-isolate stall falls
from 1205 to about 890 ms. The whole-sync totals also include the import and
the local exports, which these changes do not touch, and they vary by
200–400 ms between runs. Their drop is mostly the gate, plus noise. Import
times (595–808 ms) varied just as much without any change to that code.

## Equivalence evidence

- Existing suites pass: `chimahon_media_safety_audit_test.dart`,
  `chimahon_sync_safety_audit_test.dart`, `chimahon_small_identities_test.dart`
  (126 tests).
- `test/services/sync/chimahon_media_safety_audit_equivalence_test.dart`
  compares the current audit with
  `test/services/sync/legacy/legacy_chimahon_media_safety_audit.dart`, a
  verbatim copy of the audit before S1, S2 and S5. It builds a random remote
  and local library for each of 400 seeds: manga and anime with chapters,
  episodes, history, tracking, categories, unknown fields in about 20 % of
  records, and season fields. It merges them with the production merger and
  tampers with one in three proposals. Every `fail` and `observe` code and its
  affected list must match. The run must include more than 40 failing and more
  than 40 clean cases. A second test checks `chimahonCanonicalChildNumber`
  (S3) against `Float32List.fromList` rounding.
- Mutation checks: skipping the repeated fields in the S5 copy, and not
  copying `notes`, are both caught. Breaking the S1 shortcut so it ignores the
  loser is not caught. The random generator rarely gives the loser unknown
  fields while the winner and proposal have none. S1 relies on reasoning: when
  none of the three has unknown fields, no tag can be missing and both
  envelopes encode to zero bytes, so the full check returns `true`.

## Candidates not yet tackled

- Import (`ChimahonSyncImporter.apply`): about 760–890 ms even when nothing
  changes. Not investigated yet.
- `canonicalizeChimahonChapters` deep-copies every chapter and is called
  several times per entry by the audit and merger. A non-copying read-only
  variant for the audit is possible, but the merger may mutate its results.
- The download-only flow builds the projection four times and the revision
  three times by design (it re-checks local state between steps); each
  capture is about 0.6 s. Left alone: the repetition is part of the safety
  behavior.
- Local revision capture is dominated by Isar's JSON export and SHA-256; it was
  already optimized upstream.

## Not changed

Native (non-Chimahon) Mangayomi sync, backup/restore code, and
`docs/performance.md` were not touched.
