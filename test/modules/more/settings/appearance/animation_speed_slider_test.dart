import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/animation_duration_scale_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/widgets/animation_speed_slider.dart';

void main() {
  testWidgets('animation slider exposes animation-off as its lower endpoint', (
    tester,
  ) async {
    await tester.pumpWidget(_appWithScale(0.0));

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 0.0);
    expect(slider.max, 1.1);
    expect(slider.divisions, 11);
    expect(slider.value, 0.0);
    expect(find.text('No animation'), findsOneWidget);
  });

  testWidgets('animation slider exposes 110% duration as its upper endpoint', (
    tester,
  ) async {
    await tester.pumpWidget(_appWithScale(1.1));

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 1.1);
    expect(find.text('Animation speed'), findsOneWidget);
    expect(find.text('110% duration'), findsOneWidget);
    expect(find.text('Lower values play animations faster.'), findsOneWidget);
  });
}

Widget _appWithScale(double scale) {
  return ProviderScope(
    overrides: [animationDurationScaleProvider.overrideWithValue(scale)],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AnimationSpeedSlider()),
    ),
  );
}
