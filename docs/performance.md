# Performance measurement

This document explains how Mangatan's performance is measured and records
the results of each optimization. Keep it current: when you add a
measurement or an optimization, add its numbers here.

The rule for every optimization is that behavior must not change. Results,
ordering, UI and side effects stay identical; only speed changes. Every
optimization below has an equivalence test or an old-versus-new comparison.

## What is measured

`lib/services/perf/` records a sample for each common flow:

| Flow | Where it is traced |
|---|---|
| `browse_source` | `getPopular`, `getLatestUpdates`, `search` |
| `open_entry` | `MangaReaderDetail._init` (detail fetch and store) |
| `open_chapter` | `getChapterPages` |
| `open_episode` | `getVideoList` |
| `load_media` | `CustomExtendedNetworkImageProvider` |
| `transition` | `PerfRouteObserver`, every push and pop |

Each sample has:

- **Total time.**
- **Network time:** the union of the HTTP request intervals made inside the
  flow. Overlapping requests count once. Requests go through `MClient` (wrapped
  in `PerfHttpClient` while a trace is active) and the Mihon bridge
  (`PerfMetrics.network`).
- **Processing time:** total minus network.
- **Frames** for flows that watch them: frames rendered, janky frames,
  dropped frames and the worst build and raster times. The frame budget comes
  from the display's reported refresh rate (falling back to the shortest
  observed vsync gap). It is never hardcoded. A frame that takes longer than
  the budget drops `ceil(max(build, raster) / budget) - 1` frames.

Traces are zone-scoped, so work started inside a flow is attributed to it.
Background work that must not count (reader preloading, downloads, OCR) runs
in `PerfMetrics.untraced`.

Samples go to the Dart developer timeline and `postEvent` (visible in
DevTools) and are printed only in non-release builds. They never reach the
user-visible log.

## The two harnesses

### Flow benchmark (JIT, processing time)

`test/perf/flow_benchmark_test.dart` runs the flows end to end through the
real providers, the real Mihon service and HTTP stack, and a real Isar
database. Only the extension server is fake: a loopback server with 120 ms of
latency per request, 25 other installed sources and 400 KB extension APKs,
so source lookups and request bodies cost what they cost in the app.

```sh
MANGATAN_PERF=1 flutter test test/perf/flow_benchmark_test.dart
```

`MANGATAN_PERF_RUNS` sets the measured runs (default 12, after 3 warm-up
runs). `MANGATAN_PERF_OUT=<file>` writes the results as JSON. The test is
skipped without `MANGATAN_PERF`.

It reports medians and 90th percentiles of total, network and processing
time, plus the longest stall of the main isolate during each flow.

### Frame harness (profile build, real frames)

`tool/perf/frames_main.dart` is an app entry point that opens a throwaway
database and data folder, serves the fake extension server from a separate
isolate, pushes the real screens with the app's route type, prints one
`BENCH` line per scenario and quits. The user's own data is never touched.

```sh
./scripts/build_macos.sh --profile --no-open -- -t tool/perf/frames_main.dart
build/macos/Build/Products/Profile/Mangatan.app/Contents/MacOS/Mangatan
```

Dart defines:

- `MANGATAN_PERF_RUNS`: measured opens per scenario (default 8, after 2
  warm-up opens).
- `MANGATAN_PERF_ONLY`: run one scenario (`browse_source`, `open_entry_new`,
  `open_entry_library`, `open_chapter`, `open_episode`).
- `MANGATAN_PERF_HOLD`: seconds to stay open afterwards, for a profiler.

Each scenario pushes a screen, waits for its flow sample and transition,
leaves it open for 1.5 s so image loads and follow-up builds land in the
measured window, then pops it. `screen_open` covers every frame from the push
until the screen has settled.

Pitfalls:

- A hidden or covered window gets no vsync and renders nothing. The harness
  pins its window on top at 1200×800. Don't cover it while it runs, and don't
  compare runs taken at different window sizes.
- On macOS a push completes without animating, so push transitions report no
  frames. Pops animate.
- The episode player opens against video URLs on a reserved `.example` host
  that never resolves, so the player screen loads but no video plays.

### Measuring one optimization

To measure a single optimization, run the harness on the full set of changes
and again with only that optimization reverted, under the same conditions.
Run the full set twice to see the run-to-run noise; only differences larger
than that noise are reported below.

