import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/hoshidicts/dictionary_names.dart';

void main() {
  test('identity ignores dated revision brackets only', () {
    expect(
      dictionaryIdentityKey('JMdict [2026-11-06]'),
      dictionaryIdentityKey('JMdict'),
    );
    expect(
      dictionaryIdentityKey('ZH Wikipedia [2022-12-01] (注音)'),
      dictionaryIdentityKey('ZH Wikipedia (注音)'),
    );
    expect(
      dictionaryIdentityKey('CC-CEDICT [2024-03-30] (Zhuyin)'),
      isNot(dictionaryIdentityKey('CC-CEDICT [2026-04-18]')),
    );
    expect(
      dictionaryIdentityKey('Tags [kanji]'),
      isNot(dictionaryIdentityKey('Tags')),
    );
  });

  group('resolveEnabledDictionaryNames', () {
    const installed = ['JMdict [2026-11-06]', 'Kroll', 'Nom Han'];

    test('empty and stale sets enable everything', () {
      expect(resolveEnabledDictionaryNames(const {}, installed), installed);
      expect(
        resolveEnabledDictionaryNames(const {'BLCUmixed'}, installed),
        installed,
      );
    });

    test('matches exact names and other revisions', () {
      expect(
        resolveEnabledDictionaryNames(const {
          'Kroll',
          'JMdict [2026-11-20]',
        }, installed),
        {'Kroll', 'JMdict [2026-11-06]'},
      );
    });

    test('a stale revision does not re-enable a revision left off', () {
      expect(
        resolveEnabledDictionaryNames(
          const {'JMdict', 'JMdict [2026-11-06]'},
          const ['JMdict [2026-11-06]', 'JMdict [2026-11-20]'],
        ),
        {'JMdict [2026-11-06]'},
      );
    });
  });

  test('aligns order to local revision names and keeps foreign names', () {
    expect(
      alignDictionaryOrder(
        const ['BLCUmixed', 'JMdict [2026-11-20]', 'Kroll'],
        const ['Kroll', 'JMdict [2026-11-06]'],
      ),
      ['BLCUmixed', 'JMdict [2026-11-06]', 'Kroll'],
    );
  });

  group('mergeSyncedEnabledDictionaryNames', () {
    const installed = ['JMdict [2026-11-06]', 'Kroll', 'Local only'];

    test('remote decides shared dictionaries, local keeps the rest', () {
      final merged = mergeSyncedEnabledDictionaryNames(
        remoteEnabled: const {'JMdict [2026-11-20]', 'Remote only'},
        remoteKnown: const ['JMdict [2026-11-20]', 'Kroll', 'Remote only'],
        localEnabled: const {'Kroll'},
        installed: installed,
      );

      expect(merged, {'JMdict [2026-11-06]', 'Remote only'});
    });

    test('disjoint remote names leave every local dictionary on', () {
      final merged = mergeSyncedEnabledDictionaryNames(
        remoteEnabled: const {'BLCUmixed', 'Wenlin ABC'},
        remoteKnown: const ['BLCUmixed', 'Wenlin ABC'],
        localEnabled: const {},
        installed: installed,
      );

      expect(resolveEnabledDictionaryNames(merged, installed), installed);
      expect(merged, containsAll(['BLCUmixed', 'Wenlin ABC']));
    });

    test('an all-on remote does not enable unknown local dictionaries', () {
      final merged = mergeSyncedEnabledDictionaryNames(
        remoteEnabled: const {},
        remoteKnown: const ['Kroll'],
        localEnabled: const {'Kroll', 'JMdict [2026-11-06]'},
        installed: installed,
      );

      expect(merged, {'Kroll', 'JMdict [2026-11-06]'});
    });

    test('collapses to all-on and keeps remote names without dictionaries', () {
      expect(
        mergeSyncedEnabledDictionaryNames(
          remoteEnabled: const {'Kroll'},
          remoteKnown: const ['Kroll'],
          localEnabled: null,
          installed: const ['Kroll', 'Other'],
        ),
        isEmpty,
      );
      expect(
        mergeSyncedEnabledDictionaryNames(
          remoteEnabled: const {'Kroll'},
          remoteKnown: const ['Kroll'],
          localEnabled: null,
          installed: const [],
        ),
        {'Kroll'},
      );
    });
  });
}
