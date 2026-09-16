import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupEpisode.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/sync/chimahon_anime_seasons.dart';
import 'package:mangayomi/services/sync/chimahon_child_identity.dart';
import 'package:mangayomi/services/sync/chimahon_deferred_payload_store.dart';
import 'package:mangayomi/services/sync/chimahon_media_identity.dart';
import 'package:mangayomi/services/sync/chimahon_pending_restore_authority.dart';
import 'package:mangayomi/services/sync/chimahon_pre_upload_safety_gate.dart';
import 'package:mangayomi/services/sync/chimahon_remote_recovery_store.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:mangayomi/services/sync/cross_device_sync_engine.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';

const _codec = ChimahonSyncCodec();
const _merger = ChimahonSyncMerger();
const _authority = ChimahonPendingRestoreAuthority();

void main() {
  test('fractional child identity is stable through protobuf and gzip', () {
    for (final format in ChimahonSyncWireFormat.values) {
      for (final number in [0.1, 1.1, 17.3, 16777217.0, -1.0]) {
        final chapter = BackupChapter(
          url: '/part',
          name: 'Part 17.3',
          chapterNumber: number,
        );
        final episode = BackupEpisode(
          url: '/episode',
          name: 'Episode 17.3',
          episodeNumber: number,
        );
        final backup = BackupMihon(
          backupManga: [
            BackupManga(chapters: canonicalizeChimahonChapters([chapter])),
          ],
          backupAnime: [
            BackupAnime(episodes: canonicalizeChimahonEpisodes([episode])),
          ],
        );
        final decoded = _codec
            .decode(_codec.encode(backup, format: format))
            .backup;
        expect(
          chimahonChapterIdentity(decoded.backupManga.single.chapters.single),
          chimahonChapterIdentity(chapter),
        );
        expect(
          chimahonEpisodeIdentity(decoded.backupAnime.single.episodes.single),
          chimahonEpisodeIdentity(episode),
        );
      }
    }
  });

  test(
    'restore uses composite child identity through merge, codec, and gate',
    () async {
      final pending = BackupMihon(
        backupManga: [
          _manga(
            '/book',
            version: 2,
            chapters: [
              _chapter('Part 1.1', modified: 10, read: false),
              _chapter('Alternate 1.1', modified: 11, read: true),
            ],
          ),
        ],
      );
      final remote = BackupMihon(
        backupManga: [
          _manga(
            '/book',
            version: 20,
            chapters: [
              _chapter('Part 1.1', modified: 40, read: true),
              _chapter('Alternate 1.1', modified: 50, read: false),
              BackupChapter(
                url: '/cloud-only',
                name: 'Cloud only',
                version: Int64(8),
              ),
            ],
          ),
          _manga('/cloud-book', version: 3),
        ],
      );
      final storage = _Storage(remote);
      final sidecar = _Pending(pending);
      final recovery = _Recovery();
      final gate = ChimahonPreUploadSafetyGate(recoveryStore: recovery);
      final engine = CrossDeviceSyncEngine(
        storage: storage,
        deferredPayloadStore: sidecar,
        exportLocal: () async => pending.deepCopy(),
        importMerged: (_) async {},
        preUpload: gate.check,
      );
      await engine.uploadPreservingRemote();
      final uploaded = _codec.decode(storage.bytes).backup;
      expect(sidecar.pending, isNull);
      expect(recovery.calls, 1);
      expect(uploaded.backupManga.map((row) => row.url), [
        '/book',
        '/cloud-book',
      ]);
      final chapters = uploaded.backupManga.first.chapters;
      expect(chapters.map((row) => row.name), [
        'Part 1.1',
        'Alternate 1.1',
        'Cloud only',
      ]);
      expect(chapters.take(2).map((row) => row.read), [false, true]);
      expect(chapters.take(2).map((row) => row.lastModifiedAt), [
        Int64(10),
        Int64(11),
      ]);
      expect(chapters.take(2).map((row) => row.version), [Int64(3), Int64(3)]);

      // Repeated reads/merges of the committed wire state must converge.
      final again = await CrossDeviceSyncEngine(
        storage: storage,
        exportLocal: () async => uploaded.deepCopy(),
        importMerged: (_) async {},
        preUpload: gate.check,
      ).preview();
      expect(again.proposedBytes, storage.bytes);
    },
  );

  test('restore cannot overwrite a different parent sharing a source URL', () {
    final selected = _manga('/same', title: 'Selected');
    final cloudOnly = _manga('/same', title: 'Cloud only', version: 90);
    final pending = BackupMihon(backupManga: [selected]);
    final remote = BackupMihon(backupManga: [cloudOnly]);
    final merged = _merger.merge(local: pending, remote: remote);
    final uploaded = _authority.apply(
      pending: pending,
      localIntent: pending,
      remote: remote,
      merged: merged,
    );
    expect(uploaded.backupManga, hasLength(2));
    expect(uploaded.backupManga.first, cloudOnly);
    expect(uploaded.backupManga.last.version, selected.version);
    expect(
      _authority.transitionFailure(
        uploaded: uploaded,
        pending: pending,
        localIntent: pending,
        ordinaryMerged: merged,
        remote: remote,
      ),
      isNull,
    );
  });

  test('wire parent identity distinguishes absent and empty authors', () {
    final absent = _manga('/same', title: '  TITLE  ');
    final equivalent = _manga('/same', title: 'title');
    final empty = equivalent.deepCopy()..author = '';
    expect(chimahonMangaIdentity(absent), chimahonMangaIdentity(equivalent));
    expect(chimahonMangaIdentity(absent), isNot(chimahonMangaIdentity(empty)));
    expect(
      _merger
          .merge(
            local: BackupMihon(backupManga: [absent]),
            remote: BackupMihon(backupManga: [empty]),
          )
          .backupManga,
      hasLength(2),
    );
  });

  test(
    'pending opaque Android rows are retained, not mistaken for local exports',
    () async {
      final pending = BackupMihon(
        backupManga: [
          _manga(
            '/book',
            chapters: [
              BackupChapter(
                url: 'content://reader/document/42',
                name: 'Device chapter',
              ),
            ],
          ),
        ],
      );
      final storage = _Storage(BackupMihon(backupManga: [_manga('/cloud')]));
      await CrossDeviceSyncEngine(
        storage: storage,
        deferredPayloadStore: _Pending(pending),
        exportLocal: () async => BackupMihon(),
        importMerged: (_) async {},
        preUpload: ChimahonPreUploadSafetyGate(recoveryStore: _Recovery())
            .check,
      ).uploadPreservingRemote();
      expect(
        _codec
            .decode(storage.bytes)
            .backup
            .backupManga
            .last
            .chapters
            .single
            .url,
        'content://reader/document/42',
      );
    },
  );

  for (final tamper in <String, void Function(BackupMihon)>{
    'parent version': (backup) => backup.backupManga.first.version = Int64.ZERO,
    'parent modified clock': (backup) =>
        backup.backupManga.first.lastModifiedAt = Int64(999),
    'child version': (backup) =>
        backup.backupManga.first.chapters.first.version = Int64.ZERO,
    'cloud-only child': (backup) =>
        backup.backupManga.first.chapters.removeWhere((c) => c.url == '/cloud'),
    'unknown data': (backup) => backup.unknownFields.clear(),
  }.entries) {
    test(
      'encoded restore rejects corrupt ${tamper.key} and keeps pending intent',
      () async {
        final pending = BackupMihon(
          backupManga: [
            _manga('/book', chapters: [_chapter('Selected')]),
          ],
        );
        final remote = BackupMihon(
          backupManga: [
            _manga(
              '/book',
              version: 5,
              chapters: [
                _chapter('Selected'),
                BackupChapter(url: '/cloud', name: 'Cloud'),
              ],
            ),
          ],
        )..unknownFields.mergeVarintField(9999, Int64(42));
        final storage = _Storage(remote);
        final original = storage.bytes;
        final sidecar = _Pending(pending);
        final engine = CrossDeviceSyncEngine(
          storage: storage,
          deferredPayloadStore: sidecar,
          codec: _TamperingCodec(tamper.value),
          exportLocal: () async => pending.deepCopy(),
          importMerged: (_) async {},
          preUpload: ChimahonPreUploadSafetyGate(recoveryStore: _Recovery())
              .check,
        );
        await expectLater(engine.uploadPreservingRemote(), throwsStateError);
        expect(storage.bytes, original);
        expect(sidecar.pending, isNotNull);
      },
    );
  }

  test(
    'restore proof rejects loss of cloud-only children and unknown data',
    () {
      final pending = BackupMihon(
        backupManga: [
          _manga('/book', chapters: [_chapter('Selected')]),
        ],
      );
      final remote = BackupMihon(
        backupManga: [
          _manga(
            '/book',
            version: 5,
            chapters: [BackupChapter(url: '/cloud', name: 'Cloud')],
          ),
        ],
      )..unknownFields.mergeVarintField(9999, Int64(42));
      final ordinary = _merger.merge(local: pending, remote: remote);
      final uploaded = _authority.apply(
        pending: pending,
        localIntent: pending,
        remote: remote,
        merged: ordinary,
      );
      final lostChild = uploaded.deepCopy()
        ..backupManga.single.chapters.removeWhere((row) => row.url == '/cloud');
      expect(
        _authority.containsSelectedIntent(
          uploaded: lostChild,
          pending: pending,
          localIntent: pending,
        ),
        isTrue,
      );
      expect(
        _authority.transitionFailure(
          uploaded: lostChild,
          pending: pending,
          localIntent: pending,
          ordinaryMerged: ordinary,
          remote: remote,
        ),
        isNotNull,
      );
      final lostUnknown = uploaded.deepCopy()..unknownFields.clear();
      expect(
        _authority.transitionFailure(
          uploaded: lostUnknown,
          pending: pending,
          localIntent: pending,
          ordinaryMerged: ordinary,
          remote: remote,
        ),
        'restore_unknown_fields_lost',
      );
    },
  );

  test(
    'season restore preserves a common ID namespace and category meaning',
    () {
      final pending = BackupMihon(
        backupAnime: [
          _anime('/series', id: 1, fetch: 0),
          _anime('/season', id: 2, parent: 1)..categories.add(Int64(1)),
        ],
        backupAnimeCategories: [
          BackupCategory(name: 'Selected', order: Int64(1)),
        ],
      );
      final remote = BackupMihon(
        backupAnime: [
          _anime('/unrelated', id: 1),
          _anime('/series', id: 20, fetch: 0),
          _anime('/season', id: 21, parent: 20),
          _anime('/cloud-season', id: 22, parent: 20),
        ],
        backupAnimeCategories: [BackupCategory(name: 'Cloud', order: Int64(1))],
      );
      final ordinary = _merger.merge(local: pending, remote: remote);
      final uploaded = _codec
          .decode(
            _codec.encode(
              _authority.apply(
                pending: pending,
                localIntent: pending,
                remote: remote,
                merged: ordinary,
              ),
            ),
          )
          .backup;
      final parents = chimahonSeasonParents(uploaded.backupAnime);
      final season = uploaded.backupAnime.singleWhere(
        (row) => row.url == '/season',
      );
      final cloudSeason = uploaded.backupAnime.singleWhere(
        (row) => row.url == '/cloud-season',
      );
      expect(parents[season]!.url, '/series');
      expect(parents[cloudSeason]!.url, '/series');
      expect(uploaded.backupAnime.map((row) => row.id).toSet(), hasLength(4));
      expect(
        _authority.containsSelectedIntent(
          uploaded: uploaded,
          pending: pending,
          localIntent: pending,
        ),
        isTrue,
      );
      expect(
        _authority.transitionFailure(
          uploaded: uploaded,
          pending: pending,
          localIntent: pending,
          ordinaryMerged: ordinary,
          remote: remote,
        ),
        isNull,
      );
      final malformedLink = uploaded.deepCopy();
      malformedLink.backupAnime
          .singleWhere((row) => row.url == '/cloud-season')
          .parentId = Int64(
        999,
      );
      expect(
        _authority.transitionFailure(
          uploaded: malformedLink,
          pending: pending,
          localIntent: pending,
          ordinaryMerged: ordinary,
          remote: remote,
        ),
        isNotNull,
      );
      final duplicateId = uploaded.deepCopy();
      duplicateId.backupAnime.last.id = duplicateId.backupAnime.first.id;
      expect(
        _authority.transitionFailure(
          uploaded: duplicateId,
          pending: pending,
          localIntent: pending,
          ordinaryMerged: ordinary,
          remote: remote,
        ),
        'restore_duplicate_anime_id',
      );
    },
  );

  test(
    'Kotlin omitted season defaults reset local values and preserve parent',
    () {
      final parent = _anime('/series', id: 1, fetch: 0);
      final child = _anime('/season', id: 2, parent: 1)..clearFetchType();
      final local =
          Manga(
              source: null,
              author: null,
              artist: null,
              genre: null,
              imageUrl: null,
              lang: null,
              link: '/season',
              name: 'Season',
              status: Status.unknown,
              description: null,
              sourceId: null,
              itemType: ItemType.anime,
            )
            ..animeFetchType = 0
            ..seasonFlags = 32
            ..seasonNumber = 4
            ..seasonSourceOrder = 8
            ..backgroundUrl = 'old';
      applyChimahonAnimeSeasons(local, child, parent);
      expect(local.animeFetchType, 1);
      expect(local.animeParentUrl, '/series');
      expect(local.seasonFlags, 0);
      expect(local.seasonNumber, -1);
      expect(local.seasonSourceOrder, 0);
      expect(local.backgroundUrl, isNull);
      final old = child.deepCopy()
        ..seasonFlags = Int64(32)
        ..version = Int64(1);
      final newer = child.deepCopy()..version = Int64(2);
      final merged = _merger.merge(
        local: BackupMihon(backupAnime: [parent, old]),
        remote: BackupMihon(backupAnime: [parent, newer]),
      );
      expect(merged.backupAnime.last.hasSeasonFlags(), isFalse);
      expect(merged.backupAnime.last.parentId, parent.id);
    },
  );
}

