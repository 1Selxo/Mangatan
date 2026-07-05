import 'package:hive_flutter/adapters.dart';
import 'package:mangayomi/services/mining/anki_markers.dart';

enum OcrEnginePreference { automatic, googleLens, mokuroOnly }

class MiningPreferences {
  static const _boxName = 'mining_preferences';
  static const _jimakuApiKey = 'jimaku_api_key';
  static const _autoJimaku = 'auto_jimaku';
  static const _ankiEndpoint = 'anki_endpoint';
  static const _ankiProfile = 'anki_profile';
  static const _ocrEngine = 'ocr_engine';
  static const _ocrOverlayEnabled = 'ocr_overlay_enabled';
  static const _ocrLanguage = 'ocr_language';
  static const _ocrOverlayOpacity = 'ocr_overlay_opacity';
  static const _ocrBoxScale = 'ocr_box_scale';
  static const _ocrOutlineVisible = 'ocr_outline_visible';

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

  static Future<OcrEnginePreference> getOcrEngine() async {
    final name =
        (await _boxOrNull())?.get(
              _ocrEngine,
              defaultValue: OcrEnginePreference.automatic.name,
            )
            as String? ??
        OcrEnginePreference.automatic.name;
    return OcrEnginePreference.values.firstWhere(
      (value) => value.name == name,
      orElse: () => OcrEnginePreference.automatic,
    );
  }

  static Future<void> setOcrEngine(OcrEnginePreference value) async {
    await (await _boxOrNull())?.put(_ocrEngine, value.name);
  }

  static Future<bool> getOcrOverlayEnabled() async {
    return (await _boxOrNull())?.get(_ocrOverlayEnabled, defaultValue: true)
            as bool? ??
        true;
  }

  static Future<void> setOcrOverlayEnabled(bool value) async {
    await (await _boxOrNull())?.put(_ocrOverlayEnabled, value);
  }

  static Future<String> getOcrLanguage() async {
    return (await _boxOrNull())?.get(_ocrLanguage, defaultValue: 'ja')
            as String? ??
        'ja';
  }

  static Future<void> setOcrLanguage(String value) async {
    await (await _boxOrNull())?.put(_ocrLanguage, value);
  }

  static Future<double> getOcrOverlayOpacity() async {
    return ((await _boxOrNull())?.get(_ocrOverlayOpacity, defaultValue: 0.72)
                as num? ??
            0.72)
        .toDouble();
  }

  static Future<void> setOcrOverlayOpacity(double value) async {
    await (await _boxOrNull())?.put(_ocrOverlayOpacity, value.clamp(0.1, 1.0));
  }

  static Future<double> getOcrBoxScale() async {
    return ((await _boxOrNull())?.get(_ocrBoxScale, defaultValue: 1.0)
                as num? ??
            1.0)
        .toDouble();
  }

  static Future<void> setOcrBoxScale(double value) async {
    await (await _boxOrNull())?.put(_ocrBoxScale, value.clamp(0.8, 1.5));
  }

  static Future<bool> getOcrOutlineVisible() async {
    return (await _boxOrNull())?.get(_ocrOutlineVisible, defaultValue: true)
            as bool? ??
        true;
  }

  static Future<void> setOcrOutlineVisible(bool value) async {
    await (await _boxOrNull())?.put(_ocrOutlineVisible, value);
  }

  static String _jimakuTitleKey(int? mediaId) {
    return 'jimaku_title_${mediaId ?? 'global'}';
  }
}
