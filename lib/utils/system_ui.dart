import 'package:flutter/services.dart';
import 'package:mangayomi/utils/platform_utils.dart';
import 'package:window_manager/window_manager.dart';

/// Whether a screen may switch the window to fullscreen by itself, as the
/// reader and the player do as they open when their setting asks for it.
///
/// Not under Wayland: with Flutter 3.50 the app can freeze for good as its
/// window goes fullscreen there, the raster thread waiting on the compositor
/// while holding what GTK waits for
/// (https://github.com/flutter/flutter/issues/196529). The user can still
/// switch it themselves. Drop this once a Flutter release has the fix
/// (https://github.com/flutter/flutter/pull/196945).
final bool mayEnterFullScreenOnItsOwn = !isLinuxWayland;

void restoreSystemUI() => SystemChrome.setEnabledSystemUIMode(
  SystemUiMode.manual,
  overlays: SystemUiOverlay.values,
);

bool _restoreMaximizedAfterFullscreen = false;

/// Toggles desktop fullscreen, restoring a maximized window on exit.
Future<bool> setFullScreen({bool? value}) async {
  final current = await windowManager.isFullScreen();
  final target = value ?? !current;
  if (target == current) return current;

  if (target) {
    _restoreMaximizedAfterFullscreen = await windowManager.isMaximized();
    if (_restoreMaximizedAfterFullscreen) {
      await windowManager.unmaximize();
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    await windowManager.setFullScreen(true);
  } else {
    await windowManager.setFullScreen(false);
    if (_restoreMaximizedAfterFullscreen) {
      await windowManager.maximize();
    }
    _restoreMaximizedAfterFullscreen = false;
  }
  return target;
}
