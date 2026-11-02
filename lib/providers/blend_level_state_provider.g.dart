// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blend_level_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BlendLevelState)
final blendLevelStateProvider = BlendLevelStateProvider._();

final class BlendLevelStateProvider
    extends $NotifierProvider<BlendLevelState, double> {
  BlendLevelStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blendLevelStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blendLevelStateHash();

  @$internal
  @override
  BlendLevelState create() => BlendLevelState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$blendLevelStateHash() => r'5cc149bda4d805c2783daed78abbb99e83df927d';

abstract class _$BlendLevelState extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double, double>,
              double,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
