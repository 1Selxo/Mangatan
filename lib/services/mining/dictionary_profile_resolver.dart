import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

enum DictionaryProfileResolutionLevel { manga, source, novel, language, active }

class ResolvedDictionaryProfile {
  const ResolvedDictionaryProfile(this.profile, this.level);

  final DictionaryProfile profile;
  final DictionaryProfileResolutionLevel level;
}

/// Chimahon-compatible cascading dictionary profile resolver.
///
/// Resolution order is deliberately identical to Chimahon: entry override,
/// source override, local-novel override, first matching source language, then
/// the profile selected globally in settings. Missing and stale override IDs
/// simply fall through to the next level.
class DictionaryProfileResolver {
  const DictionaryProfileResolver._();

  static String mangaOverrideKey(Object mangaId) =>
      '${MiningPreferences.dictionaryProfileMangaOverridePrefix}$mangaId';

  static String sourceOverrideKey(Object sourceId) =>
      '${MiningPreferences.dictionaryProfileSourceOverridePrefix}$sourceId';

  static String novelOverrideKey(Object novelId) =>
      '${MiningPreferences.dictionaryProfileNovelOverridePrefix}$novelId';

  /// Chimahon keys Mihon source overrides by the extension's native Long ID.
  /// Mangatan uses a hashed local Isar ID for those sources, so it must never
  /// leak into a compatible preference key.
  static String? overrideIdForSource(Source? source) {
    if (source == null) return null;
    final nativeId = mihonSourceMetadata(source)?.sourceId;
    if (nativeId != null &&
        (source.sourceCodeLanguage != SourceCodeLanguage.mihon ||
            int.tryParse(nativeId) != null)) {
      return nativeId;
    }
    // A malformed Mihon source has no compatible identity. Falling back to
    // Mangatan's hashed Isar ID would create an override Chimahon can never
    // recognize.
    if (source.sourceCodeLanguage == SourceCodeLanguage.mihon) return null;
    return source.id?.toString();
  }

  static String sourceLanguageForSource(Source? source, {String fallback = ''}) {
    final language = source?.lang?.trim();
    if (language?.isNotEmpty == true) return language!.toLowerCase();
    return fallback.trim().toLowerCase();
  }

  static Future<DictionaryProfile> resolve({
    Object? mangaId,
    Object? sourceId,
    String sourceLanguage = '',
    Object? novelId,
  }) async {
    return (await resolveWithLevel(
      mangaId: mangaId,
      sourceId: sourceId,
      sourceLanguage: sourceLanguage,
      novelId: novelId,
    )).profile;
  }

  static Future<ResolvedDictionaryProfile> resolveWithLevel({
    Object? mangaId,
    Object? sourceId,
    String sourceLanguage = '',
    Object? novelId,
  }) async {
    final profiles = await MiningPreferences.getDictionaryProfiles();
    final active = await MiningPreferences.getActiveDictionaryProfile();
    final overrideKeys = <DictionaryProfileResolutionLevel, String>{
      if (_hasIdentity(mangaId))
        DictionaryProfileResolutionLevel.manga: mangaOverrideKey(mangaId!),
      if (_hasIdentity(sourceId))
        DictionaryProfileResolutionLevel.source: sourceOverrideKey(sourceId!),
      if (_hasIdentity(novelId))
        DictionaryProfileResolutionLevel.novel: novelOverrideKey(novelId!),
    };
    final overrides = <DictionaryProfileResolutionLevel, String>{};
    for (final entry in overrideKeys.entries) {
      overrides[entry.key] =
          await MiningPreferences.getDictionaryProfileOverride(entry.value);
    }
    return resolveValues(
      profiles: profiles,
      activeProfile: active,
      mangaOverrideId: overrides[DictionaryProfileResolutionLevel.manga] ?? '',
      sourceOverrideId:
          overrides[DictionaryProfileResolutionLevel.source] ?? '',
      novelOverrideId: overrides[DictionaryProfileResolutionLevel.novel] ?? '',
      sourceLanguage: sourceLanguage,
    );
  }

  static Future<DictionaryProfile> resolveMiningContext(
    MiningContext? context,
  ) {
    return resolve(
      mangaId: context?.mangaId,
      sourceId: context?.sourceId,
      sourceLanguage: context?.sourceLanguage ?? '',
      novelId: context?.novelId,
    );
  }

  /// Pure form used by tests and by callers that already hold a preference
  /// snapshot. The ordered profile list makes duplicate-language behavior
  /// deterministic: the first matching profile wins.
  static ResolvedDictionaryProfile resolveValues({
    required List<DictionaryProfile> profiles,
    required DictionaryProfile activeProfile,
    String mangaOverrideId = '',
    String sourceOverrideId = '',
    String novelOverrideId = '',
    String sourceLanguage = '',
  }) {
    for (final candidate in <(DictionaryProfileResolutionLevel, String)>[
      (DictionaryProfileResolutionLevel.manga, mangaOverrideId),
      (DictionaryProfileResolutionLevel.source, sourceOverrideId),
      (DictionaryProfileResolutionLevel.novel, novelOverrideId),
    ]) {
      final match = _profileById(profiles, candidate.$2);
      if (match != null) return ResolvedDictionaryProfile(match, candidate.$1);
    }

    final language = sourceLanguage.trim().toLowerCase();
    if (language.isNotEmpty && language != 'all') {
      for (final profile in profiles) {
        if (profile.languageCode.toLowerCase() == language) {
          return ResolvedDictionaryProfile(
            profile,
            DictionaryProfileResolutionLevel.language,
          );
        }
      }
    }

    final active = _profileById(profiles, activeProfile.id);
    if (active != null) {
      return ResolvedDictionaryProfile(
        active,
        DictionaryProfileResolutionLevel.active,
      );
    }
    return ResolvedDictionaryProfile(
      profiles.firstOrNull ?? activeProfile,
      DictionaryProfileResolutionLevel.active,
    );
  }

  static DictionaryProfile? _profileById(
    List<DictionaryProfile> profiles,
    String id,
  ) {
    if (id.isEmpty) return null;
    for (final profile in profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  static bool _hasIdentity(Object? value) {
    if (value == null) return false;
    final text = value.toString();
    return text.isNotEmpty && text != '0';
  }
}
