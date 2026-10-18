# Downloads performance

This covers queueing chapter and episode downloads, the download worker,
progress updates, the download queue screen, downloaded-chapter lookups and
CBZ conversion. The method follows `docs/performance.md`: behavior must not
change, every optimization has an equivalence test, and only speed changes.

## What is measured

`test/perf/downloads_benchmark_test.dart` runs the download code's
main-isolate work on a real Isar database and real files in a temporary
folder. It uses the same repository calls and helpers the app uses. The
database holds 200 library entries with 15 finished downloads each (3,000 in
all). Another entry has 300 chapters, which get queued as "download all"
queues them. Downloaded chapters have 60 pages, using the 190 KB screenshot
JPEG as each page.

Page transfers run in the download isolates against the network, so they are
not part of this benchmark. Each measurement reports the median and 90th
percentile of total time, plus the longest main-isolate stall. The stall is
the longest gap between ticks of a 1 ms timer, so it shows how long the UI
could not draw.

| Benchmark | What it runs |
|---|---|
| `download_all_300` | `MangaDetailView._downloadChaptersWithDestination`: look up 300 chapters' download state, then queue them |
| `enqueue_300_one_by_one` | 300 separate single-chapter queue taps |
| `enqueue_one_behind_299` | one tap with 299 chapters already queued |
| `get_by_chapter_id_300` | `getByChapterId` for 300 chapters (chapter tiles, swipe backgrounds, download all) |
| `tile_streams_first_emit_30` | first value of 30 visible chapter tiles' `watchByChapterId` streams |
| `tile_streams_progress_write` | one progress write while 30 tiles listen |
| `queue_screen_emission` | one build of the download queue screen's data (3,300 downloads) |
| `process_downloads_prepare` | `processDownloads` reading and ordering 300 pending downloads |
| `progress_write` | one `setProgress` database write |
| `select_next_downloads_25` | "download next 25" selection |
| `page_probe_fresh_60` | the per-page "already on disk?" probe for a new 60-page chapter |
| `downloaded_chapter_lookup_60` | `findDownloadedChapterIn` on a 60-page folder |
| `convert_to_cbz_60` | `convertToCBZ` for 60 pages (runs in `compute`) |
| `forbidden_character_names_300` | chapter folder names for 300 chapters |

```sh
MANGATAN_PERF=1 flutter test test/perf/downloads_benchmark_test.dart
```

`MANGATAN_PERF_RUNS` sets the measured runs (default 12, after 3 warm-up
runs). `MANGATAN_PERF_OUT=<file>` writes the results as JSON. The test is
skipped without `MANGATAN_PERF`.

## Findings

Every database write transaction costs about 4–9 ms to commit on the test Mac
(an empty transaction costs 0.004 ms). The work inside a transaction is small
by comparison. Queueing 300 chapters was 300 commits back to back. That loop
only ever awaits futures that are already complete, so it never yields to the
event loop, and the whole queue operation was one UI stall: 1.1–1.7 s.

Download-state lookups by chapter id used a filter query. A filter query scans
every download row (3,000+) instead of reading one row by primary key. Each
visible chapter tile does this up to twice per build (swipe backgrounds) and
once per stream emission. "Download all" does it once per chapter.

## Optimizations

| Id | Change | File |
|---|---|---|
| D1a | `DownloadRepository.enqueueAll` queues a batch in one write transaction. It runs the same per-chapter body, in the same order, as one `enqueue` per chapter. "Download all", the selection download and the queue screen's restart button use it | `download_repository.dart`, `manga_detail_view.dart`, `state_providers.dart`, `download_queue_screen.dart` |
| D1b | Inside `enqueue`, read only the pending ids (same id order) and check queue-order membership through a set | `download_repository.dart` |
| D2 | `getByChapterId` reads the row by primary key (`getSync`); a null id returns null | `download_repository.dart` |
| D3 | `watchByChapterId` watches a primary-key `where` query; a null id keeps the filter query | `download_repository.dart` |

