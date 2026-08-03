# Vendored M-Extension-Server

This directory contains the source of
[`1Selxo/M-Extension-Server`](https://github.com/1Selxo/M-Extension-Server)
at commit `68645ae7a8b2ffd0954e9c6cba62427f54f95503`.

Mangatan builds the desktop and iOS server JAR from these sources so release
artifacts do not download or require a separately installed extension server.
The covered source remains licensed under MPL-2.0; see `LICENSE`. The JAR is
shaded, so it carries more than the covered source: `BUNDLED_NOTICES.md`
accounts for every component in it and is copied next to the JAR in every
release bundle. The GPL-3.0-or-later corresponding source for the shaded NewPipe
Extractor classes is kept at `../newpipe_extractor`, and its version is coupled
to `gradle/libs.versions.toml` by `vendored_mihon_source_test.dart` — bumping
the jitpack coordinate without re-vendoring that tree fails CI.

## Mangatan security patch

`server/src/main/kotlin/mextensionserver/Main.kt` binds the headless bridge to
`127.0.0.1`. Upstream's default controller binding listens on every interface,
which is unsafe for Mangatan's unauthenticated app-internal HTTP API.

Only the headless path is patched. Upstream's `--ui` mode
(`server/src/main/kotlin/mextensionserver/ui/ServerWindow.kt`) still binds every
interface by design, and is left as upstream wrote it: Mangatan never passes
`--ui`, so no Mangatan code path reaches it.

## Archive naming

The Gradle build names the JAR `MExtensionServer-<version>-<revision>.jar`, and
`scripts/build_vendored_mihon_server.{sh,ps1}` keep that name verbatim. The app
parses the installed version out of the basename, so a bundle that flattens it
to `MExtensionServer.jar` reports the `1.0.0` fallback and offers a permanent
bogus update. See `packaging/arch/README.md` for the full detection contract.

To update the vendored source, replace this tree from a reviewed upstream
commit, preserve license notices, reapply the loopback-only binding, run the
Gradle test suite, then update the commit above and the corresponding
provenance test.
