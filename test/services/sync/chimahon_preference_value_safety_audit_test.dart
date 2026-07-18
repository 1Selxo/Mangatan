import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/sync/chimahon_preference_safety_policy.dart';
import 'package:mangayomi/services/sync/chimahon_preference_three_way_merger.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';
import 'package:mangayomi/services/sync/chimahon_source_preference_three_way_merger.dart';
import 'package:mangayomi/services/sync/chimahon_sync_safety_audit.dart';

void main() {
  const codec = ChimahonPreferenceCodec();
  const audit = ChimahonSyncSafetyAudit();

  BackupSourcePreferences sourcePreference(String value) =>
      BackupSourcePreferences(
        sourceKey: 'source',
        prefs: [codec.encode('setting', value)],
      );

  Set<String> failureCodes(ChimahonSyncSafetyReport report) =>
      report.hardFailures.map((finding) => finding.code).toSet();

  test('same-key bootstrap value corruption is a hard failure', () {
    final remote = BackupMihon(
      backupPreferences: [codec.encode('app-setting', 'remote')],
      backupSourcePreferences: [sourcePreference('remote')],
    );
    final proposed = BackupMihon(
      backupPreferences: [codec.encode('app-setting', 'corrupt')],
      backupSourcePreferences: [sourcePreference('corrupt')],
    );

    final report = audit.audit(
      remote: remote,
      local: BackupMihon(),
      proposed: proposed,
      preferenceSafetyPolicy: ChimahonPreferenceSafetyPolicy(
        appSelections: const {
          'app-setting': ChimahonPreferenceSelectionOrigin.remote,
        },
        sourceSelections: const {
          (sourceKey: 'source', preferenceKey: 'setting'):
              ChimahonPreferenceSelectionOrigin.remote,
        },
      ),
    );

    expect(failureCodes(report), {
      'remote_preference_value_not_preserved',
      'remote_source_preference_value_not_preserved',
    });
  });

  test('bootstrap unknown preference envelope loss is a hard failure', () {
    BackupPreference withFutureEnvelope(String key) {
      final preference = codec.encode(key, 'remote');
      preference.unknownFields.mergeVarintField(5000, Int64(7));
      preference.value.unknownFields.mergeVarintField(5001, Int64(8));
      return preference;
    }

    final remoteApp = withFutureEnvelope('app-setting');
    final remoteSource = withFutureEnvelope('setting');
    final proposedApp = remoteApp.deepCopy()..unknownFields.clear();
    proposedApp.value.unknownFields.clear();
    final proposedSource = remoteSource.deepCopy()..unknownFields.clear();
    proposedSource.value.unknownFields.clear();
    final remote = BackupMihon(
      backupPreferences: [remoteApp],
      backupSourcePreferences: [
        BackupSourcePreferences(sourceKey: 'source', prefs: [remoteSource]),
      ],
    );
    final proposed = BackupMihon(
      backupPreferences: [proposedApp],
      backupSourcePreferences: [
        BackupSourcePreferences(sourceKey: 'source', prefs: [proposedSource]),
      ],
    );

    final report = audit.audit(
      remote: remote,
      local: BackupMihon(),
      proposed: proposed,
      preferenceSafetyPolicy: ChimahonPreferenceSafetyPolicy(
        appSelections: const {
          'app-setting': ChimahonPreferenceSelectionOrigin.remote,
        },
        sourceSelections: const {
          (sourceKey: 'source', preferenceKey: 'setting'):
              ChimahonPreferenceSelectionOrigin.remote,
        },
      ),
    );

    expect(failureCodes(report), {
      'remote_preference_unknown_envelope_not_preserved',
      'remote_source_preference_unknown_envelope_not_preserved',
    });
  });

  test('a legitimate later local edit is audited as local intent', () {
    final baselineApp = codec.encode('app-setting', 'baseline');
    final editedApp = codec.encode('app-setting', 'local edit');
    final appResult = const ChimahonPreferenceThreeWayMerger()
        .mergeWithSafetyPolicy(
          baseline: [baselineApp],
          localBaseline: [baselineApp],
          local: [editedApp],
          remote: [baselineApp],
        );

    final baselineSource = sourcePreference('baseline');
    final editedSource = sourcePreference('local edit');
    final sourceResult = const ChimahonSourcePreferenceThreeWayMerger()
        .mergeWithSafetyPolicy(
          baseline: [baselineSource],
          localBaseline: [baselineSource],
          local: [editedSource],
          remote: [baselineSource],
        );
    final policy = ChimahonPreferenceSafetyPolicy(
      appSelections: appResult.selections,
      sourceSelections: sourceResult.selections,
      sourceGroupEnvelopeSelections: sourceResult.sourceGroupEnvelopeSelections,
    );
    final remote = BackupMihon(
      backupPreferences: [baselineApp],
      backupSourcePreferences: [baselineSource],
    );
    final proposed = BackupMihon(
      backupPreferences: appResult.preferences,
      backupSourcePreferences: sourceResult.preferences,
    );

    expect(policy.remoteAuthoritativeAppKeys, isEmpty);
    expect(policy.remoteAuthoritativeSourceKeys, isEmpty);
    expect(policy.localAuthoritativeAppKeys, {'app-setting'});
    expect(policy.localAuthoritativeSourceKeys, const {
      (sourceKey: 'source', preferenceKey: 'setting'),
    });
    expect(
      audit
          .audit(
            remote: remote,
            local: BackupMihon(
              backupPreferences: [editedApp],
              backupSourcePreferences: [editedSource],
            ),
            proposed: proposed,
            preferenceSafetyPolicy: policy,
          )
          .hardFailures,
      isEmpty,
    );
  });

  test('same-key local selection corruption is a hard failure', () {
    final baselineApp = codec.encode('app-setting', 'baseline');
    final editedApp = codec.encode('app-setting', 'local edit');
    final appResult = const ChimahonPreferenceThreeWayMerger()
        .mergeWithSafetyPolicy(
          baseline: [baselineApp],
          localBaseline: [baselineApp],
          local: [editedApp],
          remote: [baselineApp],
        );
    final baselineSource = sourcePreference('baseline');
    final editedSource = sourcePreference('local edit');
    final sourceResult = const ChimahonSourcePreferenceThreeWayMerger()
        .mergeWithSafetyPolicy(
          baseline: [baselineSource],
          localBaseline: [baselineSource],
          local: [editedSource],
          remote: [baselineSource],
        );

    final report = audit.audit(
      remote: BackupMihon(
        backupPreferences: [baselineApp],
        backupSourcePreferences: [baselineSource],
      ),
      local: BackupMihon(
        backupPreferences: [editedApp],
        backupSourcePreferences: [editedSource],
      ),
      proposed: BackupMihon(
        backupPreferences: [codec.encode('app-setting', 'corrupt')],
        backupSourcePreferences: [sourcePreference('corrupt')],
      ),
      preferenceSafetyPolicy: ChimahonPreferenceSafetyPolicy(
        appSelections: appResult.selections,
        sourceSelections: sourceResult.selections,
      ),
    );

    expect(failureCodes(report), {
      'local_preference_value_not_preserved',
      'local_source_preference_value_not_preserved',
    });
  });

  test('an intentional local preference deletion passes the safety gate', () {
    final baseline = codec.encode('nullable-setting', 'old value');
    final result = const ChimahonPreferenceThreeWayMerger()
        .mergeWithSafetyPolicy(
          baseline: [baseline],
          localBaseline: [baseline.deepCopy()],
          local: const [],
          remote: [baseline.deepCopy()],
        );
    final policy = ChimahonPreferenceSafetyPolicy(
      appSelections: result.selections,
    );

    expect(
      result.selections['nullable-setting'],
      ChimahonPreferenceSelectionOrigin.deleted,
    );
    expect(
      audit
          .audit(
            remote: BackupMihon(backupPreferences: [baseline]),
            local: BackupMihon(),
            proposed: BackupMihon(backupPreferences: result.preferences),
            preferenceSafetyPolicy: policy,
          )
          .hardFailures,
      isEmpty,
    );
  });

  test('source-group future envelope loss is a hard failure', () {
    final remoteGroup = BackupSourcePreferences(sourceKey: 'source')
      ..unknownFields.mergeVarintField(9000, Int64(42));
    final result = const ChimahonSourcePreferenceThreeWayMerger()
        .mergeWithSafetyPolicy(
          baseline: [remoteGroup.deepCopy()],
          local: [BackupSourcePreferences(sourceKey: 'source')],
          remote: [remoteGroup],
        );
    final policy = ChimahonPreferenceSafetyPolicy(
      sourceSelections: result.selections,
      sourceGroupEnvelopeSelections: result.sourceGroupEnvelopeSelections,
    );
    final remote = BackupMihon(backupSourcePreferences: [remoteGroup]);
    final local = BackupMihon(
      backupSourcePreferences: [BackupSourcePreferences(sourceKey: 'source')],
    );

    expect(result.preferences, hasLength(1));
    expect(
      audit
          .audit(
            remote: remote,
            local: local,
            proposed: BackupMihon(backupSourcePreferences: result.preferences),
            preferenceSafetyPolicy: policy,
          )
          .hardFailures,
      isEmpty,
    );

    final corrupt = result.preferences.single.deepCopy()..unknownFields.clear();
    expect(
      failureCodes(
        audit.audit(
          remote: remote,
          local: local,
          proposed: BackupMihon(backupSourcePreferences: [corrupt]),
          preferenceSafetyPolicy: policy,
        ),
      ),
      contains('source_preference_group_unknown_envelope_not_preserved'),
    );
  });

  test('preference provenance is immutable and contains no values', () {
    final selections = <String, ChimahonPreferenceSelectionOrigin>{
      'setting': ChimahonPreferenceSelectionOrigin.local,
    };
    final policy = ChimahonPreferenceSafetyPolicy(appSelections: selections);
    selections['setting'] = ChimahonPreferenceSelectionOrigin.remote;

    expect(
      policy.appSelections['setting'],
      ChimahonPreferenceSelectionOrigin.local,
    );
    expect(
      () => policy.appSelections['other'] =
          ChimahonPreferenceSelectionOrigin.remote,
      throwsUnsupportedError,
    );
  });
}
