import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Handles desktop back inputs that were not consumed by a child widget.
///
/// Page-specific back scopes remain responsible for special behavior, such as
/// leaving fullscreen before navigating away. Ordinary routes fall back to
/// [onBack] when there is somewhere to return to.
class DesktopBackNavigationHandler extends StatelessWidget {
  const DesktopBackNavigationHandler({
    super.key,
    required this.canGoBack,
    required this.onBack,
    required this.child,
    this.dismissTransientUi,
  });

  final bool Function() canGoBack;
  final VoidCallback onBack;
  final bool Function()? dismissTransientUi;
  final Widget child;

  void _handleDefaultBack() {
    if (canGoBack()) onBack();
  }

  void _invokeBackAction() {
    if (dismissTransientUi?.call() ?? false) return;
    final primaryContext = FocusManager.instance.primaryFocus?.context;
    if (primaryContext == null ||
        !DesktopBackNavigation.invoke(primaryContext)) {
      _handleDefaultBack();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    // Key repeats must not pop through several routes while Escape is held.
    if (event is KeyDownEvent) _invokeBackAction();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return DesktopBackNavigationScope(
      onBack: _handleDefaultBack,
      child: Focus(
        onKeyEvent: _handleKeyEvent,
        child: Listener(
          onPointerDown: (event) {
            if (event.buttons & kBackMouseButton != 0) _invokeBackAction();
          },
          child: child,
        ),
      ),
    );
  }
}

/// The intent shared by the app-level handler and page-specific back actions.
class DesktopBackNavigationIntent extends Intent {
  const DesktopBackNavigationIntent();
}

/// Invokes the nearest back action registered for [context].
abstract final class DesktopBackNavigation {
  static const _intent = DesktopBackNavigationIntent();

  static bool invoke(BuildContext context) {
    final action = Actions.maybeFind<DesktopBackNavigationIntent>(
      context,
      intent: _intent,
    );
    if (action == null) return false;
    Actions.invoke(context, _intent);
    return true;
  }
}

/// Overrides desktop back navigation for a subtree.
///
/// Use this when a page's visible Back button performs work beyond a normal
/// route pop. Escape and the mouse Back button will invoke the same callback.
class DesktopBackNavigationScope extends StatelessWidget {
  const DesktopBackNavigationScope({
    super.key,
    required this.onBack,
    required this.child,
  });

  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        DesktopBackNavigationIntent:
            CallbackAction<DesktopBackNavigationIntent>(
              onInvoke: (_) {
                onBack();
                return null;
              },
            ),
      },
      child: child,
    );
  }
}
