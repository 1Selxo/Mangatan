import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/fetch_sources_list.dart';

void main() {
  group('compareVersions', () {
    test('compares each dotted component as an integer', () {
      expect(compareVersions('1.0.4.1', '1.0.4.10'), lessThan(0));
      expect(compareVersions('1.0.4.10', '1.0.4.1'), greaterThan(0));
    });

    test('does not change the value of single-digit components', () {
      expect(compareVersions('1.9.0', '1.10.0'), lessThan(0));
      expect(compareVersions('2.0.0', '1.99.99'), greaterThan(0));
    });

    test('treats an empty minimum-version sentinel as zero', () {
      expect(compareVersions('1.0.8', ''), greaterThan(0));
      expect(compareVersions('', '0'), 0);
    });

    test('uses component count when shared components are equal', () {
      expect(compareVersions('1.0', '1.0.0'), lessThan(0));
      expect(compareVersions('1.0.0', '1.0.0'), 0);
    });

    test('ignores a non-numeric suffix on a version component', () {
      // Extension repos and server releases can publish pre-release / build
      // tags such as "1.2.0-beta" or "2.0.1727-r1234". These reach
      // compareVersions unsanitised from external source.json (appMinVerReq /
      // version). The numeric prefix must decide the comparison instead of
      // throwing FormatException and breaking source listing/auto-update.
      expect(compareVersions('1.2.0-beta', '1.2.0'), 0);
      expect(compareVersions('2.0.1727-r1234', '2.0.1728'), lessThan(0));
      expect(compareVersions('1.3.0', '1.2.0-beta'), greaterThan(0));
    });

    test('treats a fully non-numeric component as zero', () {
      expect(compareVersions('1.x.0', '1.0.0'), 0);
      expect(compareVersions('1.beta', '1.0'), 0);
    });
  });
}
