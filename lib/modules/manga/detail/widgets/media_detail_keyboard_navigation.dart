import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Adds desktop keyboard navigation to a media detail page.
class MediaDetailKeyboardNavigation extends StatelessWidget {
  const MediaDetailKeyboardNavigation({
    super.key,
    required this.onEscape,
    required this.child,
  });

  final VoidCallback onEscape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onEscape},
      child: Focus(autofocus: true, child: child),
    );
  }
}
