import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/animation_duration_scale_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/blend_level_state_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/flex_scheme_color_state_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/floating_navigation_bar_state_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/pure_black_dark_mode_state_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/theme_mode_state_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/tint_surfaces_state_provider.dart';
import 'package:mangayomi/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:mangayomi/providers/reader_state_provider.dart';
import 'package:mangayomi/providers/show_updates_badge_state_provider.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/router/router.dart';

/// Invalidates UI and cache state across the app after a database restoration.
void invalidateCommonRestoreState(Ref ref) {
  // Sync markers are durable local intent. In particular, tracker deletion
  // tombstones are cleared by SyncServer only after a successful upload.
  // A restore/import must not clear unrelated or concurrently-created rows.
  ref.invalidate(followSystemThemeStateProvider);
  ref.invalidate(themeModeStateProvider);
  ref.invalidate(animationDurationScaleProvider);
  ref.invalidate(blendLevelStateProvider);
  ref.invalidate(flexSchemeColorStateProvider);
  ref.invalidate(pureBlackDarkModeStateProvider);
  ref.invalidate(tintSurfacesStateProvider);
  ref.invalidate(floatingNavigationBarStateProvider);
  ref.invalidate(showUpdatesBadgeStateProvider);
  ref.invalidate(l10nLocaleStateProvider);
  ref.invalidate(navigationOrderStateProvider);
  ref.invalidate(hideItemsStateProvider);
  ref.invalidate(extensionsRepoStateProvider(ItemType.manga));
  ref.invalidate(extensionsRepoStateProvider(ItemType.anime));
  ref.invalidate(extensionsRepoStateProvider(ItemType.novel));
  ref.read(routerCurrentLocationStateProvider.notifier).refresh();
}