BackupManga _manga(
  String url, {
  String title = 'Book',
  int version = 1,
  List<BackupChapter> chapters = const [],
}) => BackupManga(
  source: Int64(7),
  url: url,
  title: title,
  version: Int64(version),
  favorite: true,
  chapters: chapters,
);
BackupChapter _chapter(String name, {int modified = 1, bool read = false}) =>
    BackupChapter(
      url: '/shared',
      name: name,
      chapterNumber: 1.1,
      version: Int64(2),
      lastModifiedAt: Int64(modified),
      read: read,
    );
BackupAnime _anime(String url, {required int id, int? parent, int fetch = 1}) =>
    BackupAnime(
      source: Int64(8),
      url: url,
      title: url,
      id: Int64(id),
      parentId: parent == null ? null : Int64(parent),
      fetchType: fetch,
      favorite: parent == null,
    );

class _Storage implements CrossDeviceSyncStorage {
  _Storage(BackupMihon remote) : bytes = _codec.encode(remote);
  Uint8List bytes;
  @override
  ChimahonSyncWireFormat get wireFormat => ChimahonSyncWireFormat.protobuf;
  @override
  Future<RemoteSyncSnapshot?> download() async => RemoteSyncSnapshot(
    bytes: bytes,
    revision: 'revision',
    isCompleteRecovery: true,
  );
  @override
  Future<String?> upload(
    Uint8List bytes, {
    String? expectedRevision,
    bool expectedAbsent = false,
  }) async {
    this.bytes = bytes;
    return 'next';
  }
}

