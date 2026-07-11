import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

enum TtsState { stopped, playing, paused }

/// Word-level progress info emitted during TTS playback.
class TtsWordProgress {
  final int paragraphIndex;
  final int startOffset;
  final int endOffset;
  final String word;
  const TtsWordProgress({
    required this.paragraphIndex,
    required this.startOffset,
    required this.endOffset,
    required this.word,
  });
}

class NovelTtsService {
  NovelTtsService._();
  static final NovelTtsService instance = NovelTtsService._();
  static const _manualInterruptionWindow = Duration(milliseconds: 500);
  bool get _isSupported => !Platform.isLinux;

  FlutterTts? _flutterTts;
  final _stateController = StreamController<TtsState>.broadcast();
  final _paragraphIndexController = StreamController<int>.broadcast();
  final _wordProgressController = StreamController<TtsWordProgress>.broadcast();

  Stream<TtsState> get stateStream => _stateController.stream;
  Stream<int> get paragraphIndexStream => _paragraphIndexController.stream;
  Stream<TtsWordProgress> get wordProgressStream =>
      _wordProgressController.stream;

  TtsState _state = TtsState.stopped;
  TtsState get state => _state;

  List<String> _paragraphs = [];
  List<String> get paragraphs => _paragraphs;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  int _currentWordStart = -1;
  int _currentWordEnd = -1;
  int _resumeOffset = 0;
  int _currentUtteranceOffset = 0;
  bool _pausedNatively = false;
  bool _hasStartedNativeSpeech = false;
  Future<void>? _stopInFlight;
  int _sessionGeneration = 0;

  double _speed = 0.5;
  double _pitch = 1.0;
  String? _language;
  DateTime? _manualInterruptionUntil;

  Future<void> _ensureInitialized() async {
    if (!_isSupported) return;
    if (_flutterTts != null) return;
    _flutterTts = FlutterTts();

    _flutterTts!.setCompletionHandler(() {
      if (_isManualInterruptionActive) return;
      _hasStartedNativeSpeech = false;
      _onParagraphComplete();
    });

    _flutterTts!.setCancelHandler(() {
      if (_isManualInterruptionActive) return;
      _hasStartedNativeSpeech = false;
      _setState(TtsState.stopped);
    });

    _flutterTts!.setErrorHandler((msg) {
      _hasStartedNativeSpeech = false;
      _setState(TtsState.stopped);
    });

    _flutterTts!.setProgressHandler((
      String text,
      int startOffset,
      int endOffset,
      String word,
    ) {
      if (_state == TtsState.playing) {
        final absoluteStart = startOffset + _currentUtteranceOffset;
        final absoluteEnd = endOffset + _currentUtteranceOffset;
        _currentWordStart = absoluteStart;
        _currentWordEnd = absoluteEnd;
        _wordProgressController.add(
          TtsWordProgress(
            paragraphIndex: _currentIndex,
            startOffset: absoluteStart,
            endOffset: absoluteEnd,
            word: word,
          ),
        );
      }
    });

    // flutter_tts 4.2.5's Windows plugin dereferences an unset native
    // completion result when stop() is called after initialization but before
    // speak(). Completion callbacks still work without awaiting the method
    // result, so keep Windows on the safe non-blocking path.
    await _flutterTts!.awaitSpeakCompletion(!Platform.isWindows);
  }

  void _setState(TtsState s) {
    _state = s;
    _stateController.add(s);
  }

