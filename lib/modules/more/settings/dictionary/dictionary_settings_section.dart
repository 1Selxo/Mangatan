enum DictionarySettingsSection {
  dictionariesAndAudio(
    title: 'Dictionaries & audio',
    summary: 'Import, order, enable',
  ),
  dictionaryPopup(title: 'Dictionary popup', summary: 'Layout, theme, OCR'),
  anki(title: 'Anki', summary: 'Deck, fields, export');

  const DictionarySettingsSection({required this.title, required this.summary});

  final String title;
  final String summary;
}
