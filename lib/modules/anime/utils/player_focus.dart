import 'package:flutter/widgets.dart';

/// Keeps keyboard events inside the player when a focused control is removed.
///
/// The focus is only moved when [playerFocusNode] or one of its descendants
/// already owns it, so closing unrelated UI does not steal focus.
void restorePlayerFocusBeforeUnmount(FocusNode playerFocusNode) {
  if (playerFocusNode.hasFocus) {
    playerFocusNode.requestFocus();
  }
}
