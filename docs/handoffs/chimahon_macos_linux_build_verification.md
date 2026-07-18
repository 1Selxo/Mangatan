# Handoff: verify Chimahon sync builds on macOS and Linux

Independently finish host-level verification of Mangatan's desktop Chimahon
Google Drive sync. Work from the current tree; do not redesign sync, change
OAuth identity, upload blindly, or touch mobile paths.

Verify both hosts:

- Run the complete `test/services/sync` suite, the two reference-backup tests
  with `CHIMAHON_REFERENCE_BACKUP` set, targeted analysis, and
  `git diff --check`.
- Build, launch, and verify the installed/debug executable—not just unit tests.
- Sign in through the system browser, confirm the callback returns to Mangatan,
  and confirm the saved credential is reused after restart. On macOS, confirm
  the Keychain item reads `Mangatan Google Drive sync` with its brief sync
  description. On Linux, record the desktop keyring's own Secret Service
  prompt; the plugin does not support a Mangatan-specific per-token label.
- Run a preview against a freshly downloaded remote and the local comparison
  fixture. On macOS use `dart run tool/chimahon_drive_diagnostic.dart
  --operation=sync-preview --app=/absolute/path/to/Mangatan.app
  --reference=/Users/rahulb/Downloads/app.chimahon_2026-07-17_22-11.tachibk`;
  on Linux copy that fixture locally and use
  `--app=/absolute/path/to/mangayomi
  --reference=/path/to/copied/app.chimahon_2026-07-17_22-11.tachibk`. Prove the
  preview performs no Drive, database, sidecar, or credential write. Confirm
  the proposed media selection matches the backed `library_entries`,
  `anime_entries`, and `sync_novels` values and that the safety audit passes
  before authorizing any real sync.
- If a real sync is authorized, capture pre/post remote fingerprints and prove
  CAS conflict handling, local import, restart persistence, novel progress,
  custom titles, unknown fields, and device-local chapter overlays.

macOS requirements:

- Apple Silicon/ARM64 only. Build with `FLUTTER_XCODE_ARCHS=arm64 flutter build
  macos --debug`; never build x64/universal and never use `lipo`.
- Check the main executable and `App.framework` with `file`, validate signing,
  stop only the exact prior Mangatan process, launch the new `.app`, and record
  its PID/start time.

Linux requirements:

- Use an x86-64 host: the tracked `libmtorrentserver.so` is x86-64. Do not claim
  Linux ARM64 support.
- Follow [Linux Google Drive sync requirements](../linux_google_drive_sync.md).
  Verify the distro-equivalent libsecret build/runtime packages, `xdg-utils`,
  D-Bus, and a working Secret Service; test both a default browser callback and
  credential reuse after a full restart.
- For an integrated AppImage, query both defaults with `xdg-mime query default
  x-scheme-handler/mangayomi` and `xdg-mime query default
  x-scheme-handler/app.chimahon.google.oauth`. The repository helper keeps the
  supported `mangayomi.desktop` identity; if a third-party integrator renames
  it, verify Mangatan's ownership-marked per-user association is the active
  callback instead of assuming the renamed entry is recognized.
- Build with the existing toolchain using `flutter build linux --debug`. Run
  `file build/linux/x64/debug/bundle/mangayomi
  build/linux/x64/debug/bundle/lib/libmtorrentserver.so` and
  `ldd build/linux/x64/debug/bundle/mangayomi`, then launch that executable.
  Do not download runtimes or add a release workflow. If testing the AppImage
  script, supply a trusted local `appimagetool`; confirm runtime dependencies
  are actually available.

Return exact commands, host/architecture, hashes, test counts, screenshots or
logs for login/callback failures, and a short pass/fail matrix. Clearly separate
verified runtime behavior from static wiring and list every remaining blocker.

## Copy-ready prompt

Independently verify the current Chimahon Google Drive sync on macOS ARM64 and
Linux x86-64 by following this handoff; do not redesign sync or change its OAuth,
storage, merge, or safety semantics, and return an evidence-backed pass/fail
matrix with every remaining blocker.
