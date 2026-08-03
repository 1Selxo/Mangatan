import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crop_image/crop_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/mining/widgets/hoshi_dictionary_popup.dart';

/// Paints a solid [width]x[height] bitmap so the crop workflow operates on a
/// real image whose pixel dimensions we can reason about deterministically.
Future<ui.Image> _solidImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF3366CC),
  );
  return recorder.endRecording().toImage(width, height);
}

/// Decodes PNG bytes back into a [ui.Image] so we can assert exported pixel
/// dimensions.
Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Issue #36 ("[Feature request] Scalable screenshot") asked for the ability
  // to screenshot a single manga panel with adjustable dimensions before Anki
  // export, instead of always exporting the whole page. The user-facing
  // workflow is the "Crop Screenshot" dialog in hoshi_dictionary_popup.dart:
  // when AnkiScreenshotMode.crop is selected the dialog wraps
  // MiningContext.imageBytesLoader, the user drags/resizes/rotates the crop
  // rect on a CropController, and pressing "Crop" turns the *chosen sub-rect*
  // into the PNG bytes that land on the Anki card.
  //
  // `cropControllerToPngBytes` is that exact production step (the dialog's
  // handleCrop / _CropActionsRow._handleCrop both call it), and
  // `kAnkiCropDefaultRect` is the sub-rect the dialog seeds and its aspect
  // presets reset to. PR #83 was rejected for asserting generic
  // screenshot-loader behavior instead of this crop mapping; these tests pin
  // the crop-rect -> exported-bytes contract the feature actually depends on.
  group('issue #36 crop workflow: crop-rect -> exported PNG bytes', () {
    testWidgets('exports exactly the manually chosen sub-rect of the panel', (
      tester,
    ) async {
      late ui.Image exported;
      await tester.runAsync(() async {
        // Source panel: a tall manga page 200x300.
        final controller = CropController();
        controller.image = await _solidImage(200, 300);

        // User drags/resizes the crop rect to the middle-left half of the page:
        //   x: 0.25 -> 0.75  (width 0.50)
        //   y: 0.50 -> 1.00  (height 0.50)
        controller.crop = const Rect.fromLTRB(0.25, 0.5, 0.75, 1.0);

        final bytes = await cropControllerToPngBytes(controller);
        expect(bytes, isNotNull);
        exported = await _decode(bytes!);
        controller.dispose();
      });

      // 0.50 * 200 = 100 wide, 0.50 * 300 = 150 tall — the chosen sub-rect,
      // NOT the full 200x300 page.
      expect(exported.width, 100);
      expect(exported.height, 150);
    });

    testWidgets(
      'the default crop window exports a proportionally smaller panel, '
      'not the full page',
      (tester) async {
        late ui.Image exported;
        await tester.runAsync(() async {
          // Seeded with the dialog's real default rect (kAnkiCropDefaultRect,
          // the centered 80% window) and accepted untouched.
          final controller = CropController(
            aspectRatio: null,
            defaultCrop: kAnkiCropDefaultRect,
          );
          controller.image = await _solidImage(400, 200);
          final bytes = await cropControllerToPngBytes(controller);
          expect(bytes, isNotNull);
          exported = await _decode(bytes!);
          controller.dispose();
        });

        // 0.8 * 400 = 320, 0.8 * 200 = 160 — strictly smaller than the source,
        // proving the crop rect (not the full page) drives the export.
        expect(exported.width, 320);
        expect(exported.height, 160);
        expect(exported.width, lessThan(400));
        expect(exported.height, lessThan(200));
      },
    );

    testWidgets(
      'distinct crop rects produce distinctly sized exports (rect-proportional)',
      (tester) async {
        // Paired case so the exported dimensions track the chosen rect, not a
        // fixed constant: a narrow crop and a wide crop of the same 1000x1000
        // source must yield different, rect-proportional outputs.
        late ui.Image narrow;
        late ui.Image wide;
        await tester.runAsync(() async {
          final c1 = CropController();
          c1.image = await _solidImage(1000, 1000);
          c1.crop = const Rect.fromLTRB(0.0, 0.0, 0.1, 0.2); // 100x200
          narrow = await _decode((await cropControllerToPngBytes(c1))!);
          c1.dispose();

          final c2 = CropController();
          c2.image = await _solidImage(1000, 1000);
          c2.crop = const Rect.fromLTRB(0.0, 0.0, 0.9, 0.3); // 900x300
          wide = await _decode((await cropControllerToPngBytes(c2))!);
          c2.dispose();
        });

        expect(narrow.width, 100);
        expect(narrow.height, 200);
        expect(wide.width, 900);
        expect(wide.height, 300);
      },
    );

    test(
      'the default crop window is the centered 80% sub-rect (never the full page)',
      () {
        // Guards the constant the dialog seeds and its aspect presets reset to.
        // A regression to a full-page 0..1 default would silently re-export the
        // whole page — exactly the behavior issue #36 asked to replace.
        expect(kAnkiCropDefaultRect, const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9));
        expect(kAnkiCropDefaultRect.width, closeTo(0.8, 1e-9));
        expect(kAnkiCropDefaultRect.height, closeTo(0.8, 1e-9));
        expect(kAnkiCropDefaultRect.left, greaterThan(0.0));
        expect(kAnkiCropDefaultRect.right, lessThan(1.0));
      },
    );
  });
}
