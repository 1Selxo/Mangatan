import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/services/fetch_item_sources.dart';

void main() {
  group('extensionInstallIsComplete', () {
    test('accepts a persisted installed extension', () {
      final source = Source(isAdded: true, sourceCode: 'apk-base64');

      expect(extensionInstallIsComplete(source), isTrue);
    });

    test('rejects catalog-only and empty installs', () {
      expect(extensionInstallIsComplete(null), isFalse);
      expect(extensionInstallIsComplete(Source()), isFalse);
      expect(
        extensionInstallIsComplete(Source(isAdded: true, sourceCode: '')),
        isFalse,
      );
    });
  });
}
