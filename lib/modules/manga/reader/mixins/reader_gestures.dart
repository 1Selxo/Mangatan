import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Handler for keyboard shortcuts in the reader.
class ReaderKeyboardHandler {
  final VoidCallback? onEscape;
  final VoidCallback? onFullScreen;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final VoidCallback? onNextChapter;
  final VoidCallback? onPreviousChapter;
  final bool Function(KeyEvent event)? onLookupTrigger;
  final bool pageKeysNavigatePages;
  final bool delegateHorizontalPageKeysToChild;

  const ReaderKeyboardHandler({
    this.onEscape,
    this.onFullScreen,
    this.onPreviousPage,
    this.onNextPage,
    this.onNextChapter,
    this.onPreviousChapter,
    this.onLookupTrigger,
    this.pageKeysNavigatePages = false,
    this.delegateHorizontalPageKeysToChild = false,
  });

  /// Handles a key event and returns true if it was handled.
  bool handleKeyEvent(KeyEvent event, {bool isReverseHorizontal = false}) {
    if (onLookupTrigger?.call(event) ?? false) return true;
    if (event is! KeyDownEvent) return false;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.f11:
        onFullScreen?.call();
        return true;

      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.backspace:
        onEscape?.call();
        return true;

      case LogicalKeyboardKey.arrowUp:
        onPreviousPage?.call();
        return true;

      case LogicalKeyboardKey.arrowDown:
        onNextPage?.call();
        return true;

      case LogicalKeyboardKey.arrowLeft:
        if (delegateHorizontalPageKeysToChild) return false;
        if (isReverseHorizontal) {
          onNextPage?.call();
        } else {
          onPreviousPage?.call();
        }
        return true;

      case LogicalKeyboardKey.arrowRight:
        if (delegateHorizontalPageKeysToChild) return false;
        if (isReverseHorizontal) {
          onPreviousPage?.call();
        } else {
          onNextPage?.call();
        }
        return true;

      case LogicalKeyboardKey.pageDown:
        if (delegateHorizontalPageKeysToChild) return false;
        if (pageKeysNavigatePages && onNextPage != null) {
          onNextPage?.call();
        } else {
          onNextChapter?.call();
        }
        return true;

      case LogicalKeyboardKey.pageUp:
        if (delegateHorizontalPageKeysToChild) return false;
        if (pageKeysNavigatePages && onPreviousPage != null) {
          onPreviousPage?.call();
        } else {
          onPreviousChapter?.call();
        }
        return true;

      case LogicalKeyboardKey.keyN:
        onNextChapter?.call();
        return true;

      case LogicalKeyboardKey.keyP:
        onPreviousChapter?.call();
        return true;

      default:
        return false;
    }
  }

  /// Creates a focusable widget with this handler.
  Widget wrapWithKeyboardListener({
    required Widget child,
    bool isReverseHorizontal = false,
    FocusNode? focusNode,
  }) {
    return Focus(
      autofocus: true,
      focusNode: focusNode,
      onKeyEvent: (_, event) =>
          handleKeyEvent(event, isReverseHorizontal: isReverseHorizontal)
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
      child: child,
    );
  }
}
