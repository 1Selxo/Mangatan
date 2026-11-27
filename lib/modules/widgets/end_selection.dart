import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/library/providers/library_state_provider.dart';
import 'package:mangayomi/modules/manga/detail/providers/state_providers.dart';

/// Ends a library or chapter selection, as its close button does. Returns
/// whether there was one, so desktop Escape (and the mouse Back button)
/// ends a selection before it navigates anywhere.
bool endSelection(WidgetRef ref) {
  if (!ref.read(isLongPressedStateProvider)) return false;
  ref.read(isLongPressedStateProvider.notifier).update(false);
  ref.read(mangasListStateProvider.notifier).clear();
  ref.read(chaptersListStateProvider.notifier).clear();
  return true;
}
