// Part of the screen sweep: see sweep_support.dart.
import 'harness/journey.dart';
import 'sweep_support.dart';

void main() {
  sweepKnownIssues();
  sweepWindows([
    ('desktop', desktopWindow, false),
    ('desktop dark', desktopWindow, true),
  ]);
}
