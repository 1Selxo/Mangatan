import 'package:flutter_kiwi_nlp/flutter_kiwi_nlp.dart';

class KoreanMorpheme {
  const KoreanMorpheme({
    required this.form,
    required this.tag,
    required this.start,
    required this.length,
  });

  final String form;
  final String tag;
  final int start;
  final int length;
}

abstract interface class KoreanMorphologyAnalyzer {
  Future<List<KoreanMorpheme>> analyze(String text);
}

class KiwiKoreanAnalyzer implements KoreanMorphologyAnalyzer {
  KiwiKoreanAnalyzer._();

  static final KiwiKoreanAnalyzer instance = KiwiKoreanAnalyzer._();

  KiwiAnalyzer? _analyzer;
  Future<KiwiAnalyzer>? _initializing;

  Future<KiwiAnalyzer> _getAnalyzer() async {
    final current = _analyzer;
    if (current != null) return current;
    final pending = _initializing ??= KiwiAnalyzer.create();
    try {
      return _analyzer = await pending;
    } finally {
      _initializing = null;
    }
  }

  @override
  Future<List<KoreanMorpheme>> analyze(String text) async {
    final analyzer = await _getAnalyzer();
    final result = await analyzer.analyze(text);
    if (result.candidates.isEmpty) return const [];
    return result.candidates.first.tokens
        .map(
          (token) => KoreanMorpheme(
            form: token.form,
            tag: token.tag,
            start: token.start,
            length: token.length,
          ),
        )
        .toList(growable: false);
  }
}
