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
  });
}
