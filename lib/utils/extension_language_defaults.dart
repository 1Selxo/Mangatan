import 'dart:ui';

String normalizeExtensionLanguageTag(String? language) {
  return (language ?? '').trim().replaceAll('_', '-').toLowerCase();
}

bool shouldEnableExtensionLanguageByDefault(
  String? sourceLanguage,
  Iterable<Locale> deviceLocales,
) {
  final sourceTag = normalizeExtensionLanguageTag(sourceLanguage);
  if (sourceTag == 'all') return true;
  if (sourceTag.isEmpty) return false;

  return deviceLocales.any((locale) {
    final languageCode = normalizeExtensionLanguageTag(locale.languageCode);
    final localeTag = normalizeExtensionLanguageTag(locale.toLanguageTag());
    return sourceTag == languageCode || sourceTag == localeTag;
  });
}

bool extensionLanguageEnabledForNewSource(
  String? sourceLanguage, {
  required Map<String, bool> savedLanguageStates,
  required Iterable<Locale> deviceLocales,
}) {
  final language = normalizeExtensionLanguageTag(sourceLanguage);
  return savedLanguageStates[language] ??
      shouldEnableExtensionLanguageByDefault(sourceLanguage, deviceLocales);
}

bool extensionLanguageEnabledForCatalogSource(
  String? sourceLanguage, {
  required bool isInstalled,
  required bool? currentValue,
  required Map<String, bool> savedLanguageStates,
  required Iterable<Locale> deviceLocales,
}) {
  // Installed sources can be enabled or disabled individually. Catalog-only
  // entries have no individual control, so keep them aligned with the
  // language-group switch, including records created by older app versions.
  if (isInstalled) {
    return currentValue ??
        shouldEnableExtensionLanguageByDefault(sourceLanguage, deviceLocales);
  }
  return extensionLanguageEnabledForNewSource(
    sourceLanguage,
    savedLanguageStates: savedLanguageStates,
    deviceLocales: deviceLocales,
  );
}