  bool get _isManualInterruptionActive {
    final until = _manualInterruptionUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _markManualInterruption() {
    _manualInterruptionUntil = DateTime.now().add(_manualInterruptionWindow);
  }

  Future<void> _stopCurrentUtterance() async {
    final activeStop = _stopInFlight;
    if (activeStop != null) return activeStop;
    if (!_isSupported || !_hasStartedNativeSpeech) return;
    // Clear this before crossing the platform channel so dispose/skip cannot
    // issue a second native stop while the first one is still completing.
    _hasStartedNativeSpeech = false;
    _markManualInterruption();
    final tts = _flutterTts;
    if (tts == null) return;
    final stop = tts.stop().then<void>((_) {});
    _stopInFlight = stop;
    try {
      await stop;
    } finally {
      if (identical(_stopInFlight, stop)) _stopInFlight = null;
    }
  }

  void _emitIndex(int i) {
    _currentIndex = i;
    _paragraphIndexController.add(i);
  }

  void _resetWordProgress() {
    _currentWordStart = -1;
    _currentWordEnd = -1;
    _resumeOffset = 0;
    _currentUtteranceOffset = 0;
    _pausedNatively = false;
  }

  static const _blockSelector =
      'p, h1, h2, h3, h4, h5, h6, li, blockquote, div';

  List<String> extractParagraphs(String htmlContent) {
    final doc = html_parser.parse(htmlContent);
    final body = doc.body;
    if (body == null) return [];

    final text = body.text.trim();
    if (text.isEmpty) return [];

    final blocks = _getLeafBlocks(body);
    final paragraphs = <String>[];
    for (final block in blocks) {
      final t = block.text.trim();
      if (t.isNotEmpty) {
        paragraphs.add(t);
      }
    }

    // Fallback: if no block elements found, split by newlines
    if (paragraphs.isEmpty) {
      for (final line in text.split(RegExp(r'\n+'))) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          paragraphs.add(trimmed);
        }
      }
    }

