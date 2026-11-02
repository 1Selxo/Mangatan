import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/repositories/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'incognito_mode_state_provider.g.dart';

@riverpod
class IncognitoModeState extends _$IncognitoModeState {
  @override
  bool build() {
    return settingsRepository.field((s) => s.incognitoModeProperty()) ?? false;
  }

  void setIncognitoMode(bool value) {
    state = value;
    settingsRepository.update((s) => s.incognitoMode = value);
  }
}
