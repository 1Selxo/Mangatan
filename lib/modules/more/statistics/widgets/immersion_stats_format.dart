import 'package:mangayomi/modules/more/statistics/immersion_stats_data.dart';

/// Formatting shared by the statistics screens and the in-reader sheets.
///
/// Chimahon's exact output is reproduced, including the two different duration
/// formats it uses: `h:mm:ss` for elapsed reading and `Xh Ym Zs` for estimates.

/// Groups thousands with commas, matching Chimahon's `toCountString`.
String formatCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

/// `h:mm:ss`, dropping the hour component when there is none.
String formatElapsed(Duration duration) {
  final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final seconds = totalSeconds % 60;
  final minutes = (totalSeconds ~/ 60) % 60;
  final hours = totalSeconds ~/ 3600;
  final paddedSeconds = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$paddedSeconds';
  }
  return '${minutes.toString().padLeft(2, '0')}:$paddedSeconds';
}

/// `Xh Ym Zs`, omitting leading zero components. Used for ETAs.
String formatEstimate(double seconds) {
  final totalSeconds = seconds.isFinite && seconds > 0 ? seconds.toInt() : 0;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final remaining = totalSeconds % 60;
  if (hours > 0) return '${hours}h ${minutes}m ${remaining}s';
  if (minutes > 0) return '${minutes}m ${remaining}s';
  return '${remaining}s';
}

/// `Xh Ym per day` for the hero subtitle.
String formatAveragePerDay(int durationMs) {
  final hours = durationMs ~/ 3600000;
  final minutes = (durationMs % 3600000) ~/ 60000;
  return hours > 0 ? '${hours}h ${minutes}m per day' : '${minutes}m per day';
}

/// `Xh Ym` for the compact per-title duration.
String formatShortDuration(int durationMs) {
  final hours = durationMs ~/ 3600000;
  final minutes = (durationMs % 3600000) ~/ 60000;
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
}

String immersionStatsTypeLabel(ImmersionStatsType type) => switch (type) {
  ImmersionStatsType.all => 'All',
  ImmersionStatsType.manga => 'Manga',
  ImmersionStatsType.novels => 'Novels',
};

String immersionStatsScaleLabel(ImmersionStatsDateScale scale) =>
    switch (scale) {
      ImmersionStatsDateScale.day => 'Day',
      ImmersionStatsDateScale.week => 'Week',
      ImmersionStatsDateScale.month => 'Month',
      ImmersionStatsDateScale.year => 'Year',
      ImmersionStatsDateScale.allTime => 'All Time',
    };

/// The heading above the chart: relative wording for the current and previous
/// period, an explicit date otherwise.
String immersionStatsPeriodLabel(
  ImmersionStatsDateScale scale,
  int offset, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  switch (scale) {
    case ImmersionStatsDateScale.day:
      if (offset == 0) return 'Today';
      if (offset == -1) return 'Yesterday';
      final date = immersionStatsDateRange(scale, offset, now: today).start;
      return '${_monthNames[date.month - 1]} ${date.day}';
    case ImmersionStatsDateScale.week:
      if (offset == 0) return 'This week';
      if (offset == -1) return 'Last week';
      final range = immersionStatsDateRange(scale, offset, now: today);
      final start = '${_monthNames[range.start.month - 1]} ${range.start.day}';
      final end = '${_monthNames[range.end.month - 1]} ${range.end.day}';
      return '$start - $end';
    case ImmersionStatsDateScale.month:
      if (offset == 0) return 'This month';
      if (offset == -1) return 'Last month';
      final date = immersionStatsDateRange(scale, offset, now: today).start;
      return '${_fullMonthNames[date.month - 1]} ${date.year}';
    case ImmersionStatsDateScale.year:
      if (offset == 0) return 'This year';
      if (offset == -1) return 'Last year';
      return '${today.year + offset}';
    case ImmersionStatsDateScale.allTime:
      return 'All Time';
  }
}

/// `MMM d, yyyy`, used for a title's last-read date.
String formatStatsDate(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _fullMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
