import 'package:isar_community/isar.dart';
part 'sync_preference.g.dart';

enum SyncMode { native, chimahon }

enum ChimahonSyncProvider { syncYomi, googleDrive, webDav }

@collection
@Name("Sync Preference")
class SyncPreference {
  Id? syncId;

  String? email;

  String? authToken;

  int? since;

  String? sessionToken;

  bool googleDriveConnected = false;

  String? chimahonDeviceId;

  String? syncYomiServer;

  String? syncYomiApiToken;

  bool chimahonSyncManga = true;

  bool chimahonSyncAnime = true;

  bool chimahonSyncNovels = true;

  /// Whether the media switches are an explicit local choice or have been
  /// bootstrapped from the current Chimahon account's backed preferences.
  bool chimahonMediaSelectionInitialized = false;

  /// True only when the user directly changed a media switch. Remote
  /// bootstrap values are account-scoped and must not gain local authority on
  /// a different account.
  bool chimahonMediaSelectionUserSelected = false;

  /// SHA-256 token of the provider/account scope that supplied the current
  /// bootstrapped values. Raw account IDs, servers, and tokens are never
  /// persisted here.
  String? chimahonMediaSelectionScopeToken;

  /// Monotonic revision for selector state. It closes value-only ABA races
  /// when a switch changes away and back during network I/O.
  int chimahonMediaSelectionGeneration = 0;

  /// `https://ip:port` of a host on another device, the sync server's URL,
  /// or [thisDeviceHost].
  String? server;

  /// The SHA-256 of the host's certificate when [server] is a host on
  /// another device: the only certificate this device accepts from it.
  String? hostFingerprint;

  /// Every address the host's invite gave, [server] among them: tried in
  /// turn when [server] does not answer, such as a home network address
  /// away from home.
  List<String>? hostAddresses;

  /// Whether this device hosts sync for the others, from app launch on.
  bool hostEnabled = false;

  bool syncOn = false;

  int autoSyncFrequency = 0;

  int? lastSync;

  @enumerated
  SyncMode syncMode = SyncMode.native;

  @enumerated
  ChimahonSyncProvider chimahonSyncProvider = ChimahonSyncProvider.syncYomi;

  SyncPreference({
    this.syncId,
    this.email,
    this.authToken,
    this.since,
    this.sessionToken,
    this.googleDriveConnected = false,
    this.chimahonDeviceId,
    this.syncYomiServer,
    this.syncYomiApiToken,
    this.chimahonSyncManga = true,
    this.chimahonSyncAnime = true,
    this.chimahonSyncNovels = true,
    this.chimahonMediaSelectionInitialized = false,
    this.chimahonMediaSelectionUserSelected = false,
    this.chimahonMediaSelectionScopeToken,
    this.chimahonMediaSelectionGeneration = 0,
    this.server,
    this.hostFingerprint,
    this.hostAddresses,
    this.hostEnabled = false,
    this.syncOn = false,
    this.autoSyncFrequency = 0,
    this.lastSync,
    this.syncMode = SyncMode.native,
    this.chimahonSyncProvider = ChimahonSyncProvider.syncYomi,
  });

  SyncPreference.fromJson(Map<String, dynamic> json) {
    syncId = json['syncId'];
    email = json['email'];
    authToken = json['authToken'];
    since = json['since'];
    sessionToken = json['sessionToken'];
    googleDriveConnected = json['googleDriveConnected'] ?? false;
    chimahonDeviceId = json['chimahonDeviceId'];
    syncYomiServer = json['syncYomiServer'];
    syncYomiApiToken = json['syncYomiApiToken'];
    chimahonSyncManga = json['chimahonSyncManga'] ?? true;
    chimahonSyncAnime = json['chimahonSyncAnime'] ?? true;
    chimahonSyncNovels = json['chimahonSyncNovels'] ?? true;
    chimahonMediaSelectionInitialized =
        json['chimahonMediaSelectionInitialized'] ?? false;
    chimahonMediaSelectionUserSelected =
        json['chimahonMediaSelectionUserSelected'] ?? false;
    chimahonMediaSelectionScopeToken = json['chimahonMediaSelectionScopeToken'];
    chimahonMediaSelectionGeneration =
        json['chimahonMediaSelectionGeneration'] ?? 0;
    server = json['server'];
    hostFingerprint = json['hostFingerprint'];
    hostAddresses = (json['hostAddresses'] as List?)?.cast<String>();
    hostEnabled = json['hostEnabled'] ?? false;
    syncOn = json['syncOn'] ?? false;
    autoSyncFrequency = json['autoSyncFrequency'] ?? 0;
    lastSync = json['lastSync'];
    syncMode = SyncMode.values[json['syncMode'] ?? SyncMode.native.index];
    chimahonSyncProvider =
        ChimahonSyncProvider.values[json['chimahonSyncProvider'] ??
            ChimahonSyncProvider.syncYomi.index];
  }