    return paragraphs;
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    if (!_isSupported) return;
    await _ensureInitialized();
    await _flutterTts!.setSpeechRate(speed);
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    if (!_isSupported) return;
    await _ensureInitialized();
    await _flutterTts!.setPitch(pitch);
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    if (!_isSupported) return;
    await _ensureInitialized();
    await _flutterTts!.setLanguage(language);
  }

  Future<void> setVoice(Map<String, String> voice) async {
    if (!_isSupported) return;
    await _ensureInitialized();
    await _flutterTts!.setVoice(voice);
  }

  Future<List<dynamic>> getLanguages() async {
    if (!_isSupported) return [];
    await _ensureInitialized();
    return await _flutterTts!.getLanguages;
  }

  Future<List<dynamic>> getVoices() async {
    if (!_isSupported) return [];
    await _ensureInitialized();
    return await _flutterTts!.getVoices;
  }

  Future<void> speak(
    String htmlContent, {
    int startIndex = 0,
    int startOffset = 0,
  }) async {
    if (!_isSupported) {
      _paragraphs = [];
      _currentIndex = 0;
      _resetWordProgress();
      _setState(TtsState.stopped);
      return;
    }
    final session = ++_sessionGeneration;
    await _stopCurrentUtterance();
    if (session != _sessionGeneration) return;
    await _ensureInitialized();
    if (session != _sessionGeneration) return;
    _paragraphs = extractParagraphs(htmlContent);
    if (_paragraphs.isEmpty) return;

    _currentIndex = startIndex.clamp(0, _paragraphs.length - 1);
    _resetWordProgress();
    _resumeOffset = startOffset.clamp(0, _paragraphs[_currentIndex].length);
    _currentWordStart = _resumeOffset;
    _currentWordEnd = _resumeOffset;
    _currentUtteranceOffset = 0;

    await _flutterTts!.setSpeechRate(_speed);
    if (session != _sessionGeneration) return;
    await _flutterTts!.setPitch(_pitch);
    if (session != _sessionGeneration) return;
    if (_language != null) {
      await _flutterTts!.setLanguage(_language!);
      if (session != _sessionGeneration) return;
    }

    _setState(TtsState.playing);
    _emitIndex(_currentIndex);
    await _speakCurrent(session: session);
  }

  Future<void> _speakCurrent({int? fromOffset, int? session}) async {
    if (!_isSupported) return;
    final expectedSession = session ?? _sessionGeneration;
    final activeStop = _stopInFlight;
    if (activeStop != null) await activeStop;
    if (expectedSession != _sessionGeneration) return;
    if (_currentIndex >= _paragraphs.length) {
      _setState(TtsState.stopped);
      return;
    }
    if (_state != TtsState.playing) return;

    final paragraph = _paragraphs[_currentIndex];
    final startOffset = (fromOffset ?? _resumeOffset).clamp(
      0,
      paragraph.length,
    );
    if (startOffset >= paragraph.length) {
      _onParagraphComplete();
      return;
    }

    _currentUtteranceOffset = startOffset;
    _resumeOffset = startOffset;
    _hasStartedNativeSpeech = true;
    try {
      await _flutterTts!.speak(paragraph.substring(startOffset));
    } catch (_) {
      _hasStartedNativeSpeech = false;
      rethrow;
    }
  }

  void _onParagraphComplete() {
    if (_state != TtsState.playing) return;
    if (_currentIndex < _paragraphs.length - 1) {
      _currentIndex++;
      _resetWordProgress();
      _emitIndex(_currentIndex);
      _speakCurrent(session: _sessionGeneration);
    } else {
      _setState(TtsState.stopped);
    }
  }

  Future<void> pause() async {
    if (!_isSupported) return;
    if (_state == TtsState.playing) {
      final session = _sessionGeneration;
      if (_currentWordStart >= 0) {
        _resumeOffset = _currentWordStart;
      } else if (_currentWordEnd >= 0) {
        _resumeOffset = _currentWordEnd;
      }

      final result = await _flutterTts?.pause();
      if (session != _sessionGeneration) return;
      _setState(TtsState.paused);
      _pausedNatively = result == 1;

      if (!_pausedNatively) {
        await _stopCurrentUtterance();
      }
    }
  }

  Future<void> resume() async {
    if (!_isSupported) return;
    if (_state == TtsState.paused && _paragraphs.isNotEmpty) {
      final session = _sessionGeneration;
      _setState(TtsState.playing);
      _emitIndex(_currentIndex);
      if (_pausedNatively) {
        // flutter_tts resumes native paused speech when speak() is called
        // with the same text on Android, iOS and macOS.
        _pausedNatively = false;
        _hasStartedNativeSpeech = true;
        try {
          await _flutterTts!.speak(_paragraphs[_currentIndex]);
        } catch (_) {
          _hasStartedNativeSpeech = false;
          rethrow;
        }
      } else {
        await _speakCurrent(fromOffset: _resumeOffset, session: session);
      }
    }
  }

  Future<void> stop() async {
    _sessionGeneration++;
    _setState(TtsState.stopped);
    _currentIndex = 0;
    _resetWordProgress();
    _emitIndex(0);
    if (!_isSupported) {
      _paragraphs = [];
      return;
    }
    await _stopCurrentUtterance();
  }

  Future<void> skipNext() async {
    if (!_isSupported) return;
    if (_currentIndex < _paragraphs.length - 1) {
      final session = _sessionGeneration;
      await _stopCurrentUtterance();
      if (session != _sessionGeneration) return;
      _currentIndex++;
      _resetWordProgress();
      _emitIndex(_currentIndex);
      if (_state == TtsState.playing) {
        await _speakCurrent(session: session);
      }
    }
  }

  Future<void> skipPrevious() async {
    if (!_isSupported) return;
    if (_currentIndex > 0) {
      final session = _sessionGeneration;
      await _stopCurrentUtterance();
      if (session != _sessionGeneration) return;
      _currentIndex--;
      _resetWordProgress();
      _emitIndex(_currentIndex);
      if (_state == TtsState.playing) {
        await _speakCurrent(session: session);
      }
    }
  }

  Future<void> jumpTo(int index) async {
    if (!_isSupported) return;
    if (index >= 0 && index < _paragraphs.length) {
      final session = _sessionGeneration;
      await _stopCurrentUtterance();
      if (session != _sessionGeneration) return;
      _currentIndex = index;
      _resetWordProgress();
      _emitIndex(_currentIndex);
      if (_state == TtsState.playing) {
        await _speakCurrent(session: session);
      }
    }
  }

  Future<void> dispose() async {
    await stop();
    if (!_isSupported) {
      _paragraphs = [];
      _currentIndex = 0;
      _resetWordProgress();
      return;
    }
    _paragraphs = [];
    _currentIndex = 0;
    _resetWordProgress();
  }

  /// Returns the same HTML with `data-tts-index` on every readable block,
  /// `data-tts-active="true"` on the active paragraph, and an inline
  /// `<span data-tts-word="true">` around the word at [wordStart]..[wordEnd]
  /// within the active paragraph. Also returns the total block count.
  (String, int) highlightHtml(
    String htmlContent,
    int activeIndex, {
    int wordStart = -1,
    int wordEnd = -1,
  }) {
    final doc = html_parser.parse(htmlContent);
    final body = doc.body;
    if (body == null) return (htmlContent, 0);

    final blocks = _getReadableBlocks(body);
    if (blocks.isEmpty) return (htmlContent, 0);

    for (int i = 0; i < blocks.length; i++) {
      blocks[i].attributes['data-tts-index'] = '$i';
      if (i == activeIndex) {
        blocks[i].attributes['data-tts-active'] = 'true';
        // Inject word-level highlight if offsets are valid.
        if (wordStart >= 0 && wordEnd > wordStart) {
          _highlightWordInElement(blocks[i], wordStart, wordEnd);
        }
      } else {
        blocks[i].attributes.remove('data-tts-active');
      }
    }

    return (doc.outerHtml, blocks.length);
  }

  /// Walk the text nodes of [element] and wrap the character range
  /// [startOffset]..[endOffset] (in plain-text coordinates) with a
  /// `<span data-tts-word="true">`.
  void _highlightWordInElement(
    dom.Element element,
    int startOffset,
    int endOffset,
  ) {
    final textNodes = <dom.Text>[];
    _collectTextNodes(element, textNodes);

    // Account for leading whitespace trimmed in extractParagraphs.
    final fullText = element.text;
    final trimmedText = fullText.trimLeft();
    final leadingOffset = fullText.length - trimmedText.length;
    final adjStart = startOffset + leadingOffset;
    final adjEnd = endOffset + leadingOffset;

    int currentOffset = 0;
    for (final textNode in textNodes) {
      final nodeText = textNode.text;
      final nodeStart = currentOffset;
      final nodeEnd = currentOffset + nodeText.length;

      // Check whether the word range overlaps this text node.
      if (adjStart < nodeEnd && adjEnd > nodeStart) {
        final localStart = math.max(0, adjStart - nodeStart);
        final localEnd = math.min(nodeText.length, adjEnd - nodeStart);

        final before = nodeText.substring(0, localStart);
        final word = nodeText.substring(localStart, localEnd);
        final after = nodeText.substring(localEnd);

        final parent = textNode.parent;
        if (parent == null) {
          currentOffset = nodeEnd;
          continue;
        }

        final idx = parent.nodes.indexOf(textNode);
        parent.nodes.removeAt(idx);

        int insertAt = idx;
        if (before.isNotEmpty) {
          parent.nodes.insert(insertAt, dom.Text(before));
          insertAt++;
        }

        final span = dom.Element.tag('span');
        span.attributes['data-tts-word'] = 'true';
        span.append(dom.Text(word));
        parent.nodes.insert(insertAt, span);
        insertAt++;

        if (after.isNotEmpty) {
          parent.nodes.insert(insertAt, dom.Text(after));
        }

        // If the word is fully within this node we're done;
        // otherwise continue to wrap remaining nodes.
        if (adjEnd <= nodeEnd) break;
      }

      currentOffset = nodeEnd;
    }
  }

  /// Recursively collect all [dom.Text] nodes under [node] in DOM order.
  void _collectTextNodes(dom.Node node, List<dom.Text> result) {
    if (node is dom.Text) {
      result.add(node);
    } else {
      for (final child in node.nodes.toList()) {
        _collectTextNodes(child, result);
      }
    }
  }

  List<dom.Element> _getReadableBlocks(dom.Element root) {
    return _getLeafBlocks(root);
  }

  /// Return only "leaf" block elements — blocks that don't contain other
  /// matching block children with text. This prevents a wrapper `<div>`
  /// from being treated as a single paragraph covering the whole chapter.
  List<dom.Element> _getLeafBlocks(dom.Element root) {
    final all = root.querySelectorAll(_blockSelector);
    final allSet = all.toSet();
    final blocks = <dom.Element>[];
    for (final el in all) {
      final t = el.text.trim();
      if (t.isEmpty) continue;
      // Skip this element if it has a descendant block that also has text.
      final childBlocks = el.querySelectorAll(_blockSelector);
      final hasChildBlock = childBlocks.any(
        (child) =>
            child != el &&
            allSet.contains(child) &&
            child.text.trim().isNotEmpty,
      );
      if (!hasChildBlock) {
        blocks.add(el);
      }
    }
    return blocks;
  }
}
