# Vendored M-Extension-Server

This directory contains the source of
[`1Selxo/M-Extension-Server`](https://github.com/1Selxo/M-Extension-Server)
at commit `68645ae7a8b2ffd0954e9c6cba62427f54f95503`.

Mangatan builds the desktop and iOS server JAR from these sources so release
artifacts do not download or require a separately installed extension server.
The covered source remains licensed under MPL-2.0; see `LICENSE`. Bundled
third-party components retain their own notices and licenses. The GPL-3.0-or-
later corresponding source for the shaded NewPipe Extractor classes is kept at
`../newpipe_extractor`.

## Mangatan security patch

`server/src/main/kotlin/mextensionserver/Main.kt` binds the headless bridge to
`127.0.0.1`. Upstream's default controller binding listens on every interface,
which is unsafe for Mangatan's unauthenticated app-internal HTTP API.

To update the vendored source, replace this tree from a reviewed upstream
commit, preserve license notices, reapply the loopback-only binding, run the
Gradle test suite, then update the commit above and the corresponding
provenance test.
