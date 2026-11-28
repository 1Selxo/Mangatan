import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/utils/date.dart';

/// The previous dateFormat, made of local DateTimes, as the reference: the
/// day-number version must say the same thing.
String legacy(
  int ms, {
  required int now,
  required AppLocalizations l10n,
  required String pattern,
  required int relative,
  required bool useRelative,
  required bool hourOrMinute,
  required bool future,
}) {
  final dateTime = DateTime.fromMillisecondsSinceEpoch(ms);
  final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final nowTime = DateTime.fromMillisecondsSinceEpoch(now);
  final today = DateTime(nowTime.year, nowTime.month, nowTime.day);
  final yesterday = DateTime(nowTime.year, nowTime.month, nowTime.day - 1);
  final aWeekAgo = DateTime(nowTime.year, nowTime.month, nowTime.day - 7);
  if (useRelative && relative != 0 && date == today) {
    if (hourOrMinute) {
      final difference = nowTime.difference(dateTime);
      if (difference.inMinutes < 60) {
        return switch (difference.inMinutes) {
          0 => l10n.now,
          1 => l10n.n_minute_ago(difference.inMinutes),
          _ => l10n.n_minutes_ago(difference.inMinutes),
        };
      } else if (difference.inHours < 24) {
        return switch (difference.inHours) {
          1 => l10n.n_hour_ago(difference.inHours),
          _ => l10n.n_hours_ago(difference.inHours),
        };
      }
    }
    return l10n.today;
  } else if (useRelative && relative != 0 && date == yesterday) {
    return l10n.yesterday;
  } else if (useRelative && relative == 2 && date.isAfter(aWeekAgo)) {
    final difference = today.difference(date).inDays.abs();
    return switch (difference) {
      1 => future ? l10n.in_n_day(difference) : l10n.n_day_ago(difference),
      != 7 => future ? l10n.in_n_days(difference) : l10n.n_days_ago(difference),
      _ => future ? l10n.next_week : l10n.a_week_ago,
    };
  }
  return DateFormat(pattern, 'en').format(date);
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final random = Random(11);
  const day = Duration.millisecondsPerDay;

  /// Calendar days between two local dates, ignoring how long they were.
  int calendarDays(DateTime a, DateTime b) => DateTime.utc(
    a.year,
    a.month,
    a.day,
  ).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

  setUpAll(() => initializeDateFormatting('en'));

  test('says what the local-DateTime version said', () {
    var compared = 0;
    for (var i = 0; i < 20000; i++) {
      // Moments around many "nows" across the year, DST changes included.
      final now =
          DateTime(2026, 1, 1).millisecondsSinceEpoch +
          random.nextInt(365) * day +
          random.nextInt(day);
      final ms = now + (random.nextInt(40) - 25) * day + random.nextInt(day);
      for (final relative in [0, 1, 2]) {
        for (final pattern in ['M/d/y', 'dd MMM yyyy']) {
          final options = (
            useRelative: random.nextBool(),
            hourOrMinute: random.nextBool(),
            future: random.nextBool(),
          );
          final expected = legacy(
            ms,
            now: now,
            l10n: l10n,
            pattern: pattern,
            relative: relative,
            useRelative: options.useRelative,
            hourOrMinute: options.hourOrMinute,
            future: options.future,
          );
          final actual = dateLabel(
            ms,
            nowMilliseconds: now,
            l10n: l10n,
            pattern: pattern,
            localeTag: 'en',
            relativeTimestamps: relative,
            useRelativeTimestamps: options.useRelative,
            showHourOrMinute: options.hourOrMinute,
            showInDaysFuture: options.future,
          );
          if (actual == expected) {
            compared++;
            continue;
          }
          // The old count used the length of the span, which a
          // daylight-saving change shortens or stretches by an hour.
          final nowDate = DateTime.fromMillisecondsSinceEpoch(now);
          final date = DateTime.fromMillisecondsSinceEpoch(ms);
          final days = calendarDays(nowDate, date).abs();
          final exact = switch (days) {
            1 => options.future ? l10n.in_n_day(1) : l10n.n_day_ago(1),
            7 => options.future ? l10n.next_week : l10n.a_week_ago,
            _ => options.future ? l10n.in_n_days(days) : l10n.n_days_ago(days),
          };
          expect(
            actual,
            exact,
            reason: 'now $nowDate, date $date, relative $relative',
          );
        }
      }
    }
    expect(compared, greaterThan(100000));
  });
}
