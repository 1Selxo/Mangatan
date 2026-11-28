# Performance profiles

Measurements of the app on a copy of a real database. Nothing here runs in
a normal `flutter test`: every file is skipped unless its environment
variables are set. Never point them at a live database; copy
`mangayomiDb.isar` somewhere first.

## Headless (flutter_tester, debug JIT)

```sh
# CPU samples and frame costs of journeys through the screens
MANGATAN_PROFILE_DB=<copy folder> \
  flutter test --enable-vmservice test/profile/ui_profile_test.dart

# Startup's Mihon refresh (first launch, again, relaunch) and a global
# search, against a real extension server with Java Flight Recorder
MANGATAN_PROFILE_DB=<copy folder> MANGATAN_PROFILE_JDK=<JDK 21> \
MANGATAN_PROFILE_JAR=<MExtensionServer jar> \
  flutter test --enable-vmservice test/profile/bridge_profile_test.dart

# The database's shape and what its common queries cost
MANGATAN_PROFILE_DB=<copy folder> flutter test test/profile/db_probe_test.dart
```

Results go to `build/perf_profile` (`MANGATAN_PROFILE_OUT`): one `.folded`
file per scenario (Dart stacks), `.jfr` recordings for the server, and
`metrics.jsonl`. `python tool/perf/flamegraph.py <folder> [--jdk <JDK>]`
writes `top.txt` (functions by self and inclusive samples) and a flame graph
page. Compare these numbers with each other, not with a release build.

## The real app (profile build)

```sh
flutter build windows --profile -t tool/perf/real_app_main.dart \
  --dart-define=MANGATAN_PERF_HARNESS=true
# a data folder with a copy of the database and chosen bridge paths
MANGATAN_PROFILE_DB=<copy folder> MANGATAN_PROFILE_ROOT=<new folder> \
MANGATAN_PROFILE_JRE=<java.exe> MANGATAN_PROFILE_JAR=<server jar> \
  flutter test test/profile/prepare_real_root_test.dart
dart run tool/perf/real_app_driver.dart --exe <absolute path to mangayomi.exe> \
  --root <that folder> --out build/perf_profile/real --name run1 \
  --seconds 60 [--search love --search-after 40]
```

`python tool/perf/window_top.py <out> <run> <from ms> <to ms>` lists the top
functions of one stretch of a run (times as in `<run>.json`).

The driver records every frame's build and raster time, the main isolate's
CPU samples, the startup phase marks and the Mihon refresh timing the app
logs. The harness build keeps all data in the folder, and the bridge's own
settings under `<folder>/bridge`.

Pitfalls found the hard way:

- Fetching CPU samples (`getCpuSamples`) makes the VM build their JSON on
  the app's UI thread: about four seconds of frozen app per fetch on a
  long run. The driver fetches them once, after the measured window; do not
  poll them while measuring stalls.
- Start the app from its own folder: flutter_rust_bridge looks for its
  library under `rust/target` relative to the working directory first, and
  a stale one there fails startup with a content hash mismatch.
- Desktop profile builds start with the sampling profiler off; the driver
  turns it on (`setFlag('profiler', 'true')`).
