import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/repositories/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mangayomi/main.dart';
part 'state_provider.g.dart';

@riverpod
class SubtitleSettingsState extends _$SubtitleSettingsState {
  @override
  PlayerSubtitleSettings build() {
    final subSets = settingsRepository.current.playerSubtitleSettings;
    if (subSets == null || subSets.backgroundColorA == null) {
      set(PlayerSubtitleSettings(), true);
      return PlayerSubtitleSettings();
    }
    return subSets;
  }

  void set(PlayerSubtitleSettings value, bool end) {
    state = value;
    if (end) {
      settingsRepository.update((s) => s.playerSubtitleSettings = value);
    }
  }

  void resetColor() {
    state = PlayerSubtitleSettings(
      fontSize: state.fontSize,
      fontWeight: state.fontWeight,
      position: state.position ?? 0,
      useBold: state.useBold,
      useItalic: state.useItalic,
      outlineThickness: state.outlineThickness,
      shadowThickness: state.shadowThickness,
    );
    settingsRepository.update(
      (settings) => settings.playerSubtitleSettings = PlayerSubtitleSettings(
        fontSize: state.fontSize,
        fontWeight: state.fontWeight,
        position: state.position ?? 0,
        useBold: state.useBold,
        useItalic: state.useItalic,
        outlineThickness: state.outlineThickness,
        shadowThickness: state.shadowThickness,
      ),
    );
  }
}
