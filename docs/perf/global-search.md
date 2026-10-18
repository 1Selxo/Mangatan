# Global search performance (work in progress)

Status: one pass. Two optimizations are implemented and merged. The JIT
benchmark has baseline numbers and the widget equivalence test passes. The
frame harness is built but has not been run, so there are no after-figures
yet.

## What is measured

`test/perf/global_search_benchmark_test.dart` (gated by `MANGATAN_PERF`,
`MANGATAN_PERF_RUNS`, `MANGATAN_PERF_OUT`) runs against a real Isar database
with 30 installed manga sources, 20 sources of other types (400 KB APK each)
and a library of 800 favorites plus 3000 browsed entries, some named like the
search results. The loopback fake extension server adds 120 ms per request.

```sh
MANGATAN_PERF=1 flutter test test/perf/global_search_benchmark_test.dart
```

| Measurement | What it does |
|---|---|
| `source_list_all` / `source_list_pinned` | Loads the searched sources as the screen does when it opens |
| `global_search_all_sources` | Searches all 30 sources through the real `searchProvider` and the screen's `FetchGate(3)` |
| `cards_first_lookup` | 300 result cards (10 per row) each subscribe the library lookup `watchFavoritesByItemTypeAndName` and get a first result |
| `cards_resubscribe_all` | The previous cost of one rebuild of the result list: every card drops its watch and subscribes again |
| `cards_after_library_write` | One library write while 300 card watches are open |
| `library_search*` | `filteredLibraryMangaProvider` with a search query |

`tool/perf/global_search_frames_main.dart` is a profile-mode frame harness
for the real `GlobalSearchScreen`: 30 manga sources, every third one failing
after 120 ms like a broken extension, the same library, fake server in its
own isolate. It reports dropped and janky frames, worst build and raster
time from the push until every source has answered and the screen has
settled. It builds (`./scripts/build_macos.sh --profile --no-open -- -t
tool/perf/global_search_frames_main.dart`) but **has not been run yet**.

## Baseline (before any change; JIT; machine shared with other agents)

Median of 6 runs (first run) unless noted, in milliseconds:

| Measurement | Total | Longest main-isolate stall |
|---|---|---|
| source_list_all | 11.4 | 11.6 |
| source_list_pinned | 5.8 | 6.0 |
| global_search_all_sources | 3823 (network 3811, processing 11.6) | 15.6 (p90 38.6) |
| cards_first_lookup (300 cards) | 57 | 26 |
| cards_resubscribe_all (one list rebuild, previous behavior) | 53 | 21 |
| cards_after_library_write | 27 | 2.4 (only 1 watch fires) |
| library_search | 0.9 | 2.1 |
| library_search_ignore_filters | 0.55 | 1.3 |

Later runs under heavier load measured 44-217 ms for `cards_first_lookup`.
The noise is larger than most differences, so the main thread should
re-measure one run at a time.

## Findings

- Network dominates searching all sources. Processing is about 12 ms across
  30 sources. The single-source search path was already optimized
  (`docs/performance.md`), so it was left alone.
- Each result card runs an Isar watch query, about 0.2 ms of fixed overhead
  each. Before this change, every rebuild of a card gave its `StreamBuilder` a
  new stream, so the card dropped its watch and queried again. Every time a
  source finished with nothing to show, the parent called `setState` and
  rebuilt every row and every card. With 300 cards on screen that is about
  20 ms or more of main-isolate stall per failing source, which is over a
  frame budget at common refresh rates.

## Optimizations

| Id | Change | File | State |
|---|---|---|---|
| G1 | Each result card creates its library-lookup stream once and reuses it. It is recreated only when the item type or name changes. | `global_search_screen.dart` | implemented |
| G3 | When a source reports nothing to show, only the bottom "no results" group rebuilds (a `ValueNotifier` with a `ValueListenableBuilder`), not the whole screen with every row and card. | `global_search_screen.dart` | implemented |
| G2 | Narrow the card query through the favorite+itemType index | `manga_repository.dart` | **tried and reverted** |

Why both G1 and G3 should keep behavior:

- G1: the Isar watch already emits after every relevant write. A G2
  side-test confirmed this for unfavorite, favorite set to null, rename,
  item-type change, delete, bulk replace and clear. So the card shows the same
  data without resubscribing. `StreamBuilder` keeps the last data across a
  resubscribe, so the old flicker-free display is unchanged.
- G3: the parent watches no providers. The rows get the same arguments, so
  rebuilding them only repeated the same build. Collapsed rows re-reported a
  reason that was already recorded, which was a no-op. The group reads the
  same map in the same insertion order. The theme dependency moves into the
  builder.

G2 was reverted for two reasons. A micro-benchmark measured about 210 us per
query with the index and about 225 us with the full scan (3800 rows): no
real gain. Its equivalence test also found that equal-key index entries come
back in id byte order, not numeric order, so it would have needed a sort to
keep the result order. Not worth the risk.

## Equivalence evidence

- `test/widgets/global_search_rebuild_test.dart` passes. It
  checks the result rows and cards, the "3 sources with no results" group and
  its entries in finish order with single-line errors. It also checks that
  each card keeps the identical stream object while other sources finish and
  when the card itself rebuilds. With the screen from before G1 and G3, the
  first test passes and the second fails, as it should.
- The test once hung after the last test: the cards' library queries had
  started under fake async and `isar.close` waited on them forever. Each test
  now lets them finish on real time and unmounts the screen before teardown.
  The old screen hung the same way, so the hang was in the test, not in G1.

## Not done

- Before/after numbers: run the frame harness on all changes, on −G1, on
  −G3 and on the baseline. The JIT `cards_resubscribe_all` value is the cost G1
  and G3 remove on each list rebuild; after the change, a list rebuild
  creates no new subscriptions.
- Measured but deliberately not changed: source list loading (11 ms). It
  deserializes 30 APKs of 400 KB each, and `searchProvider` needs them.
  Health-check round trips per source were left alone because changing them
  changes when requests are made. Library search costs under 1 ms.
- On merge, `flutter analyze` and the full `flutter test` suite passed.
