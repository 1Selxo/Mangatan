import 'package:mangayomi/modules/more/settings/settings_index.dart';

/// Mangatan's own settings the search can find, beside upstream's
/// [settingsIndex]. Their screens are not translated yet, so neither are
/// these.
final mangatanSettingsIndex = <SettingsEntry>[
  for (final (title, subtitle) in const [
    ('Show OCR in reader', 'Recognize text on manga pages'),
    ('Recognition trigger', null),
    ('Parallel OCR tasks', 'Higher values use more power'),
    ('Detect text boxes before OCR', null),
    ('Show box outlines', null),
    ('Use Mokuro website OCR', 'Prefer saved OCR when available'),
    ('Lookup text on hover', 'Available on desktop pointer devices'),
    (
      'Panel-by-panel navigation',
      'Use on-device LiteRT panel and speech-bubble detection in paged '
          'reading modes',
    ),
    ('Panel detection model', null),
  ])
    SettingsEntry(
      title: (_) => title,
      subtitle: subtitle == null ? null : (_) => subtitle,
      section: (_) => 'OCR & panel navigation',
      route: '/ocrSettings',
    ),
];
