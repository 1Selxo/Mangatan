import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/manga/detail/manga_details_view.dart';

void main() {
  test('detail metadata falls back for missing and empty values', () {
    expect(mangaDetailValueOrFallback(null, 'Unknown'), 'Unknown');
    expect(mangaDetailValueOrFallback('', 'Unknown'), 'Unknown');
    expect(mangaDetailValueOrFallback('Author', 'Unknown'), 'Author');
  });
}
