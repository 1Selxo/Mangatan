// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SubtitleSettingsState)
final subtitleSettingsStateProvider = SubtitleSettingsStateProvider._();

final class SubtitleSettingsStateProvider
    extends $NotifierProvider<SubtitleSettingsState, PlayerSubtitleSettings> {
  SubtitleSettingsStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subtitleSettingsStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subtitleSettingsStateHash();

  @$internal
  @override
  SubtitleSettingsState create() => SubtitleSettingsState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlayerSubtitleSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlayerSubtitleSettings>(value),
    );
  }
}

String _$subtitleSettingsStateHash() =>
    r'75b3da2c8c57e00cf128d063dad5f054ca9e7b96';

abstract class _$SubtitleSettingsState
    extends $Notifier<PlayerSubtitleSettings> {
  PlayerSubtitleSettings build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<PlayerSubtitleSettings, PlayerSubtitleSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlayerSubtitleSettings, PlayerSubtitleSettings>,
              PlayerSubtitleSettings,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
