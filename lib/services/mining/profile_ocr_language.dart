/// OCR languages supported by Chimahon's profile-driven OCR pipeline.
const profileOcrLanguages = <String>{
  'ja',
  'en',
  'zh',
  'ko',
  'ar',
  'es',
  'fr',
  'de',
  'pt',
  'bg',
  'cs',
  'da',
  'el',
  'et',
  'fa',
  'fi',
  'he',
  'hi',
  'hu',
  'id',
  'it',
  'la',
  'lo',
  'lv',
  'ka',
  'kn',
  'km',
  'mn',
  'mt',
  'nl',
  'no',
  'pl',
  'ro',
  'ru',
  'sv',
  'th',
  'tl',
  'tr',
  'uk',
  'vi',
  'cy',
  'yue',
};

/// Selects the OCR language from the resolved dictionary profile.
///
/// Chimahon falls back to Japanese when a profile uses a code its OCR engine
/// does not support. Mangatan retains its existing OCR preference as an
/// optional fallback for callers that explicitly provide it.
String profileOcrLanguage(String profileLanguage, {String fallback = 'ja'}) {
  final normalized = profileLanguage.toLowerCase();
  if (profileOcrLanguages.contains(normalized)) return normalized;
  final normalizedFallback = fallback.trim().toLowerCase();
  return profileOcrLanguages.contains(normalizedFallback)
      ? normalizedFallback
      : 'ja';
}

/// Mirrors Chimahon's source/profile language guard. Mixed or unknown values
/// do not restrict OCR; otherwise both base language codes must agree.
bool isProfileOcrAllowed({
  required String sourceLanguage,
  required String profileLanguage,
}) {
  final source = _baseLanguage(sourceLanguage);
  if (_isMixedOrUnknown(source)) return true;
  final profile = _baseLanguage(profileLanguage);
  if (_isMixedOrUnknown(profile)) return true;
  return source == profile;
}

String _baseLanguage(String value) =>
    value.trim().split(RegExp('[-_]')).first.toLowerCase();

bool _isMixedOrUnknown(String value) =>
    value.isEmpty || const {'all', 'other', 'multi', 'unknown'}.contains(value);
