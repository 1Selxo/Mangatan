import 'package:hive_flutter/adapters.dart';
import 'package:mangayomi/services/mining/anki_markers.dart';

class MiningPreferences {
  static const _boxName = 'mining_preferences';
  static const _jimakuApiKey = 'jimaku_api_key';
  static const _autoJimaku = 'auto_jimaku';
  static const _ankiEndpoint = 'anki_endpoint';
  static const _ankiProfile = 'anki_profile';

  MiningPreferences._();

  static Future<Box<dynamic>> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  static Future<Box<dynamic>?> _boxOrNull() async {
    try {
      return await _box();
    } catch (_) {
      return null;
    }
  }

  static Future<String> getJimakuApiKey() async {
    return (await _boxOrNull())?.get(_jimakuApiKey, defaultValue: '')
            as String? ??
        '';
  }

  static Future<void> setJimakuApiKey(String value) async {
    await (await _boxOrNull())?.put(_jimakuApiKey, value.trim());
  }

  static Future<bool> getAutoJimakuEnabled() async {
    return (await _boxOrNull())?.get(_autoJimaku, defaultValue: true)
            as bool? ??
        true;
  }

  static Future<void> setAutoJimakuEnabled(bool value) async {
    await (await _boxOrNull())?.put(_autoJimaku, value);
  }

  static Future<String> getJimakuTitleOverride(int? mediaId) async {
    return (await _boxOrNull())?.get(_jimakuTitleKey(mediaId), defaultValue: '')
            as String? ??
        '';
  }

  static Future<void> setJimakuTitleOverride(int? mediaId, String value) async {
    await (await _boxOrNull())?.put(_jimakuTitleKey(mediaId), value.trim());
  }

  static Future<Uri> getAnkiEndpoint() async {
    final raw =
        (await _boxOrNull())?.get(
              _ankiEndpoint,
              defaultValue: 'http://127.0.0.1:8765',
            )
            as String? ??
        'http://127.0.0.1:8765';
    return Uri.tryParse(raw) ?? Uri.parse('http://127.0.0.1:8765');
  }

  static Future<void> setAnkiEndpoint(Uri value) async {
    await (await _boxOrNull())?.put(_ankiEndpoint, value.toString());
  }

  static Future<AnkiMiningProfile> getAnkiProfile() async {
    final raw = (await _boxOrNull())?.get(_ankiProfile);
    return AnkiMiningProfile.fromJson(raw is Map ? raw : null);
  }

  static Future<void> setAnkiProfile(AnkiMiningProfile profile) async {
    await (await _boxOrNull())?.put(_ankiProfile, profile.toJson());
  }

  static String _jimakuTitleKey(int? mediaId) {
    return 'jimaku_title_${mediaId ?? 'global'}';
  }
}