## Optimizations

| Id | Change | File |
|---|---|---|
| O1 | Link new chapters to their manga in one database call (`manga.chapters.update(link:)`) instead of one call per chapter | `update_manga_detail_providers.dart` |
| O2 | Remember `rawSeasonAndNumber` results per title and chapter name (capped at 50,000 entries) | `chapter_recognition.dart` |
| O3 | Mihon bridge: encode the full APK body only when the server needs it, check for HTML without lower-casing the whole body, decode each response body once | `bridge_http_client.dart` |
| O4 | Parse each Mihon response's JSON once for the Cloudflare check, the error check and the result | `service.dart` |
| O5 | `getSource` queries only the rows that can match (by id, otherwise by language) instead of loading every installed source with its extension | `utils.dart` |
| O6 | When opening a chapter, skip the downloaded-page lookups if the chapter folder doesn't exist, otherwise run them together | `get_chapter_pages.dart` |
| O7 | The detail screen's sources stream watches only the rows that can match | `manga_detail_main.dart` |

Equivalence evidence:

- O1: `test/modules/manga/update_manga_detail_links_test.dart`. Also, the old
  and new code were run on the same first open (300 chapters) and refresh
  (20 new chapters): every stored chapter, update and link was identical apart
  from the `updatedAt` write time.
- O2: `test/utils/chapter_recognition_memo_test.dart`.
- O3: `test/eval/mihon/bridge_http_client_body_test.dart`.
- O5 and O7: `test/utils/get_source_test.dart`.

## Results

### Processing time, one optimization at a time

Flow benchmark, median of 30 runs, milliseconds. "All" is every optimization
(two runs, for noise). Each other column reverts one optimization.

| Flow | All | −O1 | −O2 | −O3 | −O4 | −O5 | −O6 |
|---|---|---|---|---|---|---|---|
| browse source | 5.0 / 3.2 | 5.2 | 5.6 | **9.0** | 5.6 | 5.4 | 4.5 |
| open entry | 22.1 / 24.6 | **64.7** | **33.1** | **37.4** | **31.4** | **38.3** | 23.1 |
| open chapter | 7.0 / 9.1 | 12.2 | 10.5 | **15.1** | 12.3 | **24.7** | **20.3** |
| open episode | 7.5 / 7.6 | 7.7 | 7.8 | **11.4** | 7.5 | **18.7** | 6.6 |
| load image (cache miss) | 2.9 / 2.4 | 2.7 | 3.0 | 3.6 | 3.0 | 2.2 | 2.7 |
| detail build, first | 2.6 / 1.8 | 1.8 | **6.0** | 2.9 | 2.8 | 2.7 | 2.7 |
| detail build, later | 1.8 / 1.3 | 1.3 | **5.0** | 1.9 | 1.8 | 1.8 | 1.8 |

Bold marks a difference larger than the noise between the two "All" runs.

Longest main-isolate stall: without O5 it is 15–17 ms when opening an entry,
chapter or episode, against 5–9 ms with it. Without O3 it is about 9.5 ms in
most flows, against 5–6 ms.

O7 changes a widget stream the benchmark doesn't exercise. Measured directly
on the same 26 installed sources (median of 30): the stream's first result
takes 0.56 ms instead of 6.23 ms, and loading its rows on the UI isolate
0.27 ms instead of 5.78 ms (1 row instead of 26).

### Frames, one optimization at a time

Frame harness, profile build on macOS at 1200×800, 16 opens per scenario.
The display reported a 16.7 ms frame budget.

Dropped frames while the screen loads (`screen_open`, total over 16 opens):

| Screen | All | −O1 | −O2 | −O3 | −O4 | −O5 | −O6 | −O7 |
|---|---|---|---|---|---|---|---|---|
| new entry | 4 / 3 | 1 | **17** | 0 | 1 | 4 | 4 | 7 |
| library entry | 8 / 8 | 6 | **25** | 5 | 10 | 4 | 6 | 2 |
| browse source | 1 / 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| chapter | 0 / 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

Dropped frames during the pop transition (total over 16):

| Screen | All | −O1 | −O2 | −O3 | −O4 | −O5 | −O6 | −O7 |
|---|---|---|---|---|---|---|---|---|
| new entry | 9 / 9 | 10 | **17** | 9 | 10 | 11 | 10 | 10 |
| library entry | 11 / 13 | 12 | **17** | 13 | 10 | 6 | 12 | 9 |
| browse source | 0 / 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| chapter | 0 / 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

