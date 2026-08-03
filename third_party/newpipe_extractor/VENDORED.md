# NewPipe Extractor corresponding source

This directory contains the buildable production source for
[`TeamNewPipe/NewPipeExtractor`](https://github.com/TeamNewPipe/NewPipeExtractor)
release `v0.26.3`, commit
`caae86c943857cc6e1a762e3488d6a14e9cf7800`.

M-Extension-Server links NewPipe Extractor into its shaded JAR for YouTube URL
resolution. This source is shipped in Mangatan's release-tag source archive as
the GPL-3.0-or-later corresponding source for those classes. The full license
is in `LICENSE`. Upstream tests and test fixtures are omitted because they are
not required to build the distributed production classes.

Mangatan currently resolves the compiled artifact through the vendored
M-Extension-Server Gradle build. When updating its NewPipe version, replace
this directory with the matching reviewed production source and build files,
then update the version, commit, and provenance test together.
