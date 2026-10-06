# Mangayomi v0.9.8 integration

Upstream release: `bc016a5a39d739999e41ebba90ede0118840fdc9`
([v0.9.8](https://github.com/kodjodevf/mangayomi/releases/tag/v0.9.8)).
The integration uses a merge on `main`, preserving published Mangatan history
and the newer fork changes from `origin/main`. The app version is `1.2.24+212`.

## Fork behavior retained

- Lazy iOS OpenJDK loading, foreground listener lifecycle, bridge errors,
  extension-server runtime pins, and explicit Android Proxy Server support.
- OCR, dictionary lookup, subtitle mining, Anki export, EPUB navigation, local
  chapter overlays, anime seasons, and Chimahon sync safeguards.
- Mangatan's player and reader screens, download queue and offline subtitle
  behavior, absolute local-file paths, and fork release packaging. Upstream's
  alternative player/reader refactoring and native sync transport do not replace
  these implementations. Compatible source fixes and shared helpers are merged
  into the fork implementation.

## Local manga and page caching

Local folder pages have paths and nullable image bytes. Pass both through to
`UChapDataPreload`; forcing non-null bytes crashes when opening a folder. Local
archives and folders also bypass download-directory construction, so they do
not need remote source/language metadata. Archives retain byte-backed pages.

Chapter URL lists now use upstream's disk cache rather than settings. Completed
downloads are resolved from disk before extension lookup. Cached ephemeral
Mihon proxy URLs are rejected and fetched again. Reader Retry clears the chapter
cache and invalidates page loading. Page progress uses the loaded page count.

## Linux renderer

All media-kit packages resolve to the immutable fork commit
`fdb1a7dd1bb988b2dccec566b8aa31d1af0624fe`, which contains the complete renderer
backport of Predidit's
[`df5a969`](https://github.com/Predidit/media-kit/commit/df5a969e617a1ce038d5cca46bedcfa1970a7dc6).
The video package internally names a branch for media-kit, so an override keeps
that dependency on the same immutable commit.

The backport uses native EGL display discovery, a dedicated rendering thread
with an isolated context, and deferred texture disposal. Its Linux renderer
sources match the cited commit. The fork CMake integration continues to find
system libmpv with pkg-config; Predidit's bundled libmpv configuration is not
imported. Renderer and libmpv behavior still need physical X11 playback testing.

## Generation and validation

Regenerate Riverpod/Isar outputs from the merged Dart sources and localizations
from the merged ARB inputs. The unchanged Rust union sources retain their
matching Freezed outputs; the installed older generator emits invalid `final`
parameter modifiers with this SDK if those unions are unnecessarily regenerated.
Use build filters when regenerating only providers and database schemas.

The obsolete iOS CocoaPods lock is removed: `pod install` in the macOS iOS
workflow resolves the new file-picker plugins from `pubspec.lock` and the fork's
Podfile. A Windows checkout cannot validate CocoaPods or produce an iPhone IPA.

Required release validation includes the bridge regression tests, local chapter
and archive tests, reader progress, download queue, Mihon service compatibility,
and Chimahon safety tests. X11 performance and physical iPhone startup remain
device checks, separate from Dart tests.

Local verification on Windows:

- The bridge format check and eight bridge/local chapter tests pass.
- Static analysis of `lib`, `test`, and `hook` reports zero errors; warnings
  and informational diagnostics remain.
- The broad cache/download/reader/library/Mihon/Chimahon run passed 861 tests
  and skipped four opt-in tests. Its 14 failures were corrected: Mihon header
  overrides bypass database access, video retry fixtures meet the retained
  final-file validation threshold, and the Windows dependency check reflects
  the upgraded secure-storage version.
- The rerun of the affected suites plus archive, backup, queue, and novel tests
  passed 74 tests. Ten added LNReader tests could not load the native
  `flutter_qjs_plugin.dll` in the test environment; they remain unverified.
- No native application build or device performance test was performed.