Push transitions dropped no frames in any variant (on macOS they don't
animate).

Worst build time while the screen loads (median, ms):

| Screen | All | −O1 | −O2 | −O3 | −O4 | −O5 | −O6 | −O7 |
|---|---|---|---|---|---|---|---|---|
| new entry | 14.2 / 12.6 | 11.2 | **28.1** | 12.5 | 15.3 | 12.8 | 14.9 | 16.4 |
| library entry | 16.0 / 16.3 | 15.2 | **22.2** | 14.9 | 16.4 | 15.1 | 14.5 | 12.7 |
| browse source | 7.0 / 7.5 | 7.4 | 6.9 | 6.4 | 7.2 | 7.0 | 7.2 | 7.3 |
| chapter | 6.3 / 5.9 | 5.8 | 5.7 | 4.3 | 6.4 | 6.0 | 4.9 | 6.2 |

Flow processing time in the real engine (median, ms):

| Flow | All | −O1 | −O2 | −O3 | −O4 | −O5 | −O6 | −O7 |
|---|---|---|---|---|---|---|---|---|
| browse source | 1.1 / 1.0 | 1.0 | 1.0 | **6.1** | 1.4 | 1.1 | 1.0 | 1.0 |
| open entry, new | 29.9 / 30.2 | **52.6** | 33.4 | 35.0 | 34.5 | **45.0** | 31.9 | 30.9 |
| open chapter | 132.6 / 133.1 | 134.8 | 132.3 | 139.2 | 134.8 | **155.2** | **146.4** | 136.4 |

What this shows:

- O2 is the only optimization with a clear frame effect: it halves the worst
  frame on the entry screen and removes most of its dropped frames.
- O1, O3, O4, O5 and O6 cut processing time; their frame differences are
  within the noise.
- O7 shows no frame benefit in this run. The library entry dropped fewer
  frames without it (2 against 8), which is inside the noise between variants
  (2 to 10).
- Source and reader screens: the worst build time is 4.3–7.5 ms in every
  variant, well under the budget, and no variant dropped a frame there.
  Reverting O3 (and, on the reader, O6) gives the lowest worst build. Faster
  completion appears to bunch the work into one frame instead of spreading it
  across several. The cost is 1–2 ms and was left as is.

Episode screen (`AnimePlayerView`, 16 opens; the player opens but plays no
video, see Pitfalls):

| Measure | All | −O1 | −O2 | −O3 | −O4 | −O5 | −O6 | −O7 |
|---|---|---|---|---|---|---|---|---|
| flow processing, median ms | 6.4 / 6.8 | 6.3 | 6.4 | **11.1** | 6.3 | **22.8** | 6.8 | 6.9 |
| dropped frames while loading, total | 4 / 2 | 5 | 6 | 0 | 10 | 8 | 0 | 5 |
| dropped frames on pop, total | 1 / 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| worst build while loading, median ms | 14.9 / 15.8 | 16.2 | 16.1 | **10.3** | 14.9 | 16.0 | 15.9 | 16.2 |
| worst build while loading, p90 ms | 17.8 / 17.1 | 16.9 | 16.7 | **12.1** | 17.1 | 16.8 | 16.4 | 17.1 |

O3 and O5 cut the episode's processing time. Dropped frames vary from 0 to
10 across variants with no pattern, which is noise. Reverting O3 lowers the
worst build, as on the source and reader screens.

To find which part of O3 does this, each of its three parts was reverted on
its own (16 opens each; "All" is three runs, −O3 two):

| Variant | Processing, median ms | Dropped while loading, total | Worst build, median ms | Worst build, p90 ms |
|---|---|---|---|---|
| All | 6.4 / 6.8 / 7.0 | 4 / 2 / 2 | 14.9 / 15.8 / 16.2 | 17.8 / 17.1 / 16.9 |
| −O3 (all three parts) | 11.1 / 10.1 | 0 / 1 | 10.3 / 9.0 | 12.1 / 12.4 |
| −O3a (encode the APK body only when needed) | 11.1 | 0 | 9.6 | 12.4 |
| −O3b (HTML check without lower-casing) | 6.8 | 2 | 16.1 | 16.8 |
| −O3c (decode each body once) | 7.2 | 0 | 15.8 | 16.4 |

