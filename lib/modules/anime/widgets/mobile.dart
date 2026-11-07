// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/anime/anime_player_view.dart';
import 'package:mangayomi/modules/anime/providers/state_provider.dart';
import 'package:mangayomi/modules/anime/utils/temporary_playback_speed.dart';
import 'package:mangayomi/modules/anime/widgets/custom_seekbar.dart';
import 'package:mangayomi/modules/anime/widgets/indicator_builder.dart';
import 'package:mangayomi/modules/anime/widgets/mobile_player_controls_layout.dart';
import 'package:mangayomi/modules/anime/widgets/mobile_seek_indicator.dart';
import 'package:mangayomi/modules/anime/widgets/player_overlay_surface.dart';
import 'package:mangayomi/modules/anime/widgets/subtitle_view.dart';
import 'package:mangayomi/modules/anime/widgets/temporary_playback_speed_selector.dart';
import 'package:mangayomi/modules/more/settings/player/providers/player_state_provider.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/repositories/settings_repository.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:mangayomi/services/screen_brightness.dart';
import 'package:flutter/material.dart';
import 'package:shiori/shiori.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/extensions/duration.dart';

/// The phone's player controls, on upstream's Shiori layout: a scrim behind
/// the top bar, the episode controls in the middle, and the timeline with
/// the player's buttons in one panel floating over the foot of the picture.
///
/// Mangatan keeps its subtitle overlay above the controls (lookup, mining,
/// and the line kept clear of the timeline) and its own centre controls.
class MobileControllerWidget extends ConsumerStatefulWidget {
  final VideoController videoController;
  final Widget topButtonBarWidget;
  final Widget primaryButtonBarWidget;
  final Widget bottomButtonBarWidget;
  final ValueNotifier<List<(String, int)>> chapterMarks;
  final Future<MiningContext> Function(String text)?
  subtitleMiningContextBuilder;

  /// Resolves the dictionary profile for subtitle lookups without the
  /// screenshot [subtitleMiningContextBuilder] takes.
  final Future<DictionaryProfile> Function()? subtitleLookupProfileBuilder;

  /// While true, every control but the way out of the lock is hidden and
  /// the picture's gestures do nothing.
  final ValueNotifier<bool>? isLocked;

  const MobileControllerWidget({
    super.key,
    required this.videoController,
    required this.topButtonBarWidget,
    required this.primaryButtonBarWidget,
    required this.bottomButtonBarWidget,
    required this.chapterMarks,
    this.subtitleMiningContextBuilder,
    this.subtitleLookupProfileBuilder,
    this.isLocked,
  });

  @override
  ConsumerState<MobileControllerWidget> createState() =>
      _MobileControllerWidgetState();
}

