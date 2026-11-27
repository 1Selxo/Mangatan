import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/updates/providers/updates_last_seen_provider.dart';
import 'package:mangayomi/providers/show_updates_badge_state_provider.dart';
import 'package:mangayomi/modules/browse/browse_screen.dart'
    show navExtensionUpdateCountProvider;
import 'package:mangayomi/repositories/update_repository.dart';
import 'package:mangayomi/providers/reader_state_provider.dart';

class ExtensionBadgeWidget extends ConsumerWidget {
  const ExtensionBadgeWidget({
    super.key,
    required this.icon,
    required this.ref,
  });

  final Widget icon;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(navExtensionUpdateCountProvider).value ?? 0;
    if (count == 0) return icon;
    return Badge(label: Text("$count"), child: icon);
  }
}

/// The chapters found since Updates was last opened, as Mihon counts them.
/// Opening or leaving Updates clears it; reading a chapter takes it off.
class UpdatesBadgeWidget extends ConsumerWidget {
  const UpdatesBadgeWidget({super.key, required this.icon, required this.ref});

  final Widget icon;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showUpdatesBadgeStateProvider)) return icon;
    final hideItems = ref.watch(hideItemsStateProvider);
    final lastSeenAt = ref.watch(updatesLastSeenStateProvider);

    return StreamBuilder(
      stream: updateRepository.watchUnreadExcludingHiddenItemTypes(
        hideManga: hideItems.contains("/MangaLibrary"),
        hideAnime: hideItems.contains("/AnimeLibrary"),
        hideNovel: hideItems.contains("/NovelLibrary"),
      ),
      builder: (context, snapshot) {
        final count = countNewUpdates(snapshot.data ?? const [], lastSeenAt);
        if (count == 0) return icon;

        return Badge(label: Text("$count"), child: icon);
      },
    );
  }
}
