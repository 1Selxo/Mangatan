import 'dart:convert';

import 'package:flutter_qjs/quickjs/ffi.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/changed.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/sync_preference.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/restore.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/blend_level_state_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/animation_duration_scale_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/flex_scheme_color_state_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/pure_black_dark_mode_state_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/theme_mode_state_provider.dart';
import 'package:mangayomi/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:mangayomi/modules/more/settings/sync/providers/sync_providers.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/services/http/m_client.dart';
import 'package:mangayomi/services/sync/chimahon_deferred_payload_store.dart';
import 'package:mangayomi/services/sync/chimahon_local_sync_projection_service.dart';
import 'package:mangayomi/services/sync/chimahon_media_sync_selection.dart';
import 'package:mangayomi/services/sync/chimahon_pre_upload_safety_gate.dart';
import 'package:mangayomi/services/sync/chimahon_preference_three_way_merger.dart';
import 'package:mangayomi/services/sync/chimahon_queued_sync_gate.dart';
import 'package:mangayomi/services/sync/chimahon_remote_recovery_store.dart';
import 'package:mangayomi/services/sync/chimahon_restore_sync_coordinator.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/cross_device_sync_engine.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';
import 'package:mangayomi/services/sync/google_drive_oauth.dart';
import 'package:mangayomi/services/sync/google_drive_refresh_token_store.dart';
import 'package:mangayomi/services/sync/google_drive_sync_storage.dart';
import 'package:mangayomi/services/sync/sync_user_message.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
part 'sync_server.g.dart';

@riverpod
class SyncServer extends _$SyncServer {
  static final Set<int> _syncsInProgress = <int>{};

