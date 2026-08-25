import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/reader/panel_detection_service.dart';

void main() {
  test('maps letterboxed normalized model output back to the page', () {
    final output = Float32List.fromList([.30, .20, .70, .60, .90, 0]);

    final detections = parsePanelDetections(
      output,
      sourceWidth: 1000,
      sourceHeight: 2000,
    );

    expect(detections, hasLength(1));
    expect(detections.single.kind, PanelDetectionKind.panel);
    expect(detections.single.rect.left, closeTo(.1, .001));
    expect(detections.single.rect.top, closeTo(.2, .001));
    expect(detections.single.rect.right, closeTo(.9, .001));
    expect(detections.single.rect.bottom, closeTo(.6, .001));
  });

  test('filters low-confidence and tiny panel detections', () {
    final output = Float32List.fromList([
      .25,
      .10,
      .75,
      .40,
      .24,
      0,
      .49,
      .10,
      .51,
      .12,
      .99,
      0,
    ]);

    expect(
      parsePanelDetections(output, sourceWidth: 1000, sourceHeight: 2000),
      isEmpty,
    );
  });

  test('speech bubbles split a full-width panel into reading stops', () {
    final ordered = orderPanelDetections([
      const PanelDetection(
        rect: Rect.fromLTRB(.05, .05, .95, .8),
        confidence: .9,
        kind: PanelDetectionKind.panel,
      ),
      const PanelDetection(
        rect: Rect.fromLTRB(.1, .1, .3, .25),
        confidence: .8,
        kind: PanelDetectionKind.speechBubble,
      ),
      const PanelDetection(
        rect: Rect.fromLTRB(.6, .45, .8, .6),
        confidence: .8,
        kind: PanelDetectionKind.speechBubble,
      ),
    ]);

    expect(ordered, hasLength(2));
    expect(ordered.first.rect.center.dy, lessThan(ordered.last.rect.center.dy));
    expect(
      ordered.every((item) => item.kind == PanelDetectionKind.panel),
      true,
    );
  });
}
