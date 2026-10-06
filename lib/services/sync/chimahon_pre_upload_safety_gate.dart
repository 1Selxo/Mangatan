import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/sync/chimahon_remote_recovery_store.dart';
import 'package:mangayomi/services/sync/chimahon_preference_safety_policy.dart';
import 'package:mangayomi/services/sync/chimahon_sync_safety_audit.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:mangayomi/services/sync/cross_device_sync_engine.dart';

typedef ChimahonPreUploadAudit = ChimahonSyncSafetyReport Function({
  BackupMihon? reference,
  required BackupMihon remote,
  required BackupMihon local,
  required BackupMihon proposed,
  BackupMihon? localProjection,
  required ChimahonPreferenceSafetyPolicy preferenceSafetyPolicy,
  required Set<ChimahonTrackingDeletionKey> localTrackingDeletions,
  required bool remoteWinsTies,
});

ChimahonSyncSafetyReport _defaultAudit({
  BackupMihon? reference,
  required BackupMihon remote,
  required BackupMihon local,
  required BackupMihon proposed,
  BackupMihon? localProjection,
  required ChimahonPreferenceSafetyPolicy preferenceSafetyPolicy,
  required Set<ChimahonTrackingDeletionKey> localTrackingDeletions,
  required bool remoteWinsTies,
}) => const ChimahonSyncSafetyAudit().audit(
  reference: reference,
  remote: remote,
  local: local,
  proposed: proposed,
  localProjection: localProjection,
  preferenceSafetyPolicy: preferenceSafetyPolicy,
  localTrackingDeletions: localTrackingDeletions,
  remoteWinsTies: remoteWinsTies,
  includeDiagnostics: false,
);

/// Production fail-closed boundary immediately before a Chimahon upload.
///
/// Existing remote bytes are durably preserved first unless the transport
/// proves its conditional upload retains every exact remote blob. The exact
/// routine transition is audited here. For an explicit manual restore the
/// engine additionally proves, against decoded upload bytes, that selected
/// values and promoted clocks survive and unselected data is unchanged. This
/// distinguishes an intentional reset from a destructive routine merge.
/// Remote creation is still audited against an empty remote.
class ChimahonPreUploadSafetyGate {
  const ChimahonPreUploadSafetyGate({
    required this.recoveryStore,
    this.audit = _defaultAudit,
  });

  final ChimahonRemoteRecoveryStore recoveryStore;
  final ChimahonPreUploadAudit audit;

  Future<void> check(CrossDeviceSyncPreview preview) async {
    final snapshot = preview.remoteSnapshot;
    if (snapshot != null && !snapshot.uploadRetainsAllRemoteByteBlobs) {
      try {
        await recoveryStore.preserve(snapshot);
      } on ChimahonRemoteRecoveryException catch (error) {
        throw ChimahonPreUploadSafetyException(code: error.failure.code);
      } catch (_) {
        throw const ChimahonPreUploadSafetyException(
          code: 'recovery_persistence_failed',
        );
      }
    }

    final decodedRemote = preview.decodedRemote;
    if (snapshot != null && decodedRemote == null) {
      throw const ChimahonPreUploadSafetyException(
        code: 'decoded_remote_missing',
      );
    }
    final remote = decodedRemote ?? BackupMihon();

    late final ChimahonSyncSafetyReport report;
    try {
      report = audit(
        reference: null,
        remote: remote,
        local: preview.effectiveLocalIntent,
        proposed: preview.ordinaryMerged ?? preview.proposedMerged,
        localProjection: preview.exportedLocal,
        preferenceSafetyPolicy: preview.preferenceSafetyPolicy,
        localTrackingDeletions: preview.localTrackingDeletions,
        remoteWinsTies: !preview.pendingManualRestorePresent,
      );
    } catch (_) {
      throw const ChimahonPreUploadSafetyException(code: 'safety_audit_failed');
    }
    if (!report.safeToUpload) {
      throw ChimahonPreUploadSafetyException.fromReport(report);
    }
  }
}

/// Safe-to-display refusal containing only fixed finding codes and aggregate
/// affected counts. Raw audit identities and hashes are intentionally omitted.
class ChimahonPreUploadSafetyException implements Exception {
  const ChimahonPreUploadSafetyException({
    required this.code,
    this.failureCounts = const {},
  });

  factory ChimahonPreUploadSafetyException.fromReport(
    ChimahonSyncSafetyReport report,
  ) {
    final counts = <String, int>{
      for (final finding in report.hardFailures)
        finding.code: finding.affectedCount,
    };
    final orderedKeys = counts.keys.toList()..sort();
    return ChimahonPreUploadSafetyException(
      code: 'unsafe_proposed_payload',
      failureCounts: Map.unmodifiable({
        for (final key in orderedKeys) key: counts[key]!,
      }),
    );
  }

  final String code;
  final Map<String, int> failureCounts;

  @override
  String toString() {
    final findings = failureCounts.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(',');
    return findings.isEmpty
        ? 'Chimahon sync upload refused ($code).'
        : 'Chimahon sync upload refused ($code: $findings).';
  }
}