  Map<String, dynamic> toJson() => {
    'syncId': syncId,
    'email': email,
    'authToken': authToken,
    'since': since,
    'sessionToken': sessionToken,
    'googleDriveConnected': googleDriveConnected,
    'chimahonDeviceId': chimahonDeviceId,
    'syncYomiServer': syncYomiServer,
    'syncYomiApiToken': syncYomiApiToken,
    'chimahonSyncManga': chimahonSyncManga,
    'chimahonSyncAnime': chimahonSyncAnime,
    'chimahonSyncNovels': chimahonSyncNovels,
    'chimahonMediaSelectionInitialized': chimahonMediaSelectionInitialized,
    'chimahonMediaSelectionUserSelected': chimahonMediaSelectionUserSelected,
    'chimahonMediaSelectionScopeToken': chimahonMediaSelectionScopeToken,
    'chimahonMediaSelectionGeneration': chimahonMediaSelectionGeneration,
    'server': server,
    'hostFingerprint': hostFingerprint,
    'hostAddresses': hostAddresses,
    'hostEnabled': hostEnabled,
    'syncOn': syncOn,
    'autoSyncFrequency': autoSyncFrequency,
    'lastSync': lastSync,
    'syncMode': syncMode.index,
    'chimahonSyncProvider': chimahonSyncProvider.index,
  };

  /// [server] when this device syncs with the host it runs itself.
  static const thisDeviceHost = 'mangayomi-sync://this-device';

  /// The addresses to try for the host, the one that last answered first.
  @ignore
  List<String> get peerAddresses => [
    ?server,
    for (final address in hostAddresses ?? const <String>[])
      if (address != server) address,
  ];

  /// Whether this device has something to sync with: the sync server it
  /// logged into, or a host, its own or one it paired with.
  @ignore
  bool get isConnected =>
      (server?.isNotEmpty ?? false) &&
      ((authToken?.isNotEmpty ?? false) ||
          hostFingerprint != null ||
          server == thisDeviceHost);

  /// Migrates the pre-separation SyncYomi fields exactly once. A device ID is
  /// written whenever a user newly selects Chimahon mode, so a Chimahon row
  /// without one can only be a persisted legacy configuration.
  bool migrateLegacySyncYomiCredentials(String newDeviceId) {
    if (syncMode != SyncMode.chimahon ||
        chimahonDeviceId != null ||
        syncYomiServer != null ||
        syncYomiApiToken != null) {
      return false;
    }
    final legacyServer = server?.trim() ?? '';
    final legacyToken = authToken?.trim() ?? '';
    if (legacyServer.isEmpty && legacyToken.isEmpty) return false;
    syncYomiServer = legacyServer.isEmpty ? null : legacyServer;
    syncYomiApiToken = legacyToken.isEmpty ? null : legacyToken;
    server = null;
    authToken = null;
    chimahonDeviceId = newDeviceId;
    return true;
  }
}

/// Mutates the row loaded at write time instead of a notifier's cached value.
///
/// The caller supplies transaction-bound read/write callbacks. Keeping this
/// tiny operation testable prevents post-network timestamp writes from
/// replacing selector edits that landed while the request was in flight.
SyncPreference mutateCurrentSyncPreference({
  required SyncPreference Function() readCurrent,
  required void Function(SyncPreference) mutate,
  required void Function(SyncPreference) writeCurrent,
}) {
  final current = readCurrent();
  mutate(current);
  writeCurrent(current);
  return current;
}
