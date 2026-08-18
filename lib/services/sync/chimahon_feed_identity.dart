import 'dart:convert';

import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupFeed.pb.dart';

/// Chimahon-compatible identity rules for a saved-search feed.
///
/// Chimahon declares `BackupFeed.global` with a Kotlin default of `true`.
/// Consequently an absent protobuf field means `true`, even though Dart's
/// generated scalar getter returns `false` for absence.
abstract final class ChimahonFeedIdentity {
  static bool semanticGlobal(BackupFeed feed) =>
      feed.hasGlobal() ? feed.global : true;

  static String key(BackupFeed feed) => _frame([
    feed.source.toString(),
    semanticGlobal(feed).toString(),
    feed.hasSavedSearch() ? feed.savedSearch.name : '',
  ]);

  static String _frame(Iterable<String> values) =>
      values.map((value) => '${utf8.encode(value).length}:$value').join();
}
