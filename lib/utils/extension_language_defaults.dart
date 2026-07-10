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
