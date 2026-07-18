import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/sync/chimahon_preference_safety_policy.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';
import 'package:mangayomi/services/sync/chimahon_source_preference_three_way_merger.dart';

void main() {
  const merger = ChimahonSourcePreferenceThreeWayMerger();
  const codec = ChimahonPreferenceCodec();

  BackupSourcePreferences group(
    String sourceKey,
    Iterable<BackupPreference> preferences,
  ) => BackupSourcePreferences(sourceKey: sourceKey, prefs: preferences);

  String valueOf(BackupPreference preference) =>
      codec.decode(preference).value as String;

  test('first merge prefers remote conflicts and keeps local additions', () {
    final result = merger.merge(
      baseline: const [],
      local: [
        group('source_1', [
          codec.encode('shared', 'local'),
          codec.encode('local_only', 'local'),
        ]),
      ],
      remote: [
        group('source_1', [
          codec.encode('shared', 'remote'),
          codec.encode('remote_only', 'remote'),
        ]),
      ],
    );

    final preferences = {
      for (final preference in result.single.prefs) preference.key: preference,
    };
    expect(valueOf(preferences['shared']!), 'remote');
    expect(valueOf(preferences['local_only']!), 'local');
    expect(valueOf(preferences['remote_only']!), 'remote');
    expect(result.single.prefs.map((preference) => preference.key), [
      'shared',
      'remote_only',
      'local_only',
    ]);
  });

  test(
    'preserves remote group and nested order and sorts local-only tails',
    () {
      final result = merger.merge(
        baseline: const [],
        local: [
          group('source_a', [codec.encode('only', 'remote')]),
          group('source_z', [
            codec.encode('z_shared', 'local'),
            codec.encode('z_local', 'local'),
            codec.encode('a_local', 'local'),
          ]),
          group('source_y', [codec.encode('only', 'local')]),
          group('source_b', [codec.encode('only', 'local')]),
        ],
        remote: [
          group('source_z', [
            codec.encode('z_shared', 'remote'),
            codec.encode('m_remote', 'remote'),
          ]),
          group('source_a', [codec.encode('only', 'remote')]),
        ],
      );

      expect(result.map((source) => source.sourceKey), [
        'source_z',
        'source_a',
        'source_b',
        'source_y',
      ]);
      expect(result.first.prefs.map((preference) => preference.key), [
        'z_shared',
        'm_remote',
        'a_local',
        'z_local',
      ]);
      expect(valueOf(result.first.prefs.first), 'remote');
    },
  );

  test('keeps a local edit when the remote source store is unchanged', () {
    final rawBaseline = group('source_1', [
      codec.encode('setting', 'baseline'),
    ]);
    final localBaseline = group('source_1', [
      codec.encode('setting', 'baseline'),
    ]);

    final result = merger.merge(
      baseline: [rawBaseline],
      localBaseline: [localBaseline],
      local: [
        group('source_1', [codec.encode('setting', 'local edit')]),
      ],
      remote: [rawBaseline.deepCopy()],
    );

    expect(valueOf(result.single.prefs.single), 'local edit');
  });

  test('takes a remote edit or deletion when local is unchanged', () {
    final baseline = group('source_1', [
      codec.encode('edited', 'baseline'),
      codec.encode('deleted', 'baseline'),
    ]);
    final localProjection = baseline.deepCopy();

    final result = merger.merge(
      baseline: [baseline],
      localBaseline: [localProjection.deepCopy()],
      local: [localProjection],
      remote: [
        group('source_1', [codec.encode('edited', 'remote edit')]),
      ],
    );

    expect(result.single.prefs.map((preference) => preference.key), ['edited']);
    expect(valueOf(result.single.prefs.single), 'remote edit');
  });

  test(
    'uninstalled source follows current remote state including deletion',
    () {
      final opaque = group('source_999', [codec.encode('setting', 'opaque')]);

      expect(
        merger.merge(baseline: [opaque], local: const [], remote: const []),
        isEmpty,
      );

      final retained = merger.merge(
        baseline: const [],
        local: const [],
        remote: [opaque],
      );
      expect(retained.single.writeToBuffer(), opaque.writeToBuffer());
      expect(identical(retained.single, opaque), isFalse);
    },
  );

  test('preserves an unknown preference envelope byte-for-byte', () {
    final unknown = BackupPreference(
      key: 'future_value',
      value: BackupPreferenceValue(
        type: 'app.chimahon.backup.FuturePreferenceValue',
        value: [1, 2, 3, 4],
      ),
    )..unknownFields.mergeLengthDelimitedField(97, [5, 6, 7]);
    final remote = group('source_1', [unknown]);
    remote.unknownFields.mergeVarintField(98, Int64(9));

    final result = merger.merge(
      baseline: [remote.deepCopy()],
      local: [
        group('source_1', [codec.encode('known', 'local')]),
      ],
      remote: [remote],
    );

    final retained = result.single.prefs.firstWhere(
      (preference) => preference.key == 'future_value',
    );
    expect(retained.writeToBuffer(), unknown.writeToBuffer());
    expect(result.single.unknownFields.hasField(98), isTrue);
  });

  test('retains a source group containing only future envelope fields', () {
    final remote = BackupSourcePreferences(sourceKey: 'source_1')
      ..unknownFields.mergeVarintField(98, Int64(9));

    final result = merger.mergeWithSafetyPolicy(
      baseline: [remote.deepCopy()],
      local: [BackupSourcePreferences(sourceKey: 'source_1')],
      remote: [remote],
    );

    expect(result.preferences, hasLength(1));
    expect(result.preferences.single.prefs, isEmpty);
    expect(result.preferences.single.unknownFields.hasField(98), isTrue);
    expect(
      result.sourceGroupEnvelopeSelections['source_1'],
      ChimahonPreferenceSelectionOrigin.remote,
    );
  });

  test('a removed extension definition leaves its remote key opaque', () {
    final baseline = group('source_1', [
      codec.encode('still_defined', 'old'),
      codec.encode('removed_definition', 'opaque value'),
    ]);

    final result = merger.merge(
      baseline: [baseline],
      localBaseline: [baseline.deepCopy()],
      local: [
        group('source_1', [codec.encode('still_defined', 'old')]),
      ],
      remote: [baseline.deepCopy()],
    );

    expect(result.single.prefs.map((preference) => preference.key), [
      'still_defined',
      'removed_definition',
    ]);
  });
}
