import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/animation_duration_scale_provider.dart';

void main() {
  group('animation duration scale', () {
    test('defaults to the current animation duration', () {
      expect(normalizeAnimationDurationScale(null), 1.0);
    });

    test('accepts the requested duration range', () {
      expect(normalizeAnimationDurationScale(0.0), 0.0);
      expect(normalizeAnimationDurationScale(0.5), 0.5);
      expect(normalizeAnimationDurationScale(1.1), 1.1);
    });

    test('clamps values outside the requested range', () {
      expect(normalizeAnimationDurationScale(-0.1), 0.0);
      expect(normalizeAnimationDurationScale(1.2), 1.1);
    });

    test('maps animation-off to an effectively instant scheduler scale', () {
      expect(animationTimeDilation(0.0), disabledAnimationTimeDilation);
      expect(animationTimeDilation(0.5), 0.5);
      expect(animationTimeDilation(1.1), 1.1);
    });

    test(
      'persists in settings JSON and defaults older JSON to current speed',
      () {
        final json = Settings().toJson();
        expect(json['animationDurationScale'], 1.0);

        json['animationDurationScale'] = 0.4;
        expect(Settings.fromJson(json).animationDurationScale, 0.4);

        json.remove('animationDurationScale');
        expect(Settings.fromJson(json).animationDurationScale, 1.0);
      },
    );
  });
}
