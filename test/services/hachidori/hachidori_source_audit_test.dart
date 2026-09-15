import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all popup lookup, style, and media consumers use the read facade', () {
    const paths = [
      'lib/modules/mining/widgets/dictionary_glossary.dart',
      'lib/modules/mining/widgets/dictionary_lookup_popup.dart',
      'lib/modules/mining/widgets/hoshi_dictionary_popup.dart',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('HoshidictsLookupBackend.instance')),
        reason: path,
      );
      expect(source, contains('DictionaryReadFacade.instance'), reason: path);
    }
  });

  test(
    'production Hachidori code contains only the six typed read messages',
    () {
      const allowed = {
        'hd_lookup',
        'hd_lookup_dictionary',
        'hd_kanji',
        'hd_styles',
        'hd_media',
        'hd_status',
      };
      final serviceDirectory = Directory('lib/services/hachidori');
      final messages = <String>{};
      for (final file
          in serviceDirectory
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        for (final match in RegExp(
          r'''['"](hd_[a-z_]+)['"]''',
        ).allMatches(source)) {
          messages.add(match.group(1)!);
        }
        expect(
          source,
          isNot(matches(RegExp(r'\bforward\s*\('))),
          reason: file.path,
        );
      }
      expect(messages, allowed);
    },
  );
}
