import 'package:flutter/material.dart';
import 'package:mangayomi/modules/anime/widgets/play_or_pause_button.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Chimahon-style primary playback cluster: previous, play/pause, and next.
class ChimahonPrimaryControls extends StatelessWidget {
  const ChimahonPrimaryControls({
    super.key,
    required this.controller,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  final VideoController controller;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).shortestSide < 600;
    final spacing = compact ? 24.0 : 40.0;
    final skipIconSize = compact ? 42.0 : 48.0;
    final playIconSize = compact ? 72.0 : 84.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PrimaryIconButton(
          icon: Icons.skip_previous_rounded,
          enabled: hasPrevious,
          iconSize: skipIconSize,
          onPressed: onPrevious,
        ),
        SizedBox(width: spacing),
        CustomPlayOrPauseButton(controller: controller, iconSize: playIconSize),
        SizedBox(width: spacing),
        _PrimaryIconButton(
          icon: Icons.skip_next_rounded,
          enabled: hasNext,
          iconSize: skipIconSize,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _PrimaryIconButton extends StatelessWidget {
  const _PrimaryIconButton({
    required this.icon,
    required this.enabled,
    required this.iconSize,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final double iconSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.white : Colors.white38;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    );
  }
}