The whole effect comes from O3a, which is also where O3's processing saving
comes from. With O3a the flow finishes about 4 ms sooner, and the worst build
is about 6 ms longer. The work O3a removes is not build work, so the most
likely explanation is timing: the screen's follow-up builds (and possibly a
garbage collection) now land in the same frame instead of being spread over
several. This hasn't been confirmed with a profiler. O3a is kept: dropped
frames stay within the noise, and the worst build stays under the budget at
the median.

## Library

The library screen re-runs its filter and sort on every library change and
every settings change, per category tab. `test/perf/library_benchmark_test.dart`
measures this on a real Isar database with 500 entries of 150 chapters each,
downloads, history, updates and per-entry chapter and scanlator filters:

```sh
MANGATAN_PERF=1 flutter test test/perf/library_benchmark_test.dart
```

`MANGATAN_PERF_RUNS` and `MANGATAN_PERF_OUT` work as in the flow benchmark.
Each run uses library entries freshly read from the database, as the library
stream delivers them, so chapter links start unloaded.

| Id | Change | File |
|---|---|---|
| L1 | Load an entry's chapters only when an active filter or the sort reads them | `library_filter_provider.dart` |
| L2 | Count unread chapters for many entries with one settings read (`unreadChaptersCounter`) instead of one per entry | `manga_extensions.dart`, `library_filter_provider.dart`, `library_body.dart`, `tv_anime_home_view.dart` |
| L3 | Build each category tab's entry list once per library snapshot and settings object, and reuse it for the tab and its badge | `library_filter_provider.dart`, `library_body.dart` |

Equivalence evidence: `test/modules/library/library_filter_equivalence_test.dart`
compares the filter with a verbatim copy of the previous implementation over
every sort type, every filter value and 400 random combinations (search,
ignore-filters-on-search, downloaded-only, source filter). It also checks the
unread counter against the per-entry count, including an entry with two
scanlator filters (the first wins) and one with an empty filter, and checks
the tab lists against the previous inline filter. Replacing "first filter
wins" with "last filter wins" makes it fail.

Median of 20 runs, milliseconds:

| Measure | Before | After |
|---|---|---|
| filter + sort, alphabetical | 35.6 | 0.2 |
| filter + sort, last read | 33.9 | 0.1 |
| filter + sort, last update | 37.0 | 0.1 |
| filter + sort, date added | 34.5 | 0.1 |
| filter + sort, unread count | 82.2 | 37.1 |
| filter + sort, total chapters | 34.0 | 34.6 |
| filter + sort, latest chapter | 37.0 | 34.8 |
| unread + downloaded filters | 35.8 | 34.1 |
| category tab rebuild (unread sort, list reused) | 11.3 | 0.01 |
| tile badges (unread and download counts, all entries) | 79.5 | 82.0 |
| library stream emission | 1.0 | 1.0 |
| history stream emission | 0.8 | 0.8 |
| updates stream emission | 2.5 | 2.6 |

Sorts and filters that read chapters still have to load them; what remains
is the database read of each entry's chapter links. Tile badges are unchanged
because each tile still reads the settings when it builds; sharing one read
across tiles would change when a settings change reaches a tile.

L3 caches by the identity of the library list and the settings object, both
of which are replaced whenever either changes. In the moment between a
settings write and the settings stream delivering it, a tab shows the list
built from the previous settings, exactly as the previous code would have,
since it read the same settings object.

## Library update

`library_update_entry` in the flow benchmark refreshes a stored entry the
way a library update does (`updateMangaDetail` with `isInit: false`), with
120 ms of network latency per request. Median of 20 runs: 288 ms total, of
which 259 ms network and 29 ms processing; the longest main-isolate stall is
9.4 ms. Processing is in line with opening an entry and no single step stands
out. The refresh rewrites every stored chapter because their `updatedAt`
changes, which is part of the current behavior and was kept.

## Open findings

- Every chapter open loads its page list twice.
- Desktop extension requests make two health-check round trips first.

Both were left unchanged because changing them changes when requests are
made.

- With O3a, the episode screen's worst build is about 6 ms longer while its
  processing is 4 ms shorter (see the O3 split above). The cause is believed
  to be timing, but this is unconfirmed.
