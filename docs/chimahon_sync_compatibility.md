# Chimahon sync compatibility

## Transport and account setup

Mangatan uses Chimahon's Google OAuth client ID, redirect URI, hidden Drive
`appDataFolder`, filename (`Chimahon_sync.proto.gz`), and gzip-protobuf wire
format. The user signs in through Google, but does not create a Google Cloud
project or shared folder. Drive app-data access is scoped to the OAuth client,
which is why matching Chimahon's identity is necessary.

Hoshi Reader's TTSU interoperability is a different design based on files in a
user-visible Drive folder. It cannot read Chimahon's private app-data folder,
and configuring a shared Hoshi/TTSU-style folder would not expose the existing
Chimahon payload.

The merge, safety, and transport core is shared by macOS, Windows, and Linux.
OAuth callback registration, credential storage, and packaging are the only
platform-specific layers. Linux is currently x86-64 only because the tracked
`libmtorrentserver.so` is x86-64.

## Data mapped in both directions

- Manga and anime parents, chapters/episodes, history, categories, tracking,
  favorite/library state, and conflict clocks.
- Chimahon/J2K custom manga title field 800. Mangatan maps it into its
  source-title/display-title model instead of replacing it with the source's
  default title.
- Novel identity, categories, dated progress/statistics, and modification
  clocks. The reference manual backup contains three novel records and 26
  statistics rows; the live Drive payload contained 27 statistics rows and
  retained all of them after Mangatan added two local novel records.
- Chimahon application preferences and source preferences that Mangatan can
  represent, including the backed media selectors `library_entries`,
  `anime_entries`, and `sync_novels`.
- Source maps, extension stores (including signing-key metadata), legacy
  extension repositories, manga/chapter memo bytes, search history, saved
  searches, and feeds already in the remote payload are retained through
  Mangatan merges. Extension stores are portable data only: Mangatan does not
  install them automatically because it cannot enforce Chimahon's trust model.
- Manga, anime, and novel category wire records are represented. Download-only
  treats their enabled media scope and memberships as authoritative, including
  an explicitly empty membership.

Unknown protobuf fields and unsupported preference values are retained as
opaque data. A no-edit remote -> Mangatan -> Chimahon round trip therefore does
not erase future fields merely because this Mangatan build cannot display
them. Explicit local edits replace only the fields Mangatan owns.

## Download-only behavior

Download-only previews the exact remote counts and projected removals before
writing. Enabled media scopes are remote-authoritative; disabled scopes are
untouched. A second identical download is idempotent and reuses existing title
and chapter IDs.

Remote-absent source entries are removed unless they carry device-only data.
Archives, EPUB files, downloaded/manual chapters, and their dependent local
history remain on the device. A retained source-backed overlay becomes
uncategorized so a stale or synthetic `Default` membership cannot survive the
authoritative restore. Local archive categories remain local.

The complete protobuf is staged separately before the restore. It becomes the
active remote baseline only after media, settings, preference baselines, and
media-selection state succeed. If the operation is interrupted, upload and
two-way sync remain blocked until Download-only is retried; the staged payload
is never interpreted as upload intent.

Mihon factory sources such as Jellyfin are reconciled by native source ID.
Synced preference values replace stale bridge values for keys present in the
remote store, factory children are rediscovered, and newly revealed children
receive their own deferred preference stores. Display names are advisory and
are never used as identity.

## Novel file limitation

Neither Chimahon's `BackupNovel` wire model nor `Chimahon_sync.proto.gz`
contains EPUB bytes. Sync transfers novel metadata and progress, not books.
Mangatan therefore materializes a remote-only novel as a visible placeholder;
Chimahon likewise shows a Mangatan-only novel as missing its EPUB. Importing a
matching EPUB adopts the retained identity, categories, and progress.

Full EPUB transfer uses Mangatan's separate provider-neutral
manifest/blob protocol, documented in
[`docs/mangatan_epub_blob_protocol.md`](mangatan_epub_blob_protocol.md).
Google Drive and WebDAV implement the first backends. They store immutable
SHA-256-addressed EPUB blobs and `Mangatan_epub_manifest_v1.json` alongside,
but separate from, `Chimahon_sync.proto.gz`. Adding book bytes to Chimahon's
protobuf would break wire compatibility and remains forbidden.

## Mangatan-only state

The following remains local and is deliberately absent from the Chimahon wire
payload:

- Google refresh tokens, SyncYomi credentials, provider choice, automatic-sync
  schedule, last-sync timestamps, and Mangatan's device-local sidecars.
- EPUB files, archive paths, reader caches, covers, downloaded media, local
  filesystem locations, and HoshiDicts dictionary files.
- Chapters added from a file picker, drag-and-drop, or a local archive when
  they have no portable source URL. They are a device-local overlay and are
  retained locally when remote source chapters are imported.
- Tracker account credentials. Portable progress rows for shared tracker IDs
  sync; unsupported service IDs remain opaque remotely and are not applied to
  a mismatched Mangatan tracker.
- Mangatan-only application settings, local source installation/cache state,
  window/UI state, and other preferences with no Chimahon key. They are not
  emitted into a Chimahon backup and importing Chimahon data does not delete
  them.
- Chimahon's `fullscreen` and `player_fullscreen` values remain opaque on the
  wire. They control Android system bars and are not equivalent to Mangatan's
  desktop window-fullscreen settings, which stay device-local.
- Category UI state which Chimahon cannot encode, such as Mangatan's
  `shouldUpdate` value. The wire adapters retain it locally.

## Chimahon-only or opaque state

- SY fields 600-603 and J2K custom artist, author, description, and genre fields
  801, 802, 804, and 805 have no lossless Mangatan model. They remain exact
  protobuf unknown fields but cannot be viewed or edited in Mangatan. The
  reference backup exercises fields 601 and 602.
- Root manga and Anki statistics fields 710 and 711 are retained as opaque
  rows when present in a cloud or selected manual backup. They are not merged
  by `BackupMangaStats.mangaId`, because that ID is local to Chimahon's
  database, and Chimahon's normal `SyncService` does not emit these fields.
- Remote-only saved-search/feed/source/repository records can be retained even
  when Mangatan has no corresponding UI or installed extension. Retention does
  not imply that Mangatan can execute or edit them.
- Chimahon's normal `mergeSyncData` does not include `backupFeeds`, so a later
  Chimahon-authored sync may drop feed rows even though Mangatan preserves
  them. Mangatan cannot make another client retain a field that client omits.
- Exact-name category collisions and opaque category IDs/flag bits can be
  retained on the wire without being safely editable until the category UI
  handoff is implemented.

Novel statistics differ from the root manga/Anki statistics: they are nested
under a stable novel identity and Chimahon merges them by date and modification
clock, so they remain part of routine cross-device sync.

## Current verification boundary

The macOS ARM64 debug app completed an authenticated Drive sync and subsequent
read-only preview with a stable local projection and zero hard safety failures.
The latest observed remote contained 220 manga, 21,543 chapters, five novels,
27 novel-stat rows, 57 source rows, 182 app preferences, and two feeds.

Windows and Linux use the tested shared core and have platform wiring tests,
but native-host login/build/runtime smoke tests remain to be performed on
those operating systems. Linux host verification must use x86-64.
