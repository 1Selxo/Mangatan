# Anime seasons and Chimahon interoperability

This port follows [Anikku v0.2.0](https://github.com/komikku-app/anikku/releases/tag/v0.2.0)
and its extension-lib 16 source contract. Series and collections contain
separate anime entries; each season owns its episodes, progress, downloads and
tracking. This also supports nested collections. Sources that return ordinary
episode lists continue to use the existing detail screen.

The detail screen lists seasons with watched counts and parent navigation.
Source order, season number and alphabetical sorting use Anikku's flag bits;
editing those bits preserves the other settings. Library refreshes fetch season
episodes and use the earliest child update interval for their series. Refreshes
reuse source URLs, retain progress and custom titles, and detach removed seasons
without deleting their data. Filler markers, summaries and episode previews
now cross the Mihon bridge. Background artwork is retained for backup and sync.

## Backup and sync

Local relationships use a source-scoped parent URL, never another device's
database ID. Mangatan backups and Chimahon exports include unfavorited seasons
under backed-up series. Both manual restore and incremental sync restore these
entries without automatically favoriting them.

The existing protobuf schema matches Anikku's anime fields:

| Field | Meaning |
| --- | --- |
| 500 | Background URL |
| 502 | Parent ID within this backup |
| 503 | Anime ID within this backup |
| 504 | Season display flags |
| 505 | Season number (double) |
| 506 | Source order |
| 507 | Fetch type: seasons = 0, episodes = 1 |

IDs are reassigned into a common namespace before merging independently created
backups. Missing IDs, duplicate IDs, cross-source parents and cycles cannot
create local links. Episode progress keeps the existing URL identity and clock
rules. Season-only changes participate in conflict comparison and the safety
audit. Older Chimahon clients that omit season fields cannot implicitly detach
the local hierarchy. Unimplemented Android flags remain preserved on the wire.

These rules use protobuf [field presence](https://protobuf.dev/programming-guides/field_presence/),
particularly because an absent fetch type must not become the zero-valued
"seasons" enum. Compatibility is tested against the Anikku schema and legacy
Chimahon projections; a future Chimahon release still needs an on-device
round-trip check once its upstream changes are available.

## Building both branches

Both repositories use `feature/anikku-seasons`. The exact bridge revision is
stored in `tool/mihon_server_commit.txt`. The iOS sideload workflow builds and
tests that revision on Ubuntu, transfers its JAR with a SHA-256 check, then
packages it using the existing lazy OpenJDK runtime. Build number: 206.
This requires neither a production release nor a main-branch merge.

For local iOS preparation, build that bridge with JDK 21 and
`./gradlew :server:test :server:shadowJar -PiosRuntime=true`, then set
`MIHON_SERVER_JAR_FILE`, `MIHON_SERVER_JAR_SHA256`, and `MIHON_SERVER_COMMIT`
before running `tool/prepare_embedded_mihon_ios.sh`. Without those overrides,
the preparation script retains its previous released-JAR default. The source
pin and supplied commit must match. OpenJDK assets and native loading behavior
are unchanged. A physical iPhone test is still required.

Desktop testing uses the bridge's ordinary `:server:shadowJar` build and JDK 21,
selected in Settings > Browse > Extension server. An older installed bridge
does not gain the new source APIs just by rebuilding Flutter.

## Validation and scope

Regression coverage includes legacy backups, independent-device ID collisions,
cycles, unfavorited children, progress preservation, repeated restore, removed
seasons, season-only sync changes and old episode-only sources. The bridge has
a released Jellyfin 16.30 APK fixture in `tool/test_jellyfin_seasons.py`.

That APK passes season discovery and direct playback. Transcoded qualities have
an observed upstream `TranscodingInfo` JSON naming mismatch, documented in the
bridge's `tool/ANIME_SEASONS.md`. Successful deferred resolution is separately
covered by the bridge regression tests. No extension-specific JSON workaround
is applied. Android-specific player commands, gestures and UI implementation
details are outside this port.
