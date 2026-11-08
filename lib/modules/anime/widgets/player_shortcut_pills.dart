import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mangayomi/modules/anime/utils/player_labels.dart';
import 'package:mangayomi/modules/anime/utils/temporary_playback_speed.dart';
import 'package:mangayomi/modules/widgets/settings/settings_rows.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/utils/platform_utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shiori/shiori.dart';

/// The pills [PlayerShortcutPills] can show.
enum PlayerPill { quality, subtitles, audio, speed, fit, fullscreen }

/// The row of shortcut pills in the player's bar, after upstream's: each
/// shows its value (quality, subtitle and audio track, speed, fit) and
/// opens where it is changed. [pills] picks which, so a narrow phone keeps
/// the ones it uses most.
///
/// The labels come from the player view, which knows Mangatan's own
/// subtitle sources (a subtitle drawn by the app is not an mpv track).
class PlayerShortcutPills extends StatelessWidget {
  const PlayerShortcutPills({
    super.key,
    required this.player,
    required this.qualityListenable,
    required this.qualityLabel,
    required this.subtitleLabel,
    required this.audioLabel,
    required this.playbackSpeed,
    required this.fit,
    required this.onQuality,
    required this.onSubtitles,
    required this.onAudio,
    required this.onSpeed,
    required this.onChangeFit,
    this.onToggleFullscreen,
    this.isFullscreen = false,
    this.iconOnly = false,
    this.pills = const {...PlayerPill.values},
  });

  final Set<PlayerPill> pills;
  final Player player;

  /// Rebuilds the quality pill when the stream changes.
  final Listenable qualityListenable;

  /// The quality now, or null when there is no other to pick.
  final String? Function() qualityLabel;

  /// The subtitle now, "Off" when there is none.
  final String Function() subtitleLabel;

  /// The audio track now; null hides the pill (a single track).
  final String? Function() audioLabel;

  final ValueListenable<double> playbackSpeed;
  final ValueListenable<BoxFit> fit;

  /// Each gets the pill's own context, to place a menu by it.
  final ValueChanged<BuildContext> onQuality;
  final ValueChanged<BuildContext> onSubtitles;
  final ValueChanged<BuildContext> onAudio;
  final ValueChanged<BuildContext> onSpeed;
  final VoidCallback onChangeFit;

  /// Null leaves the fullscreen pill out (desktop has its own button).
  final VoidCallback? onToggleFullscreen;
  final bool isFullscreen;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pills.contains(PlayerPill.quality))
          ListenableBuilder(
            listenable: qualityListenable,
            builder: (context, _) {
              final label = qualityLabel();
              if (label == null) return const SizedBox.shrink();
              final short = shortQualityLabel(label);
              return _pill(
                (context) => PlayerPillButton(
                  icon: Symbols.hd_rounded,
                  label: short.isNotEmpty ? short : null,
                  showLabel: !iconOnly,
                  tooltip: l10n.video_quality,
                  isCompact: isMobile,
                  onTap: () => onQuality(context),
                ),
              );
            },
          ),
        if (pills.contains(PlayerPill.subtitles))
          _trackPill(
            (context) => PlayerPillButton(
              icon: Symbols.closed_caption_rounded,
              label: subtitleLabel(),
              showLabel: !iconOnly,
              tooltip: l10n.video_subtitle,
              isCompact: isMobile,
              onTap: () => onSubtitles(context),
            ),
          ),
        if (pills.contains(PlayerPill.audio))
          _trackPill((context) {
            final label = audioLabel();
            if (label == null) return const SizedBox.shrink();
            return PlayerPillButton(
              icon: Symbols.graphic_eq_rounded,
              label: label.isNotEmpty ? label : null,
              showLabel: !iconOnly,
              tooltip: l10n.video_audio,
              isCompact: isMobile,
              onTap: () => onAudio(context),
            );
          }),
        if (pills.contains(PlayerPill.speed))
          _pill(
            (context) => ValueListenableBuilder<double>(
              valueListenable: playbackSpeed,
              builder: (context, speed, _) => PlayerPillButton(
                icon: Symbols.slow_motion_video_rounded,
                label: temporaryPlaybackSpeedLabel(speed),
                showLabel: !iconOnly,
                tooltip: l10n.playback_speed,
                isCompact: isMobile,
                onTap: () => onSpeed(context),
              ),
            ),
          ),
        if (pills.contains(PlayerPill.fit))
          _pill(
            (context) => ValueListenableBuilder<BoxFit>(
              valueListenable: fit,
              builder: (context, fit, _) => PlayerPillButton(
                icon: Symbols.aspect_ratio_rounded,
                label: fitShortLabel(fit),
                showLabel: !iconOnly,
                tooltip: l10n.scale_type_fit_screen,
                isCompact: isMobile,
                onTap: onChangeFit,
              ),
            ),
          ),
        if (onToggleFullscreen != null && pills.contains(PlayerPill.fullscreen))
          _pill(
            (context) => PlayerPillButton(
              icon: isFullscreen
                  ? Symbols.fullscreen_exit_rounded
                  : Symbols.fullscreen_rounded,
              tooltip: l10n.fullscreen,
              isCompact: isMobile,
              onTap: onToggleFullscreen!,
            ),
          ),
      ],
    );
  }

  Widget _pill(WidgetBuilder builder) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: ShioriSpace.s4),
    child: Builder(builder: builder),
  );

  /// A pill that rebuilds whenever mpv reports a track change.
  Widget _trackPill(WidgetBuilder builder) => _pill(
    (context) => StreamBuilder<Track>(
      stream: player.stream.track,
      builder: (context, _) => builder(context),
    ),
  );
}