  final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});
  final String _loginUrl = '/login';
  final String _syncMangaUrl = '/sync/manga';
  final String _syncHistoryUrl = '/sync/histories';
  final String _syncUpdateUrl = '/sync/updates';
  final String _syncSettingsUrl = '/sync/settings';

  @override
  void build({required int syncId}) {
    ref.keepAlive();
  }

  Future<(bool, String)> login(
    AppLocalizations l10n,
    String server,
    String username,
    String password,
  ) async {
    server = server.isNotEmpty && server[server.length - 1] == '/'
        ? server.substring(0, server.length - 1)
        : server;
    try {
      var response = await http.post(
        Uri.parse('$server$_loginUrl'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': username, 'password': password}),
      );
      var cookieHeader = response.headers["set-cookie"];
      var startIdx = cookieHeader?.indexOf("id=") ?? -1;
      var endIdx = cookieHeader?.indexOf(";", startIdx) ?? -1;
      if (startIdx == -1 || endIdx == -1) {
        return (false, "Auth failed");
      }
      final authToken = cookieHeader!.substring(startIdx + 3, endIdx);
      ref
          .read(synchingProvider(syncId: syncId).notifier)
          .login(server, username, authToken);
      botToast(l10n.sync_logged);
      return (true, "");
    } catch (error) {
      return (
        false,
        safeSyncUserMessage(error, context: SyncUserMessageContext.signIn),
      );
    }
  }

  /// Returns false only when a sync was attempted and failed.
  ///
  /// Manual callers intentionally receive a result instead of an exception so
  /// their existing toast-only behavior is preserved. A disabled automatic
  /// sync or an already-running sync is a benign skip and returns true.
  Future<bool> startSync(
    AppLocalizations l10n,
    bool silent, {
    bool upload = false,
    bool download = false,
  }) async {
    if (!_syncsInProgress.add(syncId)) {
      if (!silent) {
        botToast('A sync is already in progress', second: 2);
      }
      return true;
    }
    try {
      final syncPreference = ref.read(synchingProvider(syncId: syncId));
      if (silent &&
          (!syncPreference.syncOn || syncPreference.autoSyncFrequency == 0)) {
        return true;
      }
      if (!silent && syncPreference.syncMode != SyncMode.chimahon) {
        botToast(l10n.sync_starting, second: 500);
      }
      if (syncPreference.syncMode == SyncMode.chimahon) {
        final ran = await _startChimahonSync(
          silent: silent,
          onStarting: silent
              ? null
              : () => botToast(l10n.sync_starting, second: 500),
          upload: upload,
          download: download,
        );
        if (!ran) return true;
        ref.invalidate(synchingProvider(syncId: syncId));
        if (!silent) {
          botToast(l10n.sync_finished, second: 2);
        }
        return true;
      }

      final syncNotifier = ref.read(synchingProvider(syncId: syncId).notifier);
      final resultManga = await _syncManga(
        l10n,
        syncNotifier,
        download: download,
        upload: upload,
      );
      if (!resultManga) {
        if (!silent) botToast(l10n.sync_failed, second: 5);
        return false;
      }
      if (syncPreference.syncHistories) {
        final resultHistory = await _syncHistory(
          l10n,
          syncNotifier,
          download: download,
          upload: upload,
        );
        if (!resultHistory) {
          if (!silent) botToast(l10n.sync_failed, second: 5);
          return false;
        }
      }
      if (syncPreference.syncUpdates) {
        final resultUpdate = await _syncUpdate(
          l10n,
          syncNotifier,
          download: download,
          upload: upload,
        );
        if (!resultUpdate) {
          if (!silent) botToast(l10n.sync_failed, second: 5);
          return false;
        }
      }
      if (syncPreference.syncSettings) {
        final resultSettings = await _syncSettings(
          l10n,
          download: download,
          upload: upload,
        );
        if (!resultSettings) {
          if (!silent) botToast(l10n.sync_failed, second: 5);
          return false;
        }
      }

      ref.invalidate(synchingProvider(syncId: syncId));
      if (!silent) {
        botToast(l10n.sync_finished, second: 2);
      }
      return true;
    } catch (error) {
      if (!silent) botToast(safeSyncUserMessage(error), second: 5);
      return false;
    } finally {
      _syncsInProgress.remove(syncId);
    }
  }

  Future<bool> _startChimahonSync({
    required bool silent,
    required void Function()? onStarting,
    bool upload = false,
    bool download = false,
  }) => runQueuedChimahonSync(
    coordinator: ChimahonRestoreSyncCoordinator.shared,
    readCurrentPreference: () => ref.read(synchingProvider(syncId: syncId)),
    silent: silent,
    synchronize: (currentPreference) {
      onStarting?.call();
      return _startChimahonSyncExclusive(
        currentPreference,
        upload: upload,
        download: download,
      );
    },
  );

  Future<void> _startChimahonSyncExclusive(
    SyncPreference syncPreference, {
    bool upload = false,
    bool download = false,
  }) async {
    final pendingManualRestoreStore =
        await defaultChimahonPendingManualRestoreStore();
    await pendingManualRestoreStore.ensureReadyForSync();
    final CrossDeviceSyncStorage storage;
    late final String deferredPayloadScope;
    final legacyDeferredPayloadScopes = <String>{};
    String? rotatedGoogleRefreshToken;
    switch (syncPreference.chimahonSyncProvider) {
      case ChimahonSyncProvider.syncYomi:
        final server = _normalizeServer(syncPreference.syncYomiServer);
        final token = syncPreference.syncYomiApiToken ?? '';
        if (server.isEmpty || token.isEmpty) {
          throw const SyncStorageException(
            'SyncYomi server and API token required',
          );
        }
        storage = SyncYomiStorage(baseUrl: Uri.parse(server), apiToken: token);
        deferredPayloadScope = 'syncyomi|$server|$token';
        break;
      case ChimahonSyncProvider.googleDrive:
        const tokenStore = SecureGoogleDriveRefreshTokenStore();
        final refreshToken = await tokenStore.readRefreshToken();
        if (refreshToken == null) {
          _currentSyncNotifier.setGoogleDriveConnected(false);
          throw const SyncStorageException('Google Drive is not connected');
        }
        final deviceId = _currentSyncNotifier.ensureChimahonDeviceId();
        final oauth = GoogleDriveOAuthClient();
        final googleOAuthClientId = oauth.config.clientId;
        late final GoogleDriveOAuthTokens tokens;
        try {
          tokens = await oauth.refresh(refreshToken);
        } on GoogleDriveOAuthException catch (error) {
          if (error.requiresReauthentication) {
            await tokenStore.clearRefreshToken();
            _currentSyncNotifier.setGoogleDriveConnected(false);
            throw const SyncStorageException(
              'Google Drive authorization expired; reconnect Google Drive',
            );
          }
          rethrow;
        } finally {
          oauth.close();
        }
        if (tokens.refreshToken != refreshToken) {
          rotatedGoogleRefreshToken = tokens.refreshToken;
        }
        final driveStorage = GoogleDriveSyncStorage(
          accessToken: tokens.accessToken,
          deviceId: deviceId,
        );
        storage = driveStorage;
        late final String permissionId;
        try {
          permissionId = await driveStorage.currentUserPermissionId();
        } catch (_) {
          driveStorage.close();
          rethrow;
        }
        // Drive's permission ID is a stable opaque account identity available
        // through the existing app-data scope. Include the OAuth client so a
        // build configured for another Google project cannot reuse Chimahon's
        // account baseline. The store hashes this complete key before using
        // it as a directory name.
        deferredPayloadScope =
            'google-drive|$googleOAuthClientId|$permissionId';
        // Migrate sidecars made by early builds that incorrectly keyed them
        // to a refresh token. Both values are known during token rotation.
        legacyDeferredPayloadScopes
          ..add('google-drive|$refreshToken')
          ..add('google-drive|${tokens.refreshToken}');
        _currentSyncNotifier.setGoogleDriveConnected(true);
        break;
    }
    try {
      final activeMediaSelectionScopeToken = chimahonMediaSelectionScopeToken(
        deferredPayloadScope,
      );
      final codec = const ChimahonSyncCodec();
      final localProjectionService = ChimahonLocalSyncProjectionService(
        database: isar,
        activeMediaSelectionScopeToken: activeMediaSelectionScopeToken,
        mediaSelectionStateProvider: () =>
            ChimahonMediaSyncSelectionState.fromPreference(
              isar.syncPreferences.getSync(syncId) ?? syncPreference,
            ),
      );
      final accountDeferredStore = await defaultChimahonDeferredPayloadStore(
        scopeKey: deferredPayloadScope,
      );
      await _migrateLegacyChimahonSidecars(
        target: accountDeferredStore,
        legacyScopeKeys: legacyDeferredPayloadScopes.where(
          (scope) => scope != deferredPayloadScope,
        ),
      );
      if (rotatedGoogleRefreshToken != null) {
        await const SecureGoogleDriveRefreshTokenStore().writeRefreshToken(
          rotatedGoogleRefreshToken,
        );
      }
      final uploadDeferredStore = LayeredChimahonDeferredPayloadStore(
        primary: accountDeferredStore,
        pendingManualRestore: pendingManualRestoreStore,
      );
      final remoteRecoveryStore = await defaultChimahonRemoteRecoveryStore(
        scopeKey: deferredPayloadScope,
      );
      final preUploadSafetyGate = ChimahonPreUploadSafetyGate(
        recoveryStore: remoteRecoveryStore,
      );
      if (download) {
        var localProjection = await localProjectionService.createSnapshot();
        final localBeforeDownload = localProjection.backup;
        final mediaSelectionBeforeDownload = localProjection.mediaSelection;
        final mediaSelectionInitializedBeforeDownload =
            localProjection.mediaSelectionInitialized;
        final mediaSelectionStateBeforeDownload =
            localProjection.persistedMediaSelectionState;
        final remote = await storage.download();
        if (remote == null) {
          throw const SyncStorageException(
            'No remote Chimahon sync data found',
          );
        }
        final backup = codec.decode(remote.bytes).backup;
        final downloadedSelection = chimahonMediaSelectionForExplicitRestore(
          preferences: backup.backupPreferences,
          current: mediaSelectionBeforeDownload,
        );
        final downloadedSelectionPresent =
            ChimahonMediaSyncSelection.hasAnyPreference(
              backup.backupPreferences,
            );
        final downloadedSelectionCanInitialize =
            downloadedSelectionPresent &&
            !ChimahonMediaSyncSelection.hasMalformedPreference(
              backup.backupPreferences,
            );
        localProjection = await localProjectionService.createSnapshot();
        if (!_sameChimahonBackup(localBeforeDownload, localProjection.backup) ||
            localProjection.persistedMediaSelectionState !=
                mediaSelectionStateBeforeDownload) {
          throw const SyncStorageException(
            'Local data changed while Chimahon data was downloading; '
            'download again to avoid overwriting the newer local state',
          );
        }
        await restoreChimahonSyncData(ref, backup);
        // A download is not evidence that the pending manual restore reached
        // the remote backend, so only update this account's cache here.
        await accountDeferredStore.save(backup);
        localProjection = await ChimahonLocalSyncProjectionService(
          database: isar,
          mediaSelection: downloadedSelection,
          mediaSelectionInitialized: downloadedSelectionCanInitialize
              ? true
              : mediaSelectionInitializedBeforeDownload,
          mediaSelectionUserSelected: downloadedSelectionCanInitialize
              ? false
              : mediaSelectionStateBeforeDownload.userSelected,
          mediaSelectionGeneration:
              mediaSelectionStateBeforeDownload.generation,
          mediaSelectionScopeToken: downloadedSelectionCanInitialize
              ? activeMediaSelectionScopeToken
              : mediaSelectionStateBeforeDownload.scopeToken,
        ).createSnapshot();
        final localAfterImport = localProjection.backup;
        await accountDeferredStore.saveLocalPreferenceBaseline(
          const ChimahonPreferenceThreeWayMerger().baselineForProjection(
            local: localAfterImport.backupPreferences,
            raw: backup.backupPreferences,
            locallyUnrepresentableKeys:
                localProjection.unrepresentablePreferenceKeys,
          ),
        );
        await accountDeferredStore.saveLocalSourcePreferenceBaseline(
          localAfterImport.backupSourcePreferences,
        );
        if (downloadedSelectionCanInitialize) {
          _currentSyncNotifier.setChimahonMediaSelectionIfUnchanged(
            expected: mediaSelectionStateBeforeDownload,
            updated: downloadedSelection,
            updatedScopeToken: activeMediaSelectionScopeToken,
          );
        }
      } else {
        // Rebuild the engine and tombstone snapshot if a local edit lands
        // during network I/O. This lets one automatic retry include a tracker
        // deletion or chapter update that the first snapshot could not see.
        for (var localAttempt = 0; ; localAttempt++) {
          final initialProjection = await localProjectionService
              .createSnapshot();
          var currentProjection = initialProjection;
          var initialProjectionPending = true;
          Future<BackupMihon> exportLocal() async {
            if (initialProjectionPending) {
              initialProjectionPending = false;
            } else {
              currentProjection = await localProjectionService.createSnapshot();
            }
            return currentProjection.backup;
          }

          final engine = CrossDeviceSyncEngine(
            storage: storage,
            exportLocal: exportLocal,
            importMerged: upload
                ? (_) async {}
                : (backup) => restoreChimahonSyncData(ref, backup),
            deferredPayloadStore: uploadDeferredStore,
            localTrackingDeletions: initialProjection.trackingDeletionKeys,
            localMediaSelection: initialProjection.mediaSelection,
            localMediaSelectionInitialized:
                initialProjection.mediaSelectionInitialized,
            localMediaSelectionUserSelected:
                initialProjection.mediaSelectionUserSelected,
            localMediaSelectionGeneration:
                initialProjection.mediaSelectionGeneration,
            localMediaSelectionState:
                initialProjection.persistedMediaSelectionState,
            localMediaSelectionProvider: () => currentProjection.mediaSelection,
            localMediaSelectionInitializedProvider: () =>
                currentProjection.mediaSelectionInitialized,
            localMediaSelectionUserSelectedProvider: () =>
                currentProjection.mediaSelectionUserSelected,
            localMediaSelectionGenerationProvider: () =>
                currentProjection.mediaSelectionGeneration,
            localMediaSelectionStateProvider: () =>
                currentProjection.persistedMediaSelectionState,
            localUnrepresentablePreferenceKeys: () =>
                currentProjection.unrepresentablePreferenceKeys,
            preUpload: preUploadSafetyGate.check,
          );
          final result = upload
              ? await engine.uploadPreservingRemote()
              : await engine.synchronize();
          final shouldStampExplicitScope =
              result.initialMediaSelectionState.userSelected &&
              result.initialMediaSelectionState.scopeToken !=
                  activeMediaSelectionScopeToken;
          if (result.mediaSelectionNeedsPersistence ||
              shouldStampExplicitScope) {
            final retainExplicitSelection =
                result.initialMediaSelectionState.userSelected &&
                result.mediaSelection ==
                    result.initialMediaSelectionState.selection;
            _currentSyncNotifier.setChimahonMediaSelectionIfUnchanged(
              expected: result.initialMediaSelectionState,
              updated: result.mediaSelection,
              updatedUserSelected: retainExplicitSelection,
              updatedScopeToken: activeMediaSelectionScopeToken,
            );
          }
          final uploadedChangedPartIds = <int>{
            for (final deletion in result.localTrackingDeletions)
              ...?initialProjection
                  .changedPartIdsByTrackingDeletionKey[deletion],
          };
          if (uploadedChangedPartIds.isNotEmpty) {
            await isar.writeTxn(
              () =>
                  isar.changedParts.deleteAll(uploadedChangedPartIds.toList()),
            );
          }
          if (!result.requiresRetry) break;
          if (localAttempt >= 1) {
            throw const SyncStorageException(
              'Local data kept changing while Chimahon sync was uploading; '
              'sync again to finish uploading the newest state',
            );
          }
        }
      }
    } finally {
      if (storage case ClosableSyncStorage closable) {
        closable.close();
      }
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentSyncNotifier.setLastSyncManga(timestamp);
    _currentSyncNotifier.setLastSyncHistory(timestamp);
    _currentSyncNotifier.setLastSyncUpdate(timestamp);
  }

  Synching get _currentSyncNotifier =>
      ref.read(synchingProvider(syncId: syncId).notifier);

  Future<void> _migrateLegacyChimahonSidecars({
    required FileChimahonDeferredPayloadStore target,
    required Iterable<String> legacyScopeKeys,
  }) async {
    var hasPayload = await target.load() != null;
    var hasPreferenceBaseline =
        await target.loadLocalPreferenceBaseline() != null;
    var hasSourcePreferenceBaseline =
        await target.loadLocalSourcePreferenceBaseline() != null;
    if (hasPayload && hasPreferenceBaseline && hasSourcePreferenceBaseline) {
      return;
    }

    for (final scopeKey in legacyScopeKeys.toSet()) {
      final legacy = await defaultChimahonDeferredPayloadStore(
        scopeKey: scopeKey,
      );
      if (!hasPayload) {
        final payload = await legacy.load();
        if (payload != null) {
          await target.save(payload);
          hasPayload = true;
        }
      }
      if (!hasPreferenceBaseline) {
        final baseline = await legacy.loadLocalPreferenceBaseline();
        if (baseline != null) {
          await target.saveLocalPreferenceBaseline(baseline);
          hasPreferenceBaseline = true;
        }
      }
      if (!hasSourcePreferenceBaseline) {
        final baseline = await legacy.loadLocalSourcePreferenceBaseline();
        if (baseline != null) {
          await target.saveLocalSourcePreferenceBaseline(baseline);
          hasSourcePreferenceBaseline = true;
        }
      }
      if (hasPayload && hasPreferenceBaseline && hasSourcePreferenceBaseline) {
        return;
      }
    }
  }

  bool _sameChimahonBackup(BackupMihon first, BackupMihon second) {
    final firstBytes = first.writeToBuffer();
    final secondBytes = second.writeToBuffer();
    if (firstBytes.length != secondBytes.length) return false;
    for (var index = 0; index < firstBytes.length; index++) {
      if (firstBytes[index] != secondBytes[index]) return false;
    }
    return true;
  }

  String _normalizeServer(String? server) {
    final value = (server ?? '').trim();
    if (value.endsWith('/')) return value.substring(0, value.length - 1);
    return value;
  }

  Future<bool> _syncManga(
    AppLocalizations l10n,
    Synching syncNotifier, {
    bool upload = false,
    bool download = false,
  }) async {
    final mangaData = _getMangaData(upload: upload, download: download);
    final accessToken = _getAccessToken();
    var response = await http.post(
      Uri.parse('${_getServer()}$_syncMangaUrl'),
      headers: {
        'Content-Type': 'application/json',
        'Cookie': 'id=$accessToken',
      },
      body: mangaData,
    );
    if (response.statusCode != 200) {
      botToast(l10n.sync_failed, second: 5);
      return false;
    }

    if (!upload) {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      await _upsertCategories(jsonData, syncNotifier);
      await _upsertManga(jsonData, syncNotifier);
      await _upsertChapters(jsonData, syncNotifier);
      await _upsertTracks(jsonData, syncNotifier);
    } else {
      await syncNotifier.clearChangedParts([
        ActionType.removeCategory,
        ActionType.removeItem,
        ActionType.removeChapter,
        ActionType.removeTrack,
      ], true);
    }

    syncNotifier.setLastSyncManga(DateTime.now().millisecondsSinceEpoch);

    return true;
  }

  Future<bool> _syncHistory(
    AppLocalizations l10n,
    Synching syncNotifier, {
    bool upload = false,
    bool download = false,
  }) async {
    final historyData = _getHistoryData(upload: upload, download: download);
    final accessToken = _getAccessToken();
    var response = await http.post(
      Uri.parse('${_getServer()}$_syncHistoryUrl'),
      headers: {
        'Content-Type': 'application/json',
        'Cookie': 'id=$accessToken',
      },
      body: historyData,
    );
    if (response.statusCode != 200) {
      botToast(l10n.sync_failed, second: 5);
      return false;
    }

    if (!upload) {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      await _upsertHistories(jsonData, syncNotifier);
    } else {
      await syncNotifier.clearChangedParts([ActionType.removeHistory], true);
    }

    syncNotifier.setLastSyncHistory(DateTime.now().millisecondsSinceEpoch);

    return true;
  }

  Future<bool> _syncUpdate(
    AppLocalizations l10n,
    Synching syncNotifier, {
    bool upload = false,
    bool download = false,
  }) async {
    final updateData = _getUpdateData(upload: upload, download: download);
    final accessToken = _getAccessToken();
    var response = await http.post(
      Uri.parse('${_getServer()}$_syncUpdateUrl'),
      headers: {
        'Content-Type': 'application/json',
        'Cookie': 'id=$accessToken',
      },
      body: updateData,
    );
    if (response.statusCode != 200) {
      botToast(l10n.sync_failed, second: 5);
      return false;
    }

    if (!upload) {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      await _upsertUpdates(jsonData, syncNotifier);
    } else {
      await syncNotifier.clearChangedParts([ActionType.removeUpdate], true);
    }

    syncNotifier.setLastSyncUpdate(DateTime.now().millisecondsSinceEpoch);

    return true;
  }

  Future<bool> _syncSettings(
    AppLocalizations l10n, {
    bool upload = false,
    bool download = false,
  }) async {
    final settingsData = _getSettingsData(download: download);
    final accessToken = _getAccessToken();
    var response = await http.post(
      Uri.parse('${_getServer()}$_syncSettingsUrl'),
      headers: {
        'Content-Type': 'application/json',
        'Cookie': 'id=$accessToken',
      },
      body: settingsData,
    );
    if (response.statusCode != 200) {
      botToast(l10n.sync_failed, second: 5);
      return false;
    }

    if (!upload) {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      await _upsertSettings(jsonData);
    }

    return true;
  }

  Future<void> _upsertCategories(
    Map<String, dynamic> jsonData,
    Synching syncNotifier,
  ) async {
    final categories =
        (jsonData["categories"] as List?)
            ?.map((e) => Category.fromJson(e))
            .toList() ??
        [];
    await isar.writeTxn(() async {
      for (var category
          in await isar.categorys.filter().idIsNotNull().findAll()) {
        final temp = categories.firstWhereOrNull((e) => e.id == category.id);
        if (temp != null) {
          if ((category.updatedAt ?? 0) < (temp.updatedAt ?? 1)) {
            await isar.categorys.put(temp);
          }
          categories.remove(temp);
        } else {
          await isar.categorys.delete(category.id!);
        }
      }
      for (var category in categories) {
        await isar.categorys.put(category);
      }
      await syncNotifier.clearChangedParts([ActionType.removeCategory], false);
    });
  }

  Future<void> _upsertManga(
    Map<String, dynamic> jsonData,
    Synching syncNotifier,
  ) async {
    final mangas =
        (jsonData["manga"] as List?)?.map((e) => Manga.fromJson(e)).toList() ??
        [];
    await isar.writeTxn(() async {
      for (var manga in await isar.mangas.filter().idIsNotNull().findAll()) {
        final temp = mangas.firstWhereOrNull((e) => e.id == manga.id);
        if (temp != null) {
          if ((manga.updatedAt ?? 0) < (temp.updatedAt ?? 1)) {
            await isar.mangas.put(temp);
          }
          mangas.remove(temp);
        } else {
          await isar.mangas.delete(manga.id!);
        }
      }
      for (var manga in mangas) {
        await isar.mangas.put(manga);
      }
      await syncNotifier.clearChangedParts([ActionType.removeItem], false);
    });
  }

  Future<void> _upsertChapters(
    Map<String, dynamic> jsonData,
    Synching syncNotifier,
  ) async {
    final chapters =
        (jsonData["chapters"] as List?)
            ?.map((e) => Chapter.fromJson(e))
            .toList() ??
        [];
    await isar.writeTxn(() async {
      for (var chapter
          in await isar.chapters.filter().idIsNotNull().findAll()) {
        final temp = chapters.firstWhereOrNull((e) => e.id == chapter.id);
        if (temp != null) {
          final manga = await isar.mangas.get(temp.mangaId!);
          if (manga != null &&
              (chapter.updatedAt ?? 0) < (temp.updatedAt ?? 1)) {
            await isar.chapters.put(temp..manga.value = manga);
            await temp.manga.save();
          }
          chapters.remove(temp);
        } else {
          await isar.chapters.delete(chapter.id!);
        }
      }
      for (var chapter in chapters) {
        final manga = await isar.mangas.get(chapter.mangaId!);
        if (manga != null) {
          await isar.chapters.put(chapter..manga.value = manga);
          await chapter.manga.save();
        }
      }
      await syncNotifier.clearChangedParts([ActionType.removeChapter], false);
    });
  }

  Future<void> _upsertTracks(
    Map<String, dynamic> jsonData,
    Synching syncNotifier,
  ) async {
    final tracks =
        (jsonData["tracks"] as List?)?.map((e) => Track.fromJson(e)).toList() ??
        [];
    await isar.writeTxn(() async {
      for (var track in await isar.tracks.filter().idIsNotNull().findAll()) {
        final temp = tracks.firstWhereOrNull((e) => e.id == track.id);
        if (temp != null) {
          if ((track.updatedAt ?? 0) < (temp.updatedAt ?? 1)) {
            await isar.tracks.put(temp);
          }
          tracks.remove(temp);
        } else {
          await isar.tracks.delete(track.id!);
        }
      }
      for (var track in tracks) {
        await isar.tracks.put(track);
      }
      await syncNotifier.clearChangedParts([ActionType.removeTrack], false);
    });
  }

  Future<void> _upsertHistories(
    Map<String, dynamic> jsonData,
    Synching syncNotifier,
  ) async {
    final histories =
        (jsonData["histories"] as List?)
            ?.map((e) => History.fromJson(e))
            .toList() ??
        [];
    await isar.writeTxn(() async {
      for (var history
          in await isar.historys.filter().idIsNotNull().findAll()) {
        final temp = histories.firstWhereOrNull((e) => e.id == history.id);
        if (temp != null) {
          final chapter = await isar.chapters.get(temp.chapterId!);
          if (chapter != null &&
              (history.updatedAt ?? 0) < (temp.updatedAt ?? 1)) {
            await isar.historys.put(temp..chapter.value = chapter);
            await temp.chapter.save();
          }
          histories.remove(temp);
        } else {
          await isar.historys.delete(history.id!);
        }
      }
      for (var history in histories) {
        final chapter = await isar.chapters.get(history.chapterId!);
        if (chapter != null) {
          await isar.historys.put(history..chapter.value = chapter);
          await history.chapter.save();
        }
      }
      await syncNotifier.clearChangedParts([ActionType.removeHistory], false);
    });
  }

  Future<void> _upsertUpdates(
    Map<String, dynamic> jsonData,
    Synching syncNotifier,
  ) async {
    final updates =
        (jsonData["updates"] as List?)
            ?.map((e) => Update.fromJson(e))
            .toList() ??
        [];
    await isar.writeTxn(() async {
      for (var update in await isar.updates.filter().idIsNotNull().findAll()) {
        final temp = updates.firstWhereOrNull((e) => e.id == update.id);
        if (temp != null) {
          final chapter = await isar.chapters
              .filter()
              .mangaIdEqualTo(temp.mangaId)
              .nameEqualTo(temp.chapterName)
              .findFirst();
          if (chapter != null &&
              (update.updatedAt ?? 0) < (temp.updatedAt ?? 1)) {
            await isar.updates.put(temp..chapter.value = chapter);
            await temp.chapter.save();
          }
          updates.remove(temp);
        } else {
          await isar.updates.delete(update.id!);
        }
      }
      for (var update in updates) {
        final chapter = await isar.chapters
            .filter()
            .mangaIdEqualTo(update.mangaId)
            .nameEqualTo(update.chapterName)
            .findFirst();
        if (chapter != null) {
          await isar.updates.put(update..chapter.value = chapter);
          await update.chapter.save();
        }
      }
      await syncNotifier.clearChangedParts([ActionType.removeUpdate], false);
    });
  }

  Future<void> _upsertSettings(Map<String, dynamic> jsonData) async {
    final oldSettings = isar.settings.getSync(227)!;
    final settings = Settings.fromJson(jsonData["settings"]);
    await isar.writeTxn(() async {
      await isar.settings.put(settings..cookiesList = oldSettings.cookiesList);
      ref.invalidate(followSystemThemeStateProvider);
      ref.invalidate(themeModeStateProvider);
      ref.invalidate(animationDurationScaleProvider);
      ref.invalidate(blendLevelStateProvider);
      ref.invalidate(flexSchemeColorStateProvider);
      ref.invalidate(pureBlackDarkModeStateProvider);
      ref.invalidate(l10nLocaleStateProvider);
      ref.invalidate(extensionsRepoStateProvider(ItemType.manga));
      ref.invalidate(extensionsRepoStateProvider(ItemType.anime));
      ref.invalidate(extensionsRepoStateProvider(ItemType.novel));
    });
  }

  String _getMangaData({bool upload = false, bool download = false}) {
    Map<String, dynamic> data = {};
    data["categories"] = download ? [] : _getCategories();
    data["deleted_categories"] = download
        ? []
        : _getDeletedObjects(ActionType.removeCategory);
    data["manga"] = download ? [] : _getManga();
    data["deleted_manga"] = download
        ? []
        : _getDeletedObjects(ActionType.removeItem);
    data["chapters"] = download ? [] : _getChapters();
    data["deleted_chapters"] = download
        ? []
        : _getDeletedObjects(ActionType.removeChapter);
    data["tracks"] = download ? [] : _getTracks();
    data["deleted_tracks"] = download
        ? []
        : _getDeletedObjects(ActionType.removeTrack);
    if (upload) {
      data["resetAll"] = true;
    }
    return jsonEncode(data);
  }

  String _getHistoryData({bool upload = false, bool download = false}) {
    Map<String, dynamic> data = {};
    data["histories"] = download ? [] : _getHistories();
    data["deleted_histories"] = download
        ? []
        : _getDeletedObjects(ActionType.removeHistory);
    if (upload) {
      data["resetAll"] = true;
    }
    return jsonEncode(data);
  }

  String _getUpdateData({bool upload = false, bool download = false}) {
    Map<String, dynamic> data = {};
    data["updates"] = download ? [] : _getUpdates();
    data["deleted_updates"] = download
        ? []
        : _getDeletedObjects(ActionType.removeUpdate);
    if (upload) {
      data["resetAll"] = true;
    }
    return jsonEncode(data);
  }

  String _getSettingsData({bool download = false}) {
    Map<String, dynamic> data = {};
    if (!download) {
      data["settings"] = isar.settings.getSync(227)!
        ..updatedAt ??= DateTime.now().millisecondsSinceEpoch
        ..cookiesList = [];
    }
    return jsonEncode(data);
  }

  List<int> _getDeletedObjects(ActionType actionType) {
    return ref
        .read(synchingProvider(syncId: syncId).notifier)
        .getChangedParts([actionType])
        .map((e) => e.isarId)
        .nonNulls
        .toList();
  }

  List<Map<String, dynamic>> _getManga() {
    return isar.mangas
        .filter()
        .idIsNotNull()
        .findAllSync()
        .map((e) => (e..customCoverImage = null).toJson())
        .toList();
  }

  List<Map<String, dynamic>> _getCategories() {
    return isar.categorys
        .filter()
        .idIsNotNull()
        .findAllSync()
        .map((e) => e.toJson())
        .toList();
  }

  List<Map<String, dynamic>> _getChapters() {
    return isar.chapters
        .filter()
        .idIsNotNull()
        .findAllSync()
        .map((e) => e.toJson())
        .toList();
  }

  List<Map<String, dynamic>> _getTracks() {
    return isar.tracks
        .filter()
        .idIsNotNull()
        .findAllSync()
        .map((e) => e.toJson())
        .toList();
  }

  List<Map<String, dynamic>> _getHistories() {
    return isar.historys
        .filter()
        .idIsNotNull()
        .findAllSync()
        .map((e) => e.toJson())
        .toList();
  }

  List<Map<String, dynamic>> _getUpdates() {
    return isar.updates
        .filter()
        .idIsNotNull()
        .findAllSync()
        .map((e) => e.toJson())
        .toList();
  }

  String _getAccessToken() {
    final syncPrefs = ref.watch(synchingProvider(syncId: syncId));
    return syncPrefs.authToken ?? "";
  }

  String _getServer() {
    final syncPrefs = ref.watch(synchingProvider(syncId: syncId));
    return syncPrefs.server ?? "";
  }
}