If the batched transaction throws, it is rolled back. `enqueueAll` then
queues the chapters one by one exactly as before. A failure therefore leaves
the same partial queue and raises the same error as the old loop.

## Equivalence evidence

`test/repositories/download_repository_equivalence_test.dart` keeps a verbatim
copy of the previous `enqueue`, `getByChapterId` and `watchByChapterId`. It
checks the following:

- Over 12 seeded databases: `enqueueAll` against one old `enqueue` per
  chapter, and the new `enqueue` against the old one. The databases mix
  finished, queued, failed and unqueued chapters, use descending ids, have a
  partial saved order or no settings row, and the batches are shuffled with
  repeats. Every download row, its chapter link and the saved queue order must
  match.
- A batch with a broken chapter in the middle gives the same partial result
  and error type as the old loop.
- `getByChapterId` returns the same row for null, missing and present ids.
- `watchByChapterId` emits the same values as the old stream, the same number
  of times. The sequence covers queueing, progress writes, writes to unwatched
  rows, deletion and re-creation, and a null id.

Mutation checks: dropping some pending ids from the saved order fails 11
tests. Removing the one-by-one fallback fails the partial-failure test.

## Results

These are two back-to-back runs under the same conditions, before and after,
with 8 measured runs each, in milliseconds (median / p90). Other agents were
using the machine, so commit costs vary between runs. The batched path is
far beyond that noise.

| Benchmark | Before | After |
|---|---|---|
| download all (300 chapters) | 1695.5 / 2308.0 | **62.4** / 105.3 |
| longest UI stall during download all | 1695.6 / 2308.1 | **62.5** / 105.4 |
| 300 single taps (D1b only) | 1518.0 / 3051.5 | 1172.5 / 1312.6 |
| one tap behind 299 queued | 4.9 / 5.9 | 3.0 / 4.3 |
| `getByChapterId` × 300 | 38.4 / 45.1 | **0.41** / 0.55 |
| 30 tile streams, first value | 15.1 / 19.0 | **10.4** / 11.5 |
| progress write with 30 tiles listening | 5.2 / 6.7 | 5.0 / 5.1 |

The first full baseline run (12 runs, quieter machine) gave: download all
1097.8 ms, `getByChapterId` × 300 21.4 ms, 30 tile streams 6.2 ms. Single
taps are commit-bound, and their difference is mostly noise; D1b mainly
matters inside the batched transaction, where 300 full scans of the pending
rows would otherwise run.

A first attempt at an all-minus-one ablation was stopped when the scope was
reduced to one pass. Its logs could not be matched reliably to variants, so
none of its numbers are used here.

## Measured, not changed

| Benchmark | Median | Why it was left alone |
|---|---|---|
| queue screen emission (3,300 downloads) | 18–23 ms | Most of the cost is loading each download's chapter and manga links. Isar does not expose a link's target id without loading it, and caching across emissions would show stale chapter names after a rename. |
| `convert_to_cbz_60` | 250–300 ms | Runs in `compute`, so the UI isolate stays free (stall 3.5–4 ms). Most of the time goes to deflating already-compressed JPEGs. Storing them uncompressed would make the archive bytes different. |
| progress write | 4–9 ms | One commit, already rate-limited to visible percentage changes at most every 500 ms. |
| page probe, fresh 60-page chapter | 1.1–1.6 ms | Small. |
| downloaded chapter lookup, 60 pages | 0.7 ms | Small. |
| process downloads start, 300 pending | 0.9–1.4 ms | Small. |
| next 25 selection | 0.5 ms | Small. |

Also deliberately not changed, because they change when requests are made:

- `downloadChapter` polls every second (`Future.doWhile` with a 1 s delay)
  for the page list or video list to resolve. Each download therefore starts
  its transfers at least 1 s after the gate grants it a slot, even when pages
  resolve sooner. With per-source serialization this adds about 1 s per
  chapter to a long queue. It also paces requests to the source.
- The worker downloads a chapter's pages strictly one at a time
  (`MDownloader.concurrentDownloads` is 1), and each batch waits for its
  slowest page.
