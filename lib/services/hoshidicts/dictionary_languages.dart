class DictionaryLanguage {
  const DictionaryLanguage(this.code, this.name);

  final String code;
  final String name;
}

/// Languages exposed by Yomitan, with Mangatan's existing Japanese and Korean
/// implementations kept at the top of the selector.
const dictionaryLanguages = <DictionaryLanguage>[
  DictionaryLanguage('ja', 'Japanese'),
  DictionaryLanguage('ko', 'Korean'),
  DictionaryLanguage('aii', 'Assyrian Neo-Aramaic'),
  DictionaryLanguage('ar', 'Arabic (MSA)'),
  DictionaryLanguage('arz', 'Arabic (Egyptian)'),
  DictionaryLanguage('be', 'Belarusian'),
  DictionaryLanguage('bg', 'Bulgarian'),
  DictionaryLanguage('yue', 'Cantonese'),
  DictionaryLanguage('zh', 'Chinese'),
  DictionaryLanguage('cs', 'Czech'),
  DictionaryLanguage('da', 'Danish'),
  DictionaryLanguage('nl', 'Dutch'),
  DictionaryLanguage('en', 'English'),
  DictionaryLanguage('eo', 'Esperanto'),
  DictionaryLanguage('et', 'Estonian'),
  DictionaryLanguage('fa', 'Persian'),
  DictionaryLanguage('fi', 'Finnish'),
  DictionaryLanguage('fr', 'French'),
  DictionaryLanguage('ka', 'Georgian'),
  DictionaryLanguage('de', 'German'),
  DictionaryLanguage('el', 'Greek'),
  DictionaryLanguage('grc', 'Ancient Greek'),
  DictionaryLanguage('haw', 'Hawaiian'),
  DictionaryLanguage('he', 'Hebrew'),
  DictionaryLanguage('hi', 'Hindi'),
  DictionaryLanguage('hu', 'Hungarian'),
  DictionaryLanguage('id', 'Indonesian'),
  DictionaryLanguage('ga', 'Irish'),
  DictionaryLanguage('it', 'Italian'),
  DictionaryLanguage('kn', 'Kannada'),
  DictionaryLanguage('km', 'Khmer'),
  DictionaryLanguage('lo', 'Lao'),
  DictionaryLanguage('la', 'Latin'),
  DictionaryLanguage('lv', 'Latvian'),
  DictionaryLanguage('mt', 'Maltese'),
  DictionaryLanguage('mn', 'Mongolian'),
  DictionaryLanguage('no', 'Norwegian'),
  DictionaryLanguage('sga', 'Old Irish'),
  DictionaryLanguage('pl', 'Polish'),
  DictionaryLanguage('pt', 'Portuguese'),
  DictionaryLanguage('ro', 'Romanian'),
  DictionaryLanguage('ru', 'Russian'),
  DictionaryLanguage('gd', 'Scottish Gaelic'),
  DictionaryLanguage('sh', 'Serbo-Croatian'),
  DictionaryLanguage('sq', 'Albanian'),
  DictionaryLanguage('es', 'Spanish'),
  DictionaryLanguage('sv', 'Swedish'),
  DictionaryLanguage('tl', 'Tagalog'),
  DictionaryLanguage('th', 'Thai'),
  DictionaryLanguage('tok', 'Toki Pona'),
  DictionaryLanguage('tr', 'Turkish'),
  DictionaryLanguage('uk', 'Ukrainian'),
  DictionaryLanguage('eu', 'Basque'),
  DictionaryLanguage('vi', 'Vietnamese'),
  DictionaryLanguage('cy', 'Welsh'),
  DictionaryLanguage('yi', 'Yiddish'),
];

final supportedDictionaryLanguageCodes = <String>{
  for (final language in dictionaryLanguages) language.code,
};

String normalizeDictionaryLanguage(String? value) =>
    supportedDictionaryLanguageCodes.contains(value) ? value! : 'ja';

String dictionaryLanguageName(String code) => dictionaryLanguages
    .firstWhere(
      (language) => language.code == code,
      orElse: () => dictionaryLanguages.first,
    )
    .name;
