# Chimahon-compatible sync contract

This concerns Mangatan's Chimahon backup/sync protocol, not the separate native
Mangayomi sync protocol. Transport (SyncYomi, Drive, WebDAV) must not change the
merge contract.

## Cross-client differences

The compatibility reference is Chimahon's `SyncService`, `BackupAnime`, and
backup creators at commit
[`da871b45a23cf51f2b431310883606daf8a5a062`](https://github.com/Chimahon/chimahon/tree/da871b45a23cf51f2b431310883606daf8a5a062).

| Value | Chimahon wire meaning | Mangatan boundary |
| --- | --- | --- |
| Manga/anime identity | Source, URL, normalized title, nullable normalized author | Shared `chimahon_media_identity.dart`; source + URL database lookup is not wire identity |
| Chapter/episode identity | URL, exact name, float32 number | Quantize canonical numbers before comparison and encoding; a shared URL alone is insufficient |
| Anime `id` / `parentId` | Database-local relationship handles | Resolve each input graph first, then assign a shared identity-based namespace |
| Category membership | Category order used as a handle | Compare category meaning by exact name and remap memberships when orders collide |
| Missing season fields | Kotlin defaults on a season-aware record | Episodes = 1, flags/order = 0, season number = -1, background/parent = null |
| Unsupported fields | Still part of the other client's data | Retain opaque protobuf fields without projecting them into unrelated local settings |

Chimahon's season-aware creator includes a positive anime ID. Older projections
can omit IDs while synthesizing a fetch type; that alone is not evidence that
they can express season edits. An absent parent on a season-aware winner means
detach, not "retain the previous parent." Existing invalid remote links remain
opaque and are never used to attach imported rows. Their handles are reserved
so newly added rows cannot accidentally make an orphan point at a different
series. Duplicate IDs and cyclic/cross-source parent links cannot resolve to
local parents.

Mangatan-only settings, credentials, local files, and other device state stay
local. This is distinct from retaining **Chimahon-only** data that already
exists in a selected backup or cloud payload. The portable-path check applies
to a fresh Mangatan export, not to opaque rows in an explicitly selected Android
backup.

## Routine sync and explicit restore are different transitions

Routine sync uses the existing version/conflict rules and independently checks
the proposed merge. A user-selected older backup intentionally overrides those
rules for its selected identities. Validating that operation as an ordinary
newest-wins merge rejects the user's intended resets.

The upload path therefore proves two transitions:

1. Audit the ordinary merged candidate against the local intent and remote.
2. Apply the selected restore, then decode the **actual encoded upload** and
   verify selected values, necessary clock promotions, and preservation of
   unselected records/children and unknown fields.

Both proofs must succeed. Categories and season links are compared after
rebasing handles, without repairing malformed evidence during validation.
Conditional upload/retry, recovery preservation, and pending-intent persistence
remain in force. Failed validation neither uploads nor clears pending intent.
Restore diagnostics contain fixed collection-level codes, never user titles,
URLs, or preference values.

The transition proof also rejects collapsed category handles, loss of retained
season fields during a legacy restore, novel-category duplication/unknown-field
loss, and invented statistics. Statistics must use the exact per-counter maximum
of the inputs, not merely a value greater than either input.

Local commit persistence saves both projection baselines before publishing the
remote baseline and consuming pending restore intent. A failed baseline write
therefore leaves the selected backup and its original projection evidence ready
for a retry. An upload with a lost acknowledgement likewise retains intent:
the next attempt downloads current remote state and performs a new conditional
merge, rather than assuming that the server did or did not accept the write.

## Regression verification

`chimahon_sync_contract_test.dart` crosses merger, restore authority, codec,
engine, and production safety gate. It includes duplicate URLs, fractional
numbers, nullable authors, category/season handle collisions, intentional
resets, opaque Android rows, and deliberately corrupted encoded output.
`chimahon_anime_seasons_test.dart` also checks ID permutations, legacy parents,
orphan reservation, and convergence.

Unknown chapter/episode numbers are normalized for matching, not blindly
rewritten in an unchanged remote wire record. Actual duplicate aliases are still
consolidated without losing progress. Database tests cover omitted Kotlin season
defaults, fractional episodes, and explicit detachment of non-favorite seasons
without deleting their cached playback progress.

`chimahon_restore_transition_safety_test.dart` injects corrupt output into the
two restore proofs. `chimahon_sync_recovery_test.dart` exercises rejected uploads,
lost acknowledgements, import failures, and failures at each baseline-write
boundary with both protobuf and gzip, then reopens the durable pending state and
requires a successful, convergent retry. CI runs the deterministic sync/season
suite on Windows and Linux; no private fixture or cloud credentials are needed.

The opt-in `chimahon_state_replay_test.dart` reproduces private failed states
without checking fixtures into source control. Configure:

- `CHIMAHON_REPLAY_DATABASE`: directory containing a consistent snapshot of
  `mangayomiDb.isar` and optional mining/statistics Hive files.
- `CHIMAHON_REPLAY_ACCOUNT`: account sidecar directory; its sibling
  `manual_restore` directory is copied too.
- `CHIMAHON_REPLAY_REMOTE`: captured remote protobuf or `.tachibk` file.
- Optional `CHIMAHON_REPLAY_ISAR_LIBRARY`: matching native Isar library path.

Run `flutter test test/services/sync/chimahon_state_replay_test.dart`. The test
copies inputs into a new temporary directory, uses an in-memory transport,
imports media/settings/statistics through the production adapters, and requires
three further audited cycles to produce identical protobuf bytes. Dictionary
ordering is simulated in memory; no bridge discovery or cloud write occurs.
Temporary copies are removed afterward. Prefer snapshots captured while the
app is closed; do not archive raw user fixtures or credentials in the repo.

The failed Windows state that motivated this correction passes that replay.
This does not substitute for a rebuilt-app sync with Chimahon on the other
device; no live remote was changed during the replay.

## Design references

The default/presence distinction follows the
[Protocol Buffers field-presence guidance](https://protobuf.dev/programming-guides/field_presence/).
The projection/preservation invariant is the same problem studied by
[bidirectional transformations](https://www.cis.upenn.edu/~bcpierce/papers/boomerang-tr.pdf)
and [retentive lenses](https://arxiv.org/abs/2001.02031): writing an unchanged
lossy view back must not discard data outside that view. Here that is enforced
by shared identities, explicit projection gaps, retained opaque data, and
round-trip tests, not by treating every omitted field as a preservation rule.

Failure injection also follows the distinction between a rejected write and an
ambiguous result illustrated by
[CockroachDB's transaction-recovery investigation](https://www.cockroachlabs.com/blog/demonic-nondeterminism/).
The storage protocols differ, but the applicable invariant is the same: a
missing acknowledgement is not proof that a write failed.
