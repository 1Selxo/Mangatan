import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/sync/chimahon_preference_three_way_merger.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';

void main() {
  const merger = ChimahonPreferenceThreeWayMerger();
  const codec = ChimahonPreferenceCodec();

  String valueOf(BackupPreference preference) =>
      codec.decode(preference).value as String;

  test('first sync preserves remote order and sorts only local additions', () {
    final result = merger.merge(
      baseline: const [],
      local: [
        codec.encode('z_shared', 'local'),
        codec.encode('z_local', 'local only'),
        codec.encode('a_local', 'local only'),
      ],
      remote: [
        codec.encode('z_shared', 'remote'),
        codec.encode('m_remote', 'remote only'),
      ],
    );

    expect(result.map((preference) => preference.key), [
      'z_shared',
      'm_remote',
      'a_local',
      'z_local',
    ]);
    expect(valueOf(result.first), 'remote');
  });

  test('keeps a local-only change when remote matches baseline', () {
    final baseline = codec.encode('setting', 'baseline');
    final result = merger.merge(
      baseline: [baseline],
      localBaseline: [baseline.deepCopy()],
      local: [codec.encode('setting', 'local change')],
      remote: [baseline.deepCopy()],
    );

    expect(valueOf(result.single), 'local change');
  });

  test('local known edit retains raw envelope and value unknown fields', () {
    final baseline = codec.encode('setting', 'baseline')
      ..unknownFields.mergeVarintField(97, Int64(1));
    baseline.value.unknownFields.mergeLengthDelimitedField(98, [4, 5, 6]);
    final result = merger.merge(
      baseline: [baseline],
      localBaseline: [codec.encode('setting', 'baseline')],
      local: [codec.encode('setting', 'local change')],
      remote: [baseline.deepCopy()],
    );

    expect(valueOf(result.single), 'local change');
    expect(result.single.unknownFields.getField(97)!.varints, [Int64(1)]);
    expect(result.single.value.unknownFields.getField(98)!.lengthDelimited, [
      [4, 5, 6],
    ]);
  });

  test('takes a remote-only change when local matches baseline', () {
    final baseline = codec.encode('setting', 'baseline');
    final result = merger.merge(
      baseline: [baseline],
      localBaseline: [baseline.deepCopy()],
      local: [baseline.deepCopy()],
      remote: [codec.encode('setting', 'remote change')],
    );

    expect(valueOf(result.single), 'remote change');
  });

  test('resolves concurrent changes in favor of remote', () {
    final result = merger.merge(
      baseline: [codec.encode('setting', 'baseline')],
      localBaseline: [codec.encode('setting', 'baseline')],
      local: [codec.encode('setting', 'local change')],
      remote: [codec.encode('setting', 'remote change')],
    );

    expect(valueOf(result.single), 'remote change');
  });

  test('preserves an unchanged opaque remote value as a deep copy', () {
    final baseline = codec.encode('opaque', 'Chimahon only')
      ..unknownFields.mergeLengthDelimitedField(91, [1, 2, 3]);
    final result = merger.merge(
      baseline: [baseline],
      local: const [],
      remote: [baseline.deepCopy()],
    );

    expect(result.single.writeToBuffer(), baseline.writeToBuffer());
    expect(identical(result.single, baseline), isFalse);
    result.single.value.value[0] ^= 0xff;
    expect(result.single.value.value, isNot(baseline.value.value));
  });

  test('does not resurrect a locally deleted supported preference', () {
    final baseline = codec.encode('setting', 'baseline');
    final result = merger.merge(
      baseline: [baseline],
      localBaseline: [baseline.deepCopy()],
      local: const [],
      remote: [baseline.deepCopy()],
    );

    expect(result, isEmpty);
  });

  test(
    'an unrepresentable local value preserves the raw remote preference',
    () {
      final baseline = codec.encode('setting', 'last portable value')
        ..unknownFields.mergeVarintField(97, Int64(4));
      final result = merger.merge(
        baseline: [baseline],
        localBaseline: [codec.encode('setting', 'last portable value')],
        local: const [],
        remote: [baseline.deepCopy()],
        locallyUnrepresentableKeys: const {'setting'},
      );

      expect(result.single.writeToBuffer(), baseline.writeToBuffer());
    },
  );

  test('an unrepresentable local value still honors a remote deletion', () {
    final baseline = codec.encode('setting', 'last portable value');
    final result = merger.merge(
      baseline: [baseline],
      localBaseline: [baseline.deepCopy()],
      local: const [],
      remote: const [],
      locallyUnrepresentableKeys: const {'setting'},
    );

    expect(result, isEmpty);
  });

  test('download baseline makes a later representable value a local edit', () {
    final raw = codec.encode('setting', 'remote A');
    final downloadedLocalBaseline = merger.baselineForProjection(
      local: const [],
      raw: [raw],
      locallyUnrepresentableKeys: const {'setting'},
    );

    final result = merger.merge(
      baseline: [raw],
      localBaseline: downloadedLocalBaseline,
      local: [codec.encode('setting', 'local B')],
      remote: [raw.deepCopy()],
    );

    expect(valueOf(result.single), 'local B');
  });

  test('does not resurrect a remotely deleted preference', () {
    final baseline = codec.encode('setting', 'baseline');
    final result = merger.merge(
      baseline: [baseline],
      localBaseline: [baseline.deepCopy()],
      local: [baseline.deepCopy()],
      remote: const [],
    );

    expect(result, isEmpty);
  });

  test('keeps a remote deletion on the following merge cycle', () {
    final oldProjection = codec.encode('setting', 'old value');
    final result = merger.merge(
      baseline: const [],
      localBaseline: [oldProjection],
      local: [oldProjection.deepCopy()],
      remote: const [],
    );

    expect(result, isEmpty);
  });

  test('does not mistake a lossy local projection for a user edit', () {
    final rawBaseline = codec.encode('paired_setting', 'remote-only-shape');
    final projectedBaseline = codec.encode('paired_setting', 'local-default');
    final result = merger.merge(
      baseline: [rawBaseline],
      localBaseline: [projectedBaseline],
      local: [projectedBaseline.deepCopy()],
      remote: [rawBaseline.deepCopy()],
    );

    expect(valueOf(result.single), 'remote-only-shape');
  });

  test('compares and losslessly overlays complete protobuf unknown fields', () {
    final baseline = codec.encode('setting', 'same known value')
      ..unknownFields.mergeVarintField(99, Int64(1));
    final local = codec.encode('setting', 'same known value')
      ..unknownFields.mergeVarintField(99, Int64(2));
    final result = merger.merge(
      baseline: [baseline],
      localBaseline: [baseline.deepCopy()],
      local: [local],
      remote: [baseline.deepCopy()],
    );

    expect(result.single.unknownFields.getField(99)!.varints, [
      Int64(1),
      Int64(2),
    ]);
  });
}
