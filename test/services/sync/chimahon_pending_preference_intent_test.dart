import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/sync/chimahon_pending_preference_intent.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';

void main() {
  const intent = ChimahonPendingPreferenceIntent();
  const codec = ChimahonPreferenceCodec();

  test('keeps exact pending value when imported projection is unchanged', () {
    final pending = codec.encode('key', 'future-value')
      ..unknownFields.mergeVarintField(900, Int64(7));
    final projected = codec.encode('key', 'fallback');

    final result = intent.mergeApp(
      pending: [pending],
      projectedBaseline: [projected],
      current: [projected.deepCopy()],
    );

    expect(result.single.writeToBuffer(), pending.writeToBuffer());
  });

  test('later local edit wins and retains pending unknown fields', () {
    final pending = codec.encode('key', 'restored')
      ..unknownFields.mergeVarintField(900, Int64(7));
    pending.value.unknownFields.mergeVarintField(901, Int64(8));
    final baseline = codec.encode('key', 'restored');
    final edited = codec.encode('key', 'edited');

    final result = intent
        .mergeApp(
          pending: [pending],
          projectedBaseline: [baseline],
          current: [edited],
        )
        .single;

    expect(codec.decode(result).value, 'edited');
    expect(result.unknownFields.hasField(900), isTrue);
    expect(result.value.unknownFields.hasField(901), isTrue);
  });

  test('later local deletion removes a pending representable key', () {
    final pending = codec.encode('key', true);
    final result = intent.mergeApp(
      pending: [pending],
      projectedBaseline: [pending.deepCopy()],
      current: const [],
    );

    expect(result, isEmpty);
  });

  test('legacy pending store without baseline fails toward preservation', () {
    final pending = codec.encode('key', 'selected');
    final current = codec.encode('key', 'constructor-default');

    final result = intent.mergeApp(pending: [pending], current: [current]);

    expect(result.single.writeToBuffer(), pending.writeToBuffer());
  });

  test('missing per-key baseline does not invent a later local edit', () {
    final pending = codec.encode('newly-supported', 'selected wire value');
    final current = codec.encode('newly-supported', 'new constructor default');

    final result = intent.mergeApp(
      pending: [pending],
      projectedBaseline: const [],
      current: [current],
    );

    expect(result.single.writeToBuffer(), pending.writeToBuffer());
  });

  test('source groups keep pending-only keys and unknown-only envelopes', () {
    final pendingGroup = BackupSourcePreferences(
      sourceKey: '42',
      prefs: [codec.encode('opaque', 'selected')],
    )..unknownFields.mergeVarintField(902, Int64(9));

    final result = intent.mergeSource(
      pending: [pendingGroup],
      projectedBaseline: const [],
      current: const [],
    );

    expect(result.single.prefs.single.key, 'opaque');
    expect(result.single.unknownFields.hasField(902), isTrue);
  });

  test('source preference disappearance is a projection gap, not deletion', () {
    final pending = codec.encode('extension-key', 'selected');
    final baseline = codec.encode('extension-key', 'selected');

    final result = intent.mergeSource(
      pending: [
        BackupSourcePreferences(sourceKey: '42', prefs: [pending]),
      ],
      projectedBaseline: [
        BackupSourcePreferences(sourceKey: '42', prefs: [baseline]),
      ],
      current: const [],
    );

    expect(result.single.prefs.single.writeToBuffer(), pending.writeToBuffer());
  });

  test(
    'newly projected source key cannot overwrite unproven pending intent',
    () {
      final pending = codec.encode('new-extension-key', 'selected');
      final current = codec.encode('new-extension-key', 'descriptor default');

      final result = intent.mergeSource(
        pending: [
          BackupSourcePreferences(sourceKey: '42', prefs: [pending]),
        ],
        projectedBaseline: const [],
        current: [
          BackupSourcePreferences(sourceKey: '42', prefs: [current]),
        ],
      );

      expect(
        result.single.prefs.single.writeToBuffer(),
        pending.writeToBuffer(),
      );
    },
  );
}
