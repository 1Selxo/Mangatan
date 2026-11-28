import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
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
  final relativeTimestamps = ref.read(relativeTimesTampsStateProvider);
  final millisecondsSinceEpoch = stringDate != null
      ? DateTime.parse(stringDate).millisecondsSinceEpoch
      : int.parse(timestamp!);
  // The grouping key of the history and updates lists, made for every entry.
  if (forHistoryValue && (!useRelativeTimesTamps || relativeTimestamps == 0)) {
    return localDayKey(millisecondsSinceEpoch);
  }
  return dateLabel(
    millisecondsSinceEpoch,
    nowMilliseconds: DateTime.now().millisecondsSinceEpoch,
    l10n: l10nLocalizations(context)!,
    pattern: dateFormat.isEmpty
        ? ref.read(dateFormatStateProvider)
        : dateFormat,
    localeTag: currentLocale(context).toLanguageTag(),
    relativeTimestamps: relativeTimestamps,
    useRelativeTimestamps: useRelativeTimesTamps,
    forHistoryValue: forHistoryValue,
    showHourOrMinute: showHOURorMINUTE,
    showInDaysFuture: showInDaysFuture,
  );
}

/// What [dateFormat] shows for [millisecondsSinceEpoch], [nowMilliseconds]
/// being now.
///
/// Days are counted as local day numbers (see [localDayKey]) rather than
/// with local DateTimes: each of those asks the OS for the time zone, a
/// system call on Windows, and a chapter list called this for every row
/// with nine of them each. Counting days also stays exact across a
/// daylight-saving change, where a 23-hour day made "a week ago" read "6
/// days ago".
@visibleForTesting
String dateLabel(
  int millisecondsSinceEpoch, {
  required int nowMilliseconds,
  required AppLocalizations l10n,
  required String pattern,
  required String localeTag,
  required int relativeTimestamps,
  bool useRelativeTimestamps = true,
  bool forHistoryValue = false,
  bool showHourOrMinute = false,
  bool showInDaysFuture = false,
}) {
  final day = _localDay(millisecondsSinceEpoch);
  if (useRelativeTimestamps && relativeTimestamps != 0) {
    final today = _localDay(nowMilliseconds);
    if (day == today) {
      if (showHourOrMinute) {
        final difference = Duration(
          milliseconds: nowMilliseconds - millisecondsSinceEpoch,
        );
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
    }
    if (day == today - 1) return l10n.yesterday;
    // Within the last week, or any day ahead (the calendar's "in n days").
    if (relativeTimestamps == 2 && day > today - 7) {
      final difference = (today - day).abs();
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
  if (forHistoryValue) return localDayKey(millisecondsSinceEpoch);
  // The local calendar date, as UTC so formatting it asks no time zone; the
  // patterns show dates only.
  return _cachedFormatter(
    pattern,
    localeTag,
  ).format(DateTime.fromMillisecondsSinceEpoch(day * _dayMs, isUtc: true));
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

final _zoneOffsets = <int, int>{};
const _dayMs = Duration.millisecondsPerDay;

/// The local time zone's offset at [millisecondsSinceEpoch]. Every zone
/// changes its offset on a quarter hour, so one lookup per quarter hour is
/// exact.
int _zoneOffset(int millisecondsSinceEpoch) {
  const quarterHour = 15 * 60 * 1000;
  return _zoneOffsets.putIfAbsent(
    (millisecondsSinceEpoch / quarterHour).floor(),
    () =>
        DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch)
            .timeZoneOffset
            .inMilliseconds,
  );
}

/// The local calendar day of [millisecondsSinceEpoch], counted from
/// 1970-01-01.
int _localDay(int millisecondsSinceEpoch) =>
    ((millisecondsSinceEpoch + _zoneOffset(millisecondsSinceEpoch)) / _dayMs)
        .floor();

/// The local day of [millisecondsSinceEpoch], as
/// `DateTime(year, month, day).toString()` gives it.
///
/// A local DateTime asks the OS for the time zone when it is made and again
/// for each field read (a system call on Windows), and the history list
/// grouped thousands of entries this way on every build.
String localDayKey(int millisecondsSinceEpoch) {
  final day = DateTime.fromMillisecondsSinceEpoch(
    _localDay(millisecondsSinceEpoch) * _dayMs,
    isUtc: true,
  ).toString();
  return day.substring(0, day.length - 1); // without the UTC "Z"
}
