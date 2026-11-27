import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mangayomi/providers/date_format_state_provider.dart';
import 'package:mangayomi/providers/l10n_providers.dart';

/// DateFormat construction parses the pattern each time; cache instances so
/// hot paths (grouped history/updates lists) don't rebuild them per call.
final _dateFormatCache = <String, DateFormat>{};

DateFormat _cachedFormatter(String pattern, String localeTag) =>
    _dateFormatCache.putIfAbsent(
      '$pattern|$localeTag',
      () => DateFormat(pattern, localeTag),
    );

String dateFormat(
  String? timestamp, {
  required WidgetRef ref,
  required BuildContext context,
  String? stringDate,
  bool forHistoryValue = false,
  bool useRelativeTimesTamps = true,
  String dateFormat = "",
  bool showHOURorMINUTE = false,
  bool showInDaysFuture = false,
}) {
  final l10n = l10nLocalizations(context)!;
  final locale = currentLocale(context);
  final relativeTimestamps = ref.read(relativeTimesTampsStateProvider);
  final dateFrmt = ref.read(dateFormatStateProvider);
  final dateTime = stringDate != null
      ? DateTime.parse(stringDate)
      : DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp!));
  stringDate = null;
  final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
  if (stringDate == null) {
    // Only made when a relative date can be shown. Each local DateTime asks
    // the OS for the time zone (on Windows a system call), and the history
    // list calls this once per entry to group them, thousands of times.
    late final now = DateTime.now();
    late final today = DateTime(now.year, now.month, now.day);
    late final yesterday = DateTime(now.year, now.month, now.day - 1);
    late final twoDaysAgo = DateTime(now.year, now.month, now.day - 2);
    late final threeDaysAgo = DateTime(now.year, now.month, now.day - 3);
    late final fourDaysAgo = DateTime(now.year, now.month, now.day - 4);
    late final fiveDaysAgo = DateTime(now.year, now.month, now.day - 5);
    late final sixDaysAgo = DateTime(now.year, now.month, now.day - 6);
    late final aWeekAgo = DateTime(now.year, now.month, now.day - 7);

    if (useRelativeTimesTamps && relativeTimestamps != 0 && date == today) {
      if (showHOURorMINUTE) {
        final difference = now.difference(dateTime);
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
    } else if (useRelativeTimesTamps &&
        relativeTimestamps != 0 &&
        date == yesterday) {
      return l10n.yesterday;
    } else if (useRelativeTimesTamps && relativeTimestamps == 2) {
      if (date.isAfter(twoDaysAgo) ||
          date.isAfter(twoDaysAgo) ||
          date.isAfter(threeDaysAgo) ||
          date.isAfter(fourDaysAgo) ||
          date.isAfter(fiveDaysAgo) ||
          date.isAfter(sixDaysAgo) ||
          date.isAfter(aWeekAgo)) {
        final difference = today.difference(date).inDays.abs();
        return switch (difference) {
          1 =>
            showInDaysFuture
                ? l10n.in_n_day(difference)
                : l10n.n_day_ago(difference),
          != 7 =>
            showInDaysFuture
                ? l10n.in_n_days(difference)
                : l10n.n_days_ago(difference),
          _ => showInDaysFuture ? l10n.next_week : l10n.a_week_ago,
        };
      }
    }
    return forHistoryValue
        ? date.toString()
        : _cachedFormatter(
            dateFormat.isEmpty ? dateFrmt : dateFormat,
            locale.toLanguageTag(),
          ).format(date);
  }
  return date.toString();
}

String dateFormatHour(String timestamp, BuildContext context) {
  final locale = currentLocale(context);
  final dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
  final localeTag = locale.toLanguageTag();

  return _dateFormatCache
      .putIfAbsent('Hm|$localeTag', () => DateFormat.Hm(localeTag))
      .format(dateTime);
}

List<String> dateFormatsList = [
  "M/d/y",
  "MM/dd/yy",
  "dd/MM/yy",
  "yyyy-MM-dd",
  "dd MMM yyyy",
  "MMM dd, yyyy",
];

List<String> relativeTimestampsList(BuildContext context) {
  final l10n = l10nLocalizations(context)!;
  return [
    l10n.off,
    l10n.relative_timestamp_short,
    l10n.relative_timestamp_long,
  ];
}
