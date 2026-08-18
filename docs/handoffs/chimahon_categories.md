# Handoff: finish Chimahon-style categories

Finish Mangatan's existing category UI and behavior end-to-end for manga,
novels, and anime on desktop. Adapt Chimahon closely; extend the current
`Category` collection and screens instead of creating a parallel store or UI.

Use Chimahon's unified three-tab reference at
`../chimahon/app/src/main/java/eu/kanade/tachiyomi/ui/category/CategoryScreen.kt`,
the three sibling `*CategoryScreenModel.kt` files, `CategoryDialogs.kt`, the
manga/anime/novel library screen models, and `NovelCategory.kt`. Start in
Mangatan at:

- `lib/models/category.dart` and `lib/models/manga.dart`
- `lib/modules/more/categories/categories_screen.dart`
- `lib/modules/widgets/category_selection_dialog.dart`
- `lib/modules/library/library_screen.dart`
- `lib/services/sync/chimahon_category_payload_adapter.dart`
- `lib/services/sync/chimahon_novel_category_adapter.dart`
- `lib/services/sync/chimahon_manual_restore_category_adapter.dart`
- `lib/services/sync/mihon_backup_exporter.dart`
- `lib/services/sync/chimahon_sync_importer.dart`
- `lib/services/sync/chimahon_sync_merger.dart`
- `lib/modules/more/data_and_storage/providers/backup.dart` and `restore.dart`
- `lib/providers/storage_provider.dart` and `lib/services/sync_server.dart`

Required result:

- One typed Manga / Novels / Anime editor with create, normalized-unique
  rename, contiguous reorder, delete confirmation, and manga/anime hide.
- Correct implicit Default/uncategorized behavior. It is not editable; deleting
  a category atomically removes only that membership. Items keep any other
  memberships; implicit Default/uncategorized applies only when none remain.
- Single and bulk assignment from details/library selection. Bulk assignment
  is tri-state (common, mixed/unchanged, add-to-all, remove-from-all). Hidden
  categories stay assignable; hiding only removes their library tabs.
- Ordered, identity-stable library tabs with filtered/search-aware counts and
  no raw numeric routing indices.
- Keep one `Category` collection namespaced by `ItemType`, but persist the
  required Chimahon wire state and flags. Manga/anime sync identity is the
  exact category name; `order` is their membership key/conflict clock, while
  numeric `BackupCategory.id` is device-local/opaque and must never become a
  cross-device identity. Novel identities are stable strings, with `default`
  reserved; renaming a novel category must not change its UUID. Preserve
  unknown flag bits and Mangatan's `shouldUpdate` state.
- Add an idempotent Isar/JSON migration that preserves local IDs and
  memberships, `Category.updatedAt`, and Mangatan-only state; backfill the
  required novel identities/flags and repair missing or duplicate positions.
  Reorder and assignment mutations must advance the appropriate category/item
  conflict clock.
- Make exporter/importer/merger follow each wire model: manga/anime match exact
  names and remap memberships through `order`; novel categories match stable
  ID before normalized-name fallback. Encode reorders as unique monotonic
  orders above the observed baseline so downward moves and A/B swaps survive
  Chimahon's per-row maximum rule, then remap memberships atomically.
- Treat the wire's deletion limits honestly. Absence is not a deletion;
  manga/anime rename creates a new exact-name row, and Chimahon may retain or
  re-send the old/deleted row. Do not fake portability with numeric IDs or drop
  opaque remote rows. Keep local CRUD functional, retain explicit local-edit
  provenance, and document this routine-sync limitation. A novel rename may
  update its stable UUID row only when that provenance proves a real local edit.
- Preserve the current novel granularity unless deliberately expanding the
  schema: imported per-EPUB memberships union onto the Mangatan parent, and a
  parent assignment projects to each EPUB. Do not silently claim per-book
  category editing without a separate migration and UI.
- Round-trip represented membership, flags/hidden, novel UUIDs, remote-only
  rows, opaque manga/anime numeric IDs, and protobuf unknown fields. UI
  trim/case uniqueness must not collapse existing exact-name Chimahon
  case/whitespace collisions in the retained wire payload.

Acceptance: domain/provider and widget tests cover CRUD, all three media
namespaces, default/hidden behavior, reorder, deletion, tri-state assignment,
tabs/counts, and active-tab stability. Sync tests cover remote -> Isar -> UI
mutation -> export/merge, same numeric ID/different-name manga or anime rows,
an A/B reorder swap with correct memberships, importer-to-UI preservation of
case/whitespace-colliding remote rows, and v1/v2 JSON plus legacy SyncYomi
clock preservation. Keep the existing category wire no-edit regressions green.
Existing settings, novels/progress, and manually added chapters remain
unchanged. Run focused analyzer/tests and desktop smoke tests on macOS,
Windows, and Linux. Do not touch mobile paths, Drive OAuth/storage/CAS, or sync
transport.

## Copy-ready prompt

Implement Chimahon-style category UI and behavior end-to-end for manga,
novels, and anime by following this handoff; keep Drive transport and the
current sync semantics unchanged.
