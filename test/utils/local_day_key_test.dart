import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/utils/date.dart';

/// The history and updates lists group thousands of entries by local day.
/// The key is now worked out with one time-zone lookup per quarter hour
/// instead of several per entry; it must stay what it was.
void main() {
  String expected(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime(t.year, t.month, t.day).toString();
  }

  test('matches the local day for random moments over decades', () {
    final random = Random(7);
    for (var i = 0; i < 20000; i++) {
      // Any moment from 1970 to about 2039, to the millisecond.
      final ms = random.nextInt(1 << 31) * 1024 + random.nextInt(1024);
      expect(localDayKey(ms), expected(ms), reason: '$ms');
    }
  });

  test('matches around midnight and daylight-saving changes', () {
    for (final year in [2023, 2024, 2025, 2026]) {
      for (final month in [3, 10, 11]) {
        for (var day = 1; day <= 31; day++) {
          final start = DateTime(year, month, day).millisecondsSinceEpoch;
          for (var minutes = -90; minutes <= 90; minutes += 7) {
            final ms = start + minutes * 60000;
            expect(localDayKey(ms), expected(ms), reason: '$ms');
          }
        }
      }
    }
  });
}
