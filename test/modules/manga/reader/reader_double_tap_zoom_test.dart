import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/manga/reader/utils/reader_pointer_signals.dart';

void main() {
  group('readerDoubleTapZoomTarget', () {
    test('zooms to 2x keeping the tapped spot under the pointer', () {
      final target = readerDoubleTapZoomTarget(
        fromScale: 1,
        fromPosition: Offset.zero,
        focalPoint: const Offset(100, -50),
      );
      expect(target.scale, 2);
      // A point 100 px right of centre ends 200 px right at 2x unless the
      // view moves back by 100 px.
      expect(target.position, const Offset(-100, 50));
    });

    test('keeps an earlier pan while zooming in', () {
      final target = readerDoubleTapZoomTarget(
        fromScale: 1,
        fromPosition: const Offset(30, 0),
        focalPoint: Offset.zero,
      );
      expect(target.position, const Offset(60, 0));
    });

    test('returns to the default scale from any other zoom', () {
      for (final scale in [2.0, 1.37, 0.6]) {
        final target = readerDoubleTapZoomTarget(
          fromScale: scale,
          fromPosition: const Offset(80, 40),
          focalPoint: const Offset(10, 10),
        );
        expect(target.scale, readerDefaultZoomScale);
        expect(target.position, Offset.zero);
      }
    });
  });
}