class _TamperingCodec extends ChimahonSyncCodec {
  _TamperingCodec(this.tamper);
  final void Function(BackupMihon) tamper;
  @override
  Uint8List encodeProtobufBytes(
    Uint8List protobufBytes, {
    ChimahonSyncWireFormat format = ChimahonSyncWireFormat.protobuf,
    int compressionLevel = 6,
  }) {
    final backup = BackupMihon.fromBuffer(protobufBytes);
    tamper(backup);
    return super.encodeProtobufBytes(
      backup.writeToBuffer(),
      format: format,
      compressionLevel: compressionLevel,
    );
  }
}

class _Pending
    implements ChimahonDeferredPayloadStore, ChimahonPendingLocalPayloadStore {
  _Pending(this.pending);
  BackupMihon? pending;
  @override
  Future<BackupMihon?> load() async => null;
  @override
  Future<BackupMihon?> loadPendingLocalPayload() async => pending;
  @override
  Future<void> save(BackupMihon backup) async {
    pending = null;
  }
}

class _Recovery implements ChimahonRemoteRecoveryStore {
  int calls = 0;
  @override
  Future<ChimahonRemoteRecoveryRecord> preserve(
    RemoteSyncSnapshot snapshot,
  ) async {
    calls++;
    return const ChimahonRemoteRecoveryRecord(
      digest: 'test',
      alreadyPresent: false,
    );
  }
}
