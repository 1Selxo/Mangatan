import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/repositories/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'downloaded_only_state_provider.g.dart';

@riverpod
class DownloadedOnlyState extends _$DownloadedOnlyState {
  @override
  bool build() {
    return settingsRepository.field((s) => s.downloadedOnlyModeProperty()) ??
        false;
  }

  void setDownloadedOnly(bool value) {
    state = value;
    settingsRepository.update((s) => s.downloadedOnlyMode = value);
  }
}
