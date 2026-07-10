import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/utils/platform_utils.dart';

void main() {
  test('word audio is enabled by default', () {
    expect(AnkiAudioPreferences.defaults.enabled, isTrue);
  });

  test('page tap zones are disabled by default on desktop', () {
    expect(Settings().usePageTapZones, !isDesktop);
  });
}
