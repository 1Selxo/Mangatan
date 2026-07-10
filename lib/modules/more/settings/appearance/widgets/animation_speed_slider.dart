import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/animation_duration_scale_provider.dart';
import 'package:mangayomi/providers/l10n_providers.dart';

class AnimationSpeedSlider extends ConsumerWidget {
  const AnimationSpeedSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final durationScale = ref.watch(animationDurationScaleProvider);
    final l10n = l10nLocalizations(context)!;
    final valueLabel = durationScale == minimumAnimationDurationScale
        ? l10n.no_animation
        : l10n.animation_duration_percentage((durationScale * 100).round());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.animation_speed,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(valueLabel),
            ],
          ),
        ),
        Slider(
          min: minimumAnimationDurationScale,
          max: maximumAnimationDurationScale,
          divisions: 11,
          value: durationScale,
          label: valueLabel,
          semanticFormatterCallback: (_) => valueLabel,
          onChanged: (value) =>
              ref.read(animationDurationScaleProvider.notifier).set(value),
          onChangeEnd: (value) => ref
              .read(animationDurationScaleProvider.notifier)
              .set(value, persist: true),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          child: Text(
            l10n.animation_speed_description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
