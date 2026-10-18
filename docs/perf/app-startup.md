# App startup performance (work in progress)

Status: two optimizations (S1, S2), both covered by equivalence tests. S1 is
measured in profile builds (see "After S1"); S2 so far only by a
micro-benchmark. The "Baseline" section was measured on the code before S1.
The first-launch stall turned out to be a harness artifact (see "The
first-launch stall").

## What is measured

Startup runs from Dart `main` to the first frame that shows library entries,
plus the frames and main-isolate stalls of the seconds after it.

- `lib/services/perf/startup_trace.dart`: `StartupTrace.mark(phase)` records a
  phase boundary (monotonic time since `main`, wall-clock time, VM timeline
  time). Each mark goes to the timeline and `postEvent`, and is printed only
  in a harness build. `lib/main.dart` marks `main`, `bindings`,
  `media_kit`, `rust`, `window` (window manager and saved geometry),
  `database` (Isar open and launch migrations), `run_app`, `first_frame`
  (first frame rasterized), `post_launch` and `post_launch_done`
  (`_postLaunchInit`).
- `tool/perf/startup_main.dart`: a harness entry point that runs the app's
  real `main`. It adds `library_frame` (the first frame whose tree contains a
  `CoverViewWidget`), frame stats from `run_app` (all frames and the frames
  after the library frame, against the display's reported refresh rate), and
  the longest main-isolate stalls (1 ms timer probe). It can also seed a
  realistic library.
- `tool/perf/startup_driver.dart`: seeds once, then launches the harness
  repeatedly and reports median and p90. Times are also given from just
  before the process is spawned, so engine startup before Dart `main` counts.
  Several binaries can be passed (comma separated); they are launched in
  turn so machine load affects each alike.

### Data isolation

The startup spawns worker isolates that open the database themselves
(`GetIsolateService`), and each isolate has its own path_provider. The
harness is therefore built with `--dart-define=MANGATAN_PERF_HARNESS=true`.
Only in such a build, `StorageProvider`'s constructor calls
`applyBenchmarkDataRoot()` (`lib/services/perf/benchmark_data_root.dart`),
which points every path_provider directory of the isolate at the folder in
`MANGATAN_PERF_ROOT`. A harness build without that variable refuses to start.
In normal builds the constant is false and the call compiles to nothing.

The seeded settings leave the extension-server address unset, so the harness
never talks to a running server of the user's.

### Seeded library

500 favorite manga entries with 150 chapters each (75,000 chapters), 3
categories, one history row and 4 updates per entry, every 9th chapter
downloaded, 30 installed Mihon sources with 400 KB extension bodies, and
per-entry settings lists: chapter filters and sorts for every entry, scanlator
filters for 100, reader and page modes for 300, 20,000 chapter page indexes
(one is added per chapter read and never removed) and 30 cookies. Onboarding
is completed; the window opens at 1200×800. Covers have no image URL, so
cover decoding is not part of the measurement. No tracker is logged in.
Every seeded row gets its sync `clientId` during seeding (see "The
first-launch stall" below), as in a library the app has opened before.

### Commands

```sh
./scripts/build_macos.sh --profile --no-open -- \
  -t tool/perf/startup_main.dart --dart-define=MANGATAN_PERF_HARNESS=true
cp -c -R build/macos/Build/Products/Profile/Mangatan.app <scratch>/a.app
dart tool/perf/startup_driver.dart \
  --app <scratch>/a.app/Contents/MacOS/Mangatan[,<scratch>/b.app/...] \
  --data <scratch>/data --runs 15 [--mode warm|fresh] [--watch 8] \
  [--out results.json]
```

`MANGATAN_PERF_HOLD=<s>` keeps the harness open after its result. For a CPU
profile, launch it with `FLUTTER_ENGINE_SWITCHES=1` and
`FLUTTER_ENGINE_SWITCH_1=enable-dart-profiling=true`, then read the main
isolate's CPU samples over the VM service between the marks' `timelineUs`
values (the profiler is off in profile builds without that switch).

## Baseline (before S1)

Warm launches (same data folder, one discarded launch), 15 runs, profile build
on macOS. The machine was heavily loaded by other jobs (load average about
10 on 10 cores), so p90 values and the spawn-to-`main` time are dominated by
scheduling noise. The quietest runs give the clearest picture.

| Phase (ms since `main`) | median | p90 | quiet run |
|---|---|---|---|
| `window` | 85.7 | 363.0 | 41–57 |
| `database` | 154.3 | 635.2 | 97–123 |
| `run_app` | 154.3 | 639.4 | 97–124 |
| `post_launch` (first frame built) | 205.6 | 935.5 | 126–155 |
| `first_frame` (rasterized) | 237.1 | 1109.7 | 141–172 |
| `library_frame` | 404.1 | 1251.3 | 193–243 |

| Measure | median | p90 |
|---|---|---|
| spawn to `main` | 2580.6 | 5243.4 (quiet: about 460) |
| spawn to library frame | 3013.1 | 6322.2 (quiet: about 670) |
| longest main-isolate stall | 125.2 | 496.1 (quiet: 44–56) |
| dropped frames from `run_app` (to +8 s) | 5 | 10 |
| worst build from `run_app` | 46.0 | 68.0 |
| dropped frames after the library frame | 1 | 4 |

The longest stall in every run starts at `run_app`: it is the first build.

### Where the time goes (CPU profile, quiet run)

Main-isolate samples between `run_app` and `library_frame` (185 ms, 113
samples at 1 ms):

- About 39 samples: full deserialization of the settings row
  (`_settingsDeserialize`). About 25 providers each call
  `settingsRepository.current` in `build()` to read a single field, and each
  call decodes the whole row, including the 20,000 chapter page indexes.
- About 27 samples: deserializing installed sources with their 400 KB
  extension bodies, mostly `refreshInstalledMihonFactorySources`. In the
  harness the desktop extension server cannot start (no JRE configured), so
  this refresh runs immediately after the first frame. In the real app it
  runs only after the JVM is ready, seconds later, so this is mostly a
  harness artifact (see below).
- The rest: widget build and layout of the first screens, GC.

## Optimizations

| Id | Change | Files | Status |
|---|---|---|---|
| S1 | Startup providers read their one settings field with an Isar property query (`SettingsRepository.field`) instead of deserializing the whole settings row | `settings_repository.dart`; providers in `library_source_badge_provider.dart`, `library_state_provider.dart` (grid size), `tv_mode_provider.dart`, `storage_usage.dart`, `downloaded_only_state_provider.dart`, `incognito_mode_state_provider.dart`, `animation_duration_scale_provider.dart`, `app_font_family.dart`, `app_ui_scale_state_provider.dart`, `blend_level_state_provider.dart`, `flex_scheme_color_state_provider.dart`, `pure_black_dark_mode_state_provider.dart`, `theme_mode_state_provider.dart`, `browse_state_provider.dart` (extension update check), `general_state_provider.dart` (DNS, user agent), `reader_state_provider.dart` (navigation order, hidden items, merged nav), `security_state_provider.dart`, `l10n_providers.dart` | Implemented, equivalence tested, measured |
| S2 | The remaining whole-row settings reads on startup and per-request paths read single fields: `MClient.init` (DNS-over-HTTPS settings) and `MClient.getCookiesPref` (cookies) on every HTTP request, the extension-server address (`AndroidProxyServerState`, `MExtensionServerPlatform._baseUrl`), `OnboardingCompletedState` and `ExtensionsRepoState`. Reads that used `currentOrNull?.x` use the new `SettingsRepository.fieldOrNull` | `settings_repository.dart`, `m_client.dart`, `browse_state_provider.dart`, `onboarding_state_provider.dart`, `m_extension_server.dart` | Implemented, equivalence tested, micro-benchmarked |

S1 keeps every read fresh (one query per `build()`, exactly when the old code
read), so no read can see older data than before. Only `build()` methods were
changed; setters still read and write the full row as before. When the row is
missing, `field` evaluates `current`, so it fails with the same error.

Equivalence evidence: `test/repositories/settings_field_test.dart` compares
`field` with the corresponding `current.<field>` for every changed field, on
a fresh row and on a row with non-default values, nulls, an embedded locale,
lists and non-ASCII text; after a write; and for a missing row (same error
type and message). Mutation check: making `field` return null for a missing
row instead of failing makes the test fail. `flutter analyze` and the full test suite pass with S1.

Micro-benchmark (same test, `MANGATAN_PERF=1`, JIT, settings row with 20,000
page indexes and 500 entries in each chapter filter list, median of 40):
`current.themeIsDark` 1.125 ms, `field(themeIsDarkProperty)` 0.015 ms. With
about 25 startup providers this suggests roughly 25 ms less main-isolate work
before the library frame at this library size; the profile-build figure is
still to be measured.

S2: `fieldOrNull` returns null where `currentOrNull?.<field>` did: a missing
row, a null value, or a failing read (for example a closed database). The
onboarding and repository reads use `field`, which fails like `current`.
`_baseUrl` used `getSync` without a guard, so it uses an unguarded property
query. Onboarding still reads the repository lists only when the flag is
unset, in the same order. The DNS settings are now two queries instead of one
row read; nothing between them yields to the event loop.

Equivalence evidence for S2: `test/repositories/settings_field_test.dart`
compares every converted field with the old expression on a fresh row, on
rows with stored values, nulls, empty lists, embedded repositories and cookies
(compared as JSON) and non-ASCII text, after a write, for a missing row, and
with the database closed. Mutation checks: letting `fieldOrNull` throw
instead of returning null, and making it always return null, each fail the
test.

Micro-benchmark (same settings row as above, JIT, median of 40): the settings
reads of one HTTP request (`MClient.init` plus the cookie lookup) take 1.29 ms
before and 0.04 ms after. That is about 1.25 ms of main-isolate time saved per
request at this library size, for example per source in a global search.

## After S1

Profile builds of the harness with and without S1 (only the provider files
reverted), launched alternately by the driver, 15 runs each. The machine was
much quieter than for the baseline above (load average about 3.5), so compare
the two columns with each other, not with the baseline table.

Warm launches, median (p90), ms:

| Measure | without S1 | with S1 |
|---|---|---|
| `run_app` (since `main`) | 56.2 (73.4) | 54.4 (74.6) |
| `post_launch` (first frame built) | 89.5 (132.9) | 66.7 (94.4) |
| `first_frame` (rasterized) | 107.1 (195.8) | 83.5 (112.8) |
| `library_frame` | 160.5 (281.3) | 135.3 (171.9) |
| `run_app` to `library_frame` | 104.3 | 80.9 |
| longest main-isolate stall | 46.1 (121.6) | 36.0 (51.6) |
| worst build from `run_app` | 17.3 (21.2) | 14.8 (18.0) |
| dropped frames from `run_app` | 1 (2) | 0 (1) |
| spawn to `main` | 283.3 (358.6) | 298.4 (360.8) |

The first build gets about 23 ms shorter, matching the micro-benchmark's
estimate of about 25 ms. Spawn to `main` happens before any Dart code runs,
so its difference is noise.

Fresh launches (new copy of the data folder each time), median (p90), ms:

| Measure | without S1 | with S1 |
|---|---|---|
| `post_launch` | 100.4 (137.2) | 81.0 (120.7) |
| `first_frame` | 148.4 (196.3) | 127.7 (183.0) |
| `library_frame` | 636.3 (713.7) | 624.6 (678.0) |
| longest main-isolate stall | 445.4 (473.8) | 447.5 (489.3) |

On a first launch on a data folder, a stall of about 445 ms between the first
frame and `post_launch_done` dominates both variants. S1 does not touch it.
The next section explains it; it came from the harness seed.

## The first-launch stall

A CPU profile of a fresh launch (main isolate, `first_frame` to
`post_launch_done`, 437 ms) put 304 of 331 samples in
`backfillMissingClientIds`, called unawaited from `_postLaunchInit`. Inside it,
`ChapterRepository.putSync` took 274 samples and `isar_put` 261. The seed
created its rows without a `clientId`, and no app code assigns one when a row
is created; the startup backfill does that on the next launch. Each copy of
the seed folder therefore rewrote all 75,000 chapters in one synchronous
write transaction on the main isolate.

In the real app this happens once, on the first launch after an upgrade from
a version without `clientId`. After that, each launch backfills only the rows
created since the previous launch: a few, or as many as a large restore or
update check added. It is real behavior, but not an ordinary launch.

A bulk write is not meaningfully faster. In a JIT test with 75,000 chapters,
one `putAllSync` per collection took 339–342 ms, against 343–353 ms for the
current per-row `putSync` loop, so about 2%. The cost is Isar's native index
maintenance, which both forms pay the same. Moving the backfill to another
isolate would take it out of `dbWriteQueue`'s ordering. Neither was changed.

The seed now calls `backfillMissingClientIds()` itself, so `--mode fresh`
measures an ordinary launch on a data folder the OS has not cached. Fresh
launches with S1 and the backfilled seed (15 runs, load average about 4),
median (p90), ms:

| Measure | old seed | backfilled seed |
|---|---|---|
| `first_frame` | 127.7 (183.0) | 116.5 (123.4) |
| `post_launch_done` | 599.6 (681.0) | 130.9 (138.8) |
| `library_frame` | 624.6 (678.0) | 151.6 (161.2) |
| spawn to library frame | 977.0 (1031.1) | 428.3 (443.2) |
| longest main-isolate stall | 447.5 (489.3) | 42.1 (49.3) |
| dropped frames from `run_app` | 1 (2) | 0 (0) |

The longest remaining stall is the first build, as in warm launches.

## Still to do

- Measure S2 in a profile build: a request-heavy flow such as global search
  across many sources, not only startup.

## Measured but deliberately not changed

- `window` (40–85 ms quiet): `windowManager.ensureInitialized` and
  `WindowGeometry.restore` are platform calls that size and place the window
  before the first frame; moving them would change what the user sees first.
- `database` (about 55 ms quiet): Isar open plus launch migrations (settings
  seed check, windowed-reader marker, tracker `refreshing` reset, default
  custom button). Each is a side effect that must stay before `runApp`.
- `refreshInstalledMihonFactorySources` deserializing every installed source
  with its extension body: in the real app it starts after the desktop
  extension server is ready, not at the first frame, and it needs the bodies.
- Worker isolates (`GetIsolateService`, download pool) each open the database
  and repeat `initDB`'s launch migrations after the first frame. Not changed:
  that is existing behavior with side effects.
- Spawn-to-`main` (engine and plugin startup, about 460 ms quiet) is outside
  Dart.
- `backfillMissingClientIds` on the first launch after an upgrade (about
  340 ms for 75,000 chapters): see "The first-launch stall".
- True cold launches (empty OS file cache) were not measured: that needs
  `sudo purge`.
