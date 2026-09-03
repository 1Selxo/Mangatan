import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/repositories/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mangayomi/main.dart';
part 'color_filter_provider.g.dart';

@riverpod
class CustomColorFilterState extends _$CustomColorFilterState {
  @override
  CustomColorFilter? build() {
    if (!ref.watch(enableCustomColorFilterStateProvider)) return null;
    return settingsRepository.current.customColorFilter;
  }

  void set(int a, int r, int g, int b, bool _) {
    final settings = isar.settings.getSync(227);
    var value = CustomColorFilter()
      ..a = a
      ..r = r
      ..g = g
      ..b = b;
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..customColorFilter = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class EnableCustomColorFilterState extends _$EnableCustomColorFilterState {
  @override
  bool build() {
    return settingsRepository.current.enableCustomColorFilter ?? false;
  }

  void set(bool value) {
    settingsRepository.update((s) => s.enableCustomColorFilter = value);
    state = value;
  }
}

@riverpod
class ColorFilterBlendModeState extends _$ColorFilterBlendModeState {
  @override
  ColorFilterBlendMode build() {
    return settingsRepository.current.colorFilterBlendMode;
  }

  void set(ColorFilterBlendMode value) {
    settingsRepository.update((s) => s.colorFilterBlendMode = value);
    state = value;
  }
}
