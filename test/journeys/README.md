# Journey tests

Behavioural tests of the whole app: each journey starts the real router,
screens, providers, theme and translations on a real Isar database in a
temporary directory, then uses the app the way a person does (taps, keys,
mouse wheel, window sizes, closing the window) and checks what a person
would check: what is on screen and what was saved.

Run them with one command; the report is a few lines:

```sh
dart run tool/test_journeys.dart                      # everything (~6 min)
dart run tool/test_journeys.dart test/journeys/reader_journey_test.dart
dart run tool/test_journeys.dart --name "every reading mode"
```

Plain `flutter test test/journeys` works too, with the full log.

## Why they catch what unit tests miss

Most bugs found by hand in this fork were in the wiring, not in a function:
a setting saved by one screen and not read by another, a page index written
on dispose that never runs on desktop, a popup that keeps the keyboard, a
layout that only breaks in German on a phone. A journey goes through all of
that at once. Each past bug it guards was checked by putting the bug back
and watching the journey fail (library category on window close, Chimahon
page resume, grey screen after selecting chapters).

## What is real and what is not

Real: the database, Hive preferences, router, every screen and provider,
keyboard and pointer handling, page decoding (the native decoder DLL the
test run builds), backups and restores.

Stand-ins (harness/plugins.dart): OS window controls, wakelock, secure
storage, path_provider (pointed at the test's temp folder). The headless app
mirrors MyApp's builder (toasts, desktop back navigation, app lock, memory
overlay) but not its startup side effects (Mihon bridge, deep links,
background work).

Out of reach headlessly: the EPUB novel reader and anything else inside a
WebView, the mpv player, network sources and Mihon extensions. Those need a
real build (an `integration_test` run on Windows) or a person.

## Sync against a fake SyncYomi server

`sync/` runs the app's real Chimahon sync code over HTTP against a SyncYomi
server on 127.0.0.1 (`fake_syncyomi.dart`: the `/api/sync/content` protocol
with its token check and ETag preconditions). It serves `sync_fixture.dart`,
a generic payload built to have every record type and field the real
account payloads had (checked against two of them in 2026-11), with made-up
contents, plus fields this app does not know, which a sync must keep. The
same fixture, written as a `.tachibk`, drives the Mihon backup import
journeys. Remember Chimahon's `lastModifiedAt`/`favoriteModifiedAt` are
epoch seconds; everything else is milliseconds.

## When a test process hangs

A journey takes about a second (the longest settings search about 90 s), so
`flutter_test_config.dart` fails any test after 3 minutes instead of 10.
Real IO in the harness runs through `realWork`, which fails with what it was
doing ("opening the test database did not finish ...") instead of blocking
every later test of the process. All journeys of a process share one
database, emptied before each: Isar's native library on Windows stops
opening databases after about 118 opens in one process.

## Real fonts

`flutter_test_config.dart` loads the app's own interface font (Figtree, from
packages/shiori) and Roboto before the journeys run. flutter_test otherwise
draws every letter as a full square, much wider than real text, and the
sweep then reports overflows nobody sees in the app (S7, S14, S17 and S18
were exactly that).

`--dart-define=RUN_KNOWN=true` also runs the sweep's known-issue journeys,
to see which suspected bugs still reproduce.

## Every step checks the screen

Besides exceptions and layout overflows, which fail a test by themselves,
each step fails when the screen shows the app's error view, Flutter's error
box, a nonsense relative date ("20000 days ago") or a raw value ("null",
"NaN", "Instance of ...").

## Suspected bugs

A journey that finds a suspected bug is skipped, with a comment
"Suspected bug Sn: ..." saying what goes wrong, until a person has confirmed
it and it is fixed. Then the skip goes and a "Was Sn" comment says what the
journey now guards.

## Writing a journey

```dart
testWidgets('what a person does and expects', (tester) async {
  final j = await Journey.start(tester, arrange: (seed) async {
    final manga = await seed.manga('Kuso Onna');
    await seed.chapters(manga, 3, pages: 6);   // real PNG pages on disk
  });
  await j.tapText('Kuso Onna');
  await j.openChapter('Chapter 1');
  await j.nextPage();
  await j.kill();                               // close the window
  ...
});
```

- `Journey.start(window:, locale:, dark:, arrange:)`, `restart()`, `kill()`
- `tap`, `tapText`, `tapTooltip`, `longPress` scroll a target clear of
  anything covering it and fail if a person could not reach it
- `key`, `wait`, `settle`, `waitFor`, `scrollTo`, `resize`, `go`, `push`
- reader: `openChapter`, `nextPage`, `previousPage`, `pageIndicator`,
  `leaveReader`, `showReaderBars`, `savedPage`, `isRead`
- `seed.livedIn()` fills a library with categories, CJK titles, read,
  unread and in-progress chapters, history and updates
