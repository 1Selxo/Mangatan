import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/http/m_client.dart';

/// Every MClient.httpClient call used to build a new native client and keep
/// it forever: the pool was keyed by ClientSettings, which has no value
/// equality. No request reused another's connection, and memory grew with
/// each one.
void main() {
  test('the same options share one pooled client', () {
    expect(rhttpPoolKey(null), rhttpPoolKey(null));
    expect(
      rhttpPoolKey({'useDartHttpClient': false, 'timeout': 30}),
      rhttpPoolKey({'timeout': 30}),
    );
  });

  test('different options get their own client', () {
    expect(rhttpPoolKey({'timeout': 30}), isNot(rhttpPoolKey({'timeout': 60})));
    expect(rhttpPoolKey({'noProxy': true}), isNot(rhttpPoolKey(null)));
    expect(
      rhttpPoolKey({'verifyCertificates': true}),
      isNot(rhttpPoolKey(null)),
    );
  });

  test(
    'DNS resolvers made anew on each call are told apart by what they use',
    () {
      expect(
        rhttpPoolKey(null, poolKey: ('doh', 1, '')),
        rhttpPoolKey(null, poolKey: ('doh', 1, '')),
      );
      expect(
        rhttpPoolKey(null, poolKey: ('doh', 1, '')),
        isNot(rhttpPoolKey(null, poolKey: ('doh', 2, ''))),
      );
    },
  );
}