class _MobileControllerWidgetState
    extends ConsumerState<MobileControllerWidget> {
  static const double _gestureInset = 16;

  bool mount = true;
  bool visible = true;
  Duration controlsTransitionDuration = ShioriMotion.enter;
  Timer? _timer;
  // Read, not watched: a late final is read once, and a double tap can be
  // the first to read it, outside build, where watch is not allowed.
  late final skipDuration = ref.read(defaultDoubleTapToSkipLengthStateProvider);
  final ValueNotifier<double> _brightnessValue = ValueNotifier(0.0);
  final ValueNotifier<bool> _brightnessIndicator = ValueNotifier(false);
  Timer? _brightnessTimer;
  bool _brightnessChanged = false;

  final ValueNotifier<double> _volumeValue = ValueNotifier(0.0);
  final ValueNotifier<bool> _volumeIndicator = ValueNotifier(false);
  Timer? _volumeTimer;
  // The default event stream in package:volume_controller is buggy.
  bool _volumeInterceptEventStream = false;

  Offset _dragInitialDelta =
      Offset.zero; // Initial position for horizontal drag
  int swipeDuration = 0; // Duration to seek in video
  bool showSwipeDuration = false; // Whether to show the seek duration overlay
  double previousPlaybackSpeed = -1;
  double? _temporaryPlaybackSpeed;
  double? _temporaryInitialSpeed;
  double? _temporarySpeedOriginY;

  late bool buffering = widget.videoController.player.state.buffering;
  final controlsHoverDuration = const Duration(seconds: 3);
  bool _mountSeekBackwardButton = false;
  bool _mountSeekForwardButton = false;
  bool _hideSeekBackwardButton = false;
  bool _hideSeekForwardButton = false;
  double buttonBarHeight = 100;
  final bottomButtonBarMargin = const EdgeInsets.only(
    left: ShioriSpace.s16,
    right: ShioriSpace.s8,
  );
  final GlobalKey _subtitleOverlayKey = GlobalKey();
  final GlobalKey _seekBarKey = GlobalKey();
  double _subtitleBottomInset = 24;
  bool _subtitleAnchorUpdateScheduled = false;

  Duration? _seekBarDeltaValueNotifier;

  final List<StreamSubscription> subscriptions = [];
  Offset? _tapPosition;

  bool get _locked => widget.isLocked?.value == true;

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _tapPosition = details.localPosition;
    });
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  final horizontalGestureSensitivity = 7500;
  final verticalGestureSensitivity = 500;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (subscriptions.isEmpty) {
      subscriptions.addAll([
        widget.videoController.player.stream.buffering.listen((event) {
          setState(() {
            buffering = event;
            if (event) {
              _mountSeekBackwardButton = false;
              _mountSeekForwardButton = false;
              _hideSeekBackwardButton = false;
              _hideSeekForwardButton = false;
              _seekBarDeltaValueNotifier = null;
            }
          });
        }),
      ]);

      _timer = Timer(controlsHoverDuration, () {
        if (mounted) {
          setState(() {
            visible = false;
          });
        }
      });
    }
  }

  void _onLockChanged() {
    if (!mounted) return;
    setState(() {});
    if (_locked) {
      if (!visible) {
        setState(() {
          mount = true;
          visible = true;
        });
      }
      _restartHideTimer();
    }
  }

  @override
  void didUpdateWidget(covariant MobileControllerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLocked != widget.isLocked) {
      oldWidget.isLocked?.removeListener(_onLockChanged);
      widget.isLocked?.addListener(_onLockChanged);
    }
  }

  @override
  void dispose() {
    _restorePlaybackSpeed(updateUi: false);
    widget.isLocked?.removeListener(_onLockChanged);
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    _timer?.cancel();
    _volumeTimer?.cancel();
    _brightnessTimer?.cancel();
    _rememberVolumeAndBrightness();
    _volumeValue.dispose();
    _volumeIndicator.dispose();
    _brightnessValue.dispose();
    _brightnessIndicator.dispose();
    _volumeController.removeListener();

    // Gives the screen's brightness back to the system.
    unawaited(ScreenBrightness.reset());
    super.dispose();
  }

  void onTap() {
    if (!visible) {
      setState(() {
        mount = true;
        visible = true;
      });
      _restartHideTimer();
    } else {
      setState(() {
        visible = false;
      });
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      _timer?.cancel();
    }
  }

  void _restartHideTimer() {
    _timer?.cancel();
    _timer = Timer(controlsHoverDuration, () {
      if (mounted) {
        setState(() {
          visible = false;
        });
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      }
    });
  }

  Duration _doubleTapSeekTarget(Duration offset, {required bool forward}) {
    final position = widget.videoController.player.state.position;
    final duration = widget.videoController.player.state.duration;
    final target = forward ? position + offset : position - offset;
    return target.clamp(Duration.zero, duration);
  }

  /// A double tap seeks with the controls out of the way: only the timeline
  /// shows, in its panel, while the taps add up.
  void _startDoubleTapSeek({required bool forward}) {
    _timer?.cancel();
    final offset = Duration(seconds: skipDuration);

    setState(() {
      mount = false;
      visible = false;
      _mountSeekForwardButton = forward;
      _mountSeekBackwardButton = !forward;
      _hideSeekForwardButton = false;
      _hideSeekBackwardButton = false;
      _seekBarDeltaValueNotifier = _doubleTapSeekTarget(
        offset,
        forward: forward,
      );
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  void onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_dragInitialDelta == Offset.zero) {
      _dragInitialDelta = details.localPosition;
      return;
    }

    final diff = _dragInitialDelta.dx - details.localPosition.dx;
    final duration = widget.videoController.player.state.duration.inSeconds;
    final position = widget.videoController.player.state.position.inSeconds;

    final seconds = -(diff * duration / horizontalGestureSensitivity).round();
    final relativePosition = position + seconds;

    if (relativePosition <= duration && relativePosition >= 0) {
      setState(() {
        swipeDuration = seconds;
        showSwipeDuration = true;
        _seekBarDeltaValueNotifier = Duration(
          seconds:
              widget.videoController.player.state.position.inSeconds + seconds,
        );
      });
    }
  }

  void onHorizontalDragEnd() {
    if (swipeDuration != 0) {
      Duration newPosition =
          widget.videoController.player.state.position +
          Duration(seconds: swipeDuration);
      newPosition = newPosition.clamp(
        Duration.zero,
        widget.videoController.player.state.duration,
      );
      widget.videoController.player.seek(newPosition);
    }

    setState(() {
      _dragInitialDelta = Offset.zero;
      showSwipeDuration = false;
      _seekBarDeltaValueNotifier = null;
    });
  }

  late final VolumeController _volumeController;

  /// Read once the controls start: dispose() can no longer use ref.
  late final bool _rememberVolume;
  late final bool _rememberBrightness;

  @override
  void initState() {
    super.initState();
    _rememberVolume = ref.read(rememberPlayerVolumeStateProvider);
    _rememberBrightness = ref.read(rememberPlayerBrightnessStateProvider);
    widget.isLocked?.addListener(_onLockChanged);
    _volumeController = VolumeController.instance;

    Future.microtask(() async {
      try {
        _volumeController.showSystemUI = false;
        final remembered = _rememberVolume
            ? settingsRepository.current.playerVolume
            : null;
        if (remembered != null) {
          _volumeController.setVolume(remembered.clamp(0.0, 1.0));
        }
        _volumeValue.value = await _volumeController.getVolume();
        _volumeController.addListener((value) {
          if (mounted && !_volumeInterceptEventStream) {
            _volumeValue.value = value;
          }
        });
      } catch (_) {}
    });

    Future.microtask(() async {
      try {
        final remembered = _rememberBrightness
            ? settingsRepository.current.playerBrightness
            : null;
        if (remembered != null) {
          _brightnessChanged = true;
          await ScreenBrightness.set(remembered.clamp(0.0, 1.0));
        }
        final current = await ScreenBrightness.current();
        if (mounted && current != null) _brightnessValue.value = current;
      } catch (_) {}
    });
  }

  /// Keeps the volume and brightness the episode ended with, for the next
  /// one, when asked to.
  void _rememberVolumeAndBrightness() {
    final volume = _rememberVolume ? _volumeValue.value : null;
    final brightness = _brightnessChanged && _rememberBrightness
        ? _brightnessValue.value
        : null;
    if (volume == null && brightness == null) return;
    settingsRepository.update((s) {
      if (volume != null) s.playerVolume = volume;
      if (brightness != null) s.playerBrightness = brightness;
    });
  }

  Future<void> setVolume(double value) async {
    try {
      _volumeController.setVolume(value);
    } catch (_) {}
    _volumeValue.value = value;
    _volumeIndicator.value = true;
    _volumeInterceptEventStream = true;
    _volumeTimer?.cancel();
    _volumeTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        _volumeIndicator.value = false;
        _volumeInterceptEventStream = false;
      }
    });
  }

  Future<void> setBrightness(double value) async {
    _brightnessChanged = true;
    _brightnessValue.value = value;
    unawaited(ScreenBrightness.set(value));
    _brightnessIndicator.value = true;
    _brightnessTimer?.cancel();
    _brightnessTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        _brightnessIndicator.value = false;
      }
    });
  }

  /// Hold to play faster, and slide up or down while holding to pick how
  /// much faster; letting go gives the speed back.
  void _startTemporaryPlaybackSpeed(LongPressStartDetails details) {
    if (_locked || previousPlaybackSpeed != -1) return;

    previousPlaybackSpeed = widget.videoController.player.state.rate;
    final initialSpeed = initialTemporaryPlaybackSpeed();

    setState(() {
      _temporaryPlaybackSpeed = initialSpeed;
      _temporaryInitialSpeed = initialSpeed;
      _temporarySpeedOriginY = details.localPosition.dy;
    });
    HapticFeedback.mediumImpact();
    unawaited(widget.videoController.player.setRate(initialSpeed));
  }

  void _updateTemporaryPlaybackSpeed(LongPressMoveUpdateDetails details) {
    final initialSpeed = _temporaryInitialSpeed;
    final originY = _temporarySpeedOriginY;
    if (initialSpeed == null || originY == null) return;

    final speed = temporaryPlaybackSpeedForDrag(
      initialSpeed: initialSpeed,
      verticalDelta: details.localPosition.dy - originY,
    );
    if (speed == _temporaryPlaybackSpeed) return;

    setState(() {
      _temporaryPlaybackSpeed = speed;
    });

    HapticFeedback.selectionClick();
    unawaited(widget.videoController.player.setRate(speed));
  }

  void _restorePlaybackSpeed({bool updateUi = true}) {
    if (previousPlaybackSpeed == -1) return;

    final speedToRestore = previousPlaybackSpeed;
    previousPlaybackSpeed = -1;
    unawaited(widget.videoController.player.setRate(speedToRestore));

    void clearSelection() {
      _temporaryPlaybackSpeed = null;
      _temporaryInitialSpeed = null;
      _temporarySpeedOriginY = null;
    }

    if (updateUi && mounted) {
      setState(clearSelection);
    } else {
      clearSelection();
    }
  }

  void _scheduleSubtitleAnchorUpdate() {
    if (_subtitleAnchorUpdateScheduled) return;
    _subtitleAnchorUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subtitleAnchorUpdateScheduled = false;
      if (!mounted) return;
      final overlay =
          _subtitleOverlayKey.currentContext?.findRenderObject() as RenderBox?;
      final seekBar =
          _seekBarKey.currentContext?.findRenderObject() as RenderBox?;
      if (overlay == null || seekBar == null) return;
      final seekBarTop = overlay
          .globalToLocal(seekBar.localToGlobal(Offset.zero))
          .dy;
      final inset = subtitleBottomInsetForSeekBar(
        playerHeight: overlay.size.height,
        seekBarTop: seekBarTop,
      );
      if ((inset - _subtitleBottomInset).abs() > 0.5) {
        setState(() => _subtitleBottomInset = inset);
      }
    });
  }

  Widget _seekIndicator({required bool forward, required bool compact}) {
    final hide = forward ? _hideSeekForwardButton : _hideSeekBackwardButton;
    return AbsorbPointer(
      absorbing: hide,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: hide ? 0.0 : 1.0),
        duration: ShioriMotion.of(context, ShioriMotion.standard),
        builder: (context, value, child) =>
            Opacity(opacity: value, child: child),
        onEnd: () {
          if (!hide) return;
          setState(() {
            if (forward) {
              _hideSeekForwardButton = false;
              _mountSeekForwardButton = false;
            } else {
              _hideSeekBackwardButton = false;
              _mountSeekBackwardButton = false;
            }
            _seekBarDeltaValueNotifier = null;
          });
        },
        child: MobileSeekIndicator(
          forward: forward,
          compactPortrait: compact,
          onChanged: (value) {
            setState(() {
              _seekBarDeltaValueNotifier = _doubleTapSeekTarget(
                value,
                forward: forward,
              );
            });
          },
          onSubmitted: (value) {
            setState(() {
              if (forward) {
                _hideSeekForwardButton = true;
              } else {
                _hideSeekBackwardButton = true;
              }
            });
            widget.videoController.player.seek(
              _doubleTapSeekTarget(value, forward: forward),
            );
          },
          skipDuration: skipDuration,
        ),
      ),
    );
  }

  Widget _mediaIndicator(
    ValueNotifier<bool> shown,
    ValueNotifier<double> value, {
    required bool volume,
  }) {
    return IgnorePointer(
      child: ValueListenableBuilder(
        valueListenable: shown,
        builder: (context, isShown, child) => AnimatedOpacity(
          curve: Curves.easeInOut,
          opacity: isShown ? 1.0 : 0.0,
          duration: controlsTransitionDuration,
          child: MediaIndicatorBuilder(
            value: value,
            isVolumeIndicator: volume,
            adaptiveMobilePlacement: true,
            showAtZero: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _scheduleSubtitleAnchorUpdate();
    final compactPortrait = usesCompactPortraitPlayerControls(
      orientation: MediaQuery.orientationOf(context),
      width: MediaQuery.sizeOf(context).width,
    );
    final scrim = Theme.of(context).colorScheme.scrim;
    return Stack(
      key: _subtitleOverlayKey,
      children: [
        Focus(
          autofocus: true,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Controls:
              AnimatedOpacity(
                curve: Curves.easeInOut,
                opacity: visible ? 1.0 : 0.0,
                duration: controlsTransitionDuration,
                onEnd: () {
                  setState(() {
                    if (!visible) {
                      mount = false;
                    }
                  });
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // A scrim behind the top bar only: the timeline brings
                    // its own ground.
                    if (!_locked)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: compactPortrait ? 200 : 140,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  scrim.withValues(alpha: 0.75),
                                  scrim.withValues(alpha: 0.35),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.65, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    // A 16 px margin around the gesture area keeps the
                    // system's edge swipes (status bar, navigation bar, back)
                    // from starting a volume or brightness drag.
                    Positioned.fill(
                      left: _gestureInset,
                      top: _gestureInset,
                      right: _gestureInset,
                      bottom: _gestureInset,
                      child: GestureDetector(
                        onTap: onTap,
                        onDoubleTapDown: _handleTapDown,
                        onDoubleTap: () {
                          if (_locked) return;
                          final forward =
                              _tapPosition != null &&
                              _tapPosition!.dx >
                                  (MediaQuery.sizeOf(context).width -
                                          _gestureInset * 2) /
                                      2;
                          _startDoubleTapSeek(forward: forward);
                        },
                        // It owns the long press as well as the vertical drag,
                        // so a completed hold wins the gesture arena before
                        // volume or brightness can start.
                        onLongPressStart: _startTemporaryPlaybackSpeed,
                        onLongPressMoveUpdate: _updateTemporaryPlaybackSpeed,
                        onLongPressEnd: (_) => _restorePlaybackSpeed(),
                        onLongPressCancel: _restorePlaybackSpeed,
                        onHorizontalDragUpdate: (details) {
                          if (_locked) return;
                          onHorizontalDragUpdate(details);
                        },
                        onHorizontalDragEnd: (details) {
                          if (_locked) return;
                          onHorizontalDragEnd();
                        },
                        onVerticalDragUpdate: (e) async {
                          if (_locked) return;
                          final delta = e.delta.dy;
                          final Offset position = e.localPosition;

                          if (position.dx <=
                              MediaQuery.sizeOf(context).width / 2) {
                            final brightness =
                                _brightnessValue.value -
                                delta / verticalGestureSensitivity;
                            setBrightness(brightness.clamp(0.0, 1.0));
                          } else {
                            final volume =
                                _volumeValue.value -
                                delta / verticalGestureSensitivity;
                            setVolume(volume.clamp(0.0, 1.0));
                          }
                        },
                        child: Listener(
                          // A platform interruption can cancel the pointer
                          // after Flutter has accepted the long press.
                          behavior: HitTestBehavior.translucent,
                          onPointerCancel: (_) => _restorePlaybackSpeed(),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ),
                    if (mount)
                      if (_locked)
                        Positioned.fill(
                          child: MobilePlayerUnlockControl(
                            tooltip: context.l10n.unlock,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              widget.isLocked?.value = false;
                              _restartHideTimer();
                            },
                          ),
                        )
                      else
                        MobilePlayerControlsOverlayLayout(
                          compactPortrait: compactPortrait,
                          safeInsets: mobilePlayerControlInsets(context),
                          topControls: widget.topButtonBarWidget,
                          // Hidden while buffering or seeking by swipe.
                          primaryControls: AnimatedOpacity(
                            curve: Curves.easeInOut,
                            opacity: buffering || showSwipeDuration ? 0 : 1,
                            duration: controlsTransitionDuration,
                            child: Center(child: widget.primaryButtonBarWidget),
                          ),
                          // The timeline and the player's buttons in one
                          // panel floating over the foot of the picture, as
                          // the manga reader's: its own ground, so no
                          // gradient.
                          bottomControls: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              ShioriSpace.s8,
                              0,
                              ShioriSpace.s8,
                              ShioriSpace.s8,
                            ),
                            child: ShioriOverlayPanel(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CustomSeekBar(
                                    key: _seekBarKey,
                                    onSeekStart: (value) {
                                      setState(() {
                                        swipeDuration = value.inSeconds;
                                        showSwipeDuration = true;
                                      });
                                      _timer?.cancel();
                                    },
                                    onSeekEnd: (value) {
                                      _restartHideTimer();
                                      setState(() {
                                        showSwipeDuration = false;
                                      });
                                    },
                                    player: widget.videoController.player,
                                    chapterMarks: widget.chapterMarks,
                                  ),
                                  widget.bottomButtonBarWidget,
                                ],
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              // The timeline alone while a double tap or a swipe seeks, in the
              // same panel as with the controls.
              if (!mount && !_locked)
                if (_mountSeekBackwardButton ||
                    _mountSeekForwardButton ||
                    showSwipeDuration)
                  Padding(
                    padding: mobilePlayerControlInsets(context),
                    child: Column(
                      children: [
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            ShioriSpace.s8,
                            0,
                            ShioriSpace.s8,
                            ShioriSpace.s8,
                          ),
                          child: ShioriOverlayPanel(
                            padding: const EdgeInsets.symmetric(
                              horizontal: ShioriSpace.s12,
                              vertical: ShioriSpace.s8,
                            ),
                            child: CustomSeekBar(
                              delta: _seekBarDeltaValueNotifier,
                              player: widget.videoController.player,
                              chapterMarks: widget.chapterMarks,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              if (_temporaryPlaybackSpeed != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: TemporaryPlaybackSpeedSelector(
                      speed: _temporaryPlaybackSpeed!,
                    ),
                  ),
                ),
              // Buffering Indicator.
              IgnorePointer(
                child: Padding(
                  padding: isFullscreen(context)
                      ? MediaQuery.of(context).padding
                      : EdgeInsets.zero,
                  child: Column(
                    children: [
                      SizedBox(height: buttonBarHeight),
                      Expanded(
                        child: Center(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0.0,
                              end: buffering ? 1.0 : 0.0,
                            ),
                            duration: controlsTransitionDuration,
                            builder: (context, value, child) {
                              // Mounted only while it shows, so the spinner
                              // does not run unseen.
                              if (value > 0.0) {
                                return Opacity(opacity: value, child: child!);
                              }
                              return const SizedBox.shrink();
                            },
                            child: const PlayerBuffering(),
                          ),
                        ),
                      ),
                      Container(
                        height: buttonBarHeight,
                        margin: bottomButtonBarMargin,
                      ),
                    ],
                  ),
                ),
              ),
              _mediaIndicator(_volumeIndicator, _volumeValue, volume: true),
              _mediaIndicator(
                _brightnessIndicator,
                _brightnessValue,
                volume: false,
              ),
              // Seek Indicator.
              IgnorePointer(
                child: AnimatedOpacity(
                  duration: controlsTransitionDuration,
                  opacity: showSwipeDuration ? 1 : 0,
                  child: seekIndicatorTextWidget(
                    Duration(seconds: swipeDuration),
                    widget.videoController.player.state.position,
                  ),
                ),
              ),
              // Double-Tap Seek Button(s):
              if (_mountSeekBackwardButton || _mountSeekForwardButton)
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(
                        child: _mountSeekBackwardButton
                            ? _seekIndicator(
                                forward: false,
                                compact: compactPortrait,
                              )
                            : const SizedBox(),
                      ),
                      Expanded(
                        child: _mountSeekForwardButton
                            ? _seekIndicator(
                                forward: true,
                                compact: compactPortrait,
                              )
                            : const SizedBox(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Consumer(
          builder: (context, ref, _) {
            final subtitleSettings = ref.watch(subtitleSettingsStateProvider);
            return Positioned(
              child: CustomSubtitleView(
                controller: widget.videoController,
                configuration: SubtitleViewConfiguration(
                  style: subtileTextStyle(ref),
                  padding: EdgeInsets.fromLTRB(16, 0, 16, _subtitleBottomInset),
                ),
                paintSubtitle: true,
                verticalOffset: (subtitleSettings.position ?? 0).toDouble(),
                miningContextBuilder: widget.subtitleMiningContextBuilder,
                lookupProfileBuilder: widget.subtitleLookupProfileBuilder,
              ),
            );
          },
        ),
      ],
    );
  }
}
