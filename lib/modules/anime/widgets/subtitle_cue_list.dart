import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class AnimeSubtitleCue {
  const AnimeSubtitleCue({
    required this.index,
    required this.text,
    required this.start,
    required this.end,
  });

  final int index;
  final String text;
  final Duration start;
  final Duration end;

  bool contains(Duration position) => position >= start && position <= end;
}

int? subtitleDelayForAdjacentCue({
  required List<AnimeSubtitleCue> cues,
  required Duration playbackPosition,
  required int currentDelayMs,
  required bool next,
}) {
  if (cues.isEmpty) return null;
  final subtitlePosition =
      playbackPosition - Duration(milliseconds: currentDelayMs);
  const tolerance = Duration(milliseconds: 2);
  AnimeSubtitleCue? target;
  if (next) {
    for (final cue in cues) {
      if (cue.start > subtitlePosition + tolerance) {
        target = cue;
        break;
      }
    }
  } else {
    for (final cue in cues.reversed) {
      if (cue.start < subtitlePosition - tolerance) {
        target = cue;
        break;
      }
    }
  }
  if (target == null) return null;
  return playbackPosition.inMilliseconds - target.start.inMilliseconds;
}

Duration subtitleCuePlaybackTime(
  AnimeSubtitleCue cue, {
  required int subtitleDelayMs,
}) {
  final delayed = cue.start + Duration(milliseconds: subtitleDelayMs);
  return delayed.isNegative ? Duration.zero : delayed;
}

int activeSubtitleCueIndex({
  required List<AnimeSubtitleCue> cues,
  required Duration playbackPosition,
  required int subtitleDelayMs,
}) {
  final subtitlePosition =
      playbackPosition - Duration(milliseconds: subtitleDelayMs);
  return cues.lastIndexWhere((cue) => cue.contains(subtitlePosition));
}

List<int> findSubtitleCueMatches({
  required List<AnimeSubtitleCue> cues,
  required String query,
  required bool ignoreWhitespace,
}) {
  String normalize(String value) {
    final lower = value.toLowerCase();
    return ignoreWhitespace ? lower.replaceAll(RegExp(r'\s+'), '') : lower;
  }

  final normalizedQuery = normalize(query.trim());
  if (normalizedQuery.isEmpty) return const [];
  return [
    for (var index = 0; index < cues.length; index++)
      if (normalize(cues[index].text).contains(normalizedQuery)) index,
  ];
}

String formatSubtitleCueTimestamp(Duration value) {
  final totalSeconds = value.inSeconds.clamp(0, 359999);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

List<AnimeSubtitleCue> parseAnimeSubtitleFile(File file) {
  if (!file.existsSync()) return const [];
  return parseAnimeSubtitleContent(file.path, file.readAsStringSync());
}

List<AnimeSubtitleCue> parseAnimeSubtitleContent(
  String fileName,
  String content,
) {
  final normalized = content
      .replaceFirst('\ufeff', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final lower = fileName.toLowerCase();
  final cues =
      lower.endsWith('.ass') ||
          lower.endsWith('.ssa') ||
          normalized.toLowerCase().contains('[events]')
      ? _parseAss(normalized)
      : _parseSrtOrVtt(normalized);
  return [
    for (var index = 0; index < cues.length; index++)
      AnimeSubtitleCue(
        index: index,
        text: cues[index].text,
        start: cues[index].start,
        end: cues[index].end,
      ),
  ];
}

List<AnimeSubtitleCue> _parseSrtOrVtt(String content) {
  final cues = <AnimeSubtitleCue>[];
  for (final block in content.split(RegExp(r'\n\s*\n'))) {
    final lines = block
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line != 'WEBVTT')
        .toList();
    final timeIndex = lines.indexWhere((line) => line.contains('-->'));
    if (timeIndex < 0) continue;
    final times = lines[timeIndex].split('-->');
    if (times.length < 2) continue;
    final start = _parseTimestamp(times[0]);
    final end = _parseTimestamp(times[1]);
    final text = _cleanSubtitleText(lines.skip(timeIndex + 1).join('\n'));
    if (start == null || text.isEmpty) continue;
    cues.add(
      AnimeSubtitleCue(
        index: cues.length,
        text: text,
        start: start,
        end: end != null && end > start
            ? end
            : start + const Duration(seconds: 5),
      ),
    );
  }
  return cues;
}

List<AnimeSubtitleCue> _parseAss(String content) {
  final cues = <AnimeSubtitleCue>[];
  var inEvents = false;
  var format = <String>[
    'layer',
    'start',
    'end',
    'style',
    'name',
    'marginl',
    'marginr',
    'marginv',
    'effect',
    'text',
  ];
  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.toLowerCase() == '[events]') {
      inEvents = true;
      continue;
    }
    if (line.startsWith('[') && line.endsWith(']')) {
      inEvents = false;
      continue;
    }
    if (!inEvents) continue;
    if (line.toLowerCase().startsWith('format:')) {
      format = line
          .substring(line.indexOf(':') + 1)
          .split(',')
          .map((value) => value.trim().toLowerCase())
          .toList();
      continue;
    }
    if (!line.toLowerCase().startsWith('dialogue:')) continue;
    final startIndex = format.indexOf('start');
    final endIndex = format.indexOf('end');
    final textIndex = format.indexOf('text');
    if (startIndex < 0 || endIndex < 0 || textIndex < 0) continue;
    final values = line.substring(line.indexOf(':') + 1).trimLeft().split(',');
    if (values.length < format.length) continue;
    if (values.length > format.length) {
      final tail = values.sublist(textIndex).join(',');
      values
        ..removeRange(textIndex, values.length)
        ..add(tail);
    }
    final start = _parseTimestamp(values[startIndex]);
    final end = _parseTimestamp(values[endIndex]);
    final text = _cleanSubtitleText(values[textIndex]);
    if (start == null || text.isEmpty) continue;
    cues.add(
      AnimeSubtitleCue(
        index: cues.length,
        text: text,
        start: start,
        end: end != null && end > start
            ? end
            : start + const Duration(seconds: 5),
      ),
    );
  }
  return cues;
}

Duration? _parseTimestamp(String raw) {
  final token = raw.trim().split(RegExp(r'\s+')).first.replaceAll(',', '.');
  final parts = token.split(':');
  if (parts.length < 2) return null;
  final seconds = double.tryParse(parts.last);
  final minutes = int.tryParse(parts[parts.length - 2]);
  final hours = parts.length > 2 ? int.tryParse(parts[parts.length - 3]) : 0;
  if (seconds == null || minutes == null || hours == null) return null;
  return Duration(
    milliseconds: (((hours * 60 + minutes) * 60 + seconds) * 1000).round(),
  );
}

String _cleanSubtitleText(String value) => value
    .replaceAll(RegExp(r'\{[^}]*\}'), '')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll(r'\N', '\n')
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\h', ' ')
    .trim();

class AnimeSubtitleListPanel extends StatefulWidget {
  const AnimeSubtitleListPanel({
    super.key,
    required this.cues,
    required this.position,
    required this.subtitleDelayMs,
    required this.onSelect,
    required this.onDismiss,
  });

  final List<AnimeSubtitleCue> cues;
  final ValueListenable<Duration> position;
  final int subtitleDelayMs;
  final ValueChanged<AnimeSubtitleCue> onSelect;
  final VoidCallback onDismiss;

  @override
  State<AnimeSubtitleListPanel> createState() => _AnimeSubtitleListPanelState();
}

class _AnimeSubtitleListPanelState extends State<AnimeSubtitleListPanel> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final TextEditingController _searchController = TextEditingController();
  int? _lastActive;
  int _matchCursor = 0;
  bool _ignoreWhitespace = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _centerActive(int index) {
    if (_lastActive == index) return;
    _lastActive = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_itemScrollController.isAttached) return;
      unawaited(
        _itemScrollController.scrollTo(
          index: index,
          alignment: 0.5,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  List<int> get _matches => findSubtitleCueMatches(
    cues: widget.cues,
    query: _searchController.text,
    ignoreWhitespace: _ignoreWhitespace,
  );

  void _searchChanged(String _) {
    setState(() => _matchCursor = 0);
    _jumpToCurrentMatch();
  }

  void _stepMatch(int delta) {
    final matches = _matches;
    if (matches.isEmpty) return;
    setState(() {
      _matchCursor = (_matchCursor + delta) % matches.length;
      if (_matchCursor < 0) _matchCursor += matches.length;
    });
    _jumpToCurrentMatch();
  }

  void _jumpToCurrentMatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final matches = _matches;
      if (!mounted || matches.isEmpty || !_itemScrollController.isAttached) {
        return;
      }
      final cursor = _matchCursor.clamp(0, matches.length - 1);
      unawaited(
        _itemScrollController.scrollTo(
          index: matches[cursor],
          alignment: 0.35,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  void _toggleIgnoreWhitespace() {
    setState(() {
      _ignoreWhitespace = !_ignoreWhitespace;
      _matchCursor = 0;
    });
    _jumpToCurrentMatch();
  }

  Widget _buildSearchBar(BuildContext context, List<int> matches) {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final matchLabel = !hasQuery
        ? '${widget.cues.length} lines'
        : matches.isEmpty
        ? 'No matches'
        : '${_matchCursor + 1} of ${matches.length}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search subtitles',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    suffixIcon: hasQuery
                        ? IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              _searchChanged('');
                            },
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white70,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white10,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _searchChanged,
                  onSubmitted: (_) => _stepMatch(1),
                ),
              ),
              IconButton(
                tooltip: _ignoreWhitespace
                    ? 'Whitespace is ignored'
                    : 'Ignore whitespace',
                onPressed: _toggleIgnoreWhitespace,
                icon: Icon(
                  Icons.space_bar_rounded,
                  color: _ignoreWhitespace
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white70,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (hasQuery) ...[
                IconButton(
                  tooltip: 'Previous match',
                  onPressed: matches.isEmpty ? null : () => _stepMatch(-1),
                  icon: const Icon(
                    Icons.keyboard_arrow_up,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  tooltip: 'Next match',
                  onPressed: matches.isEmpty ? null : () => _stepMatch(1),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                matchLabel,
                textAlign: TextAlign.end,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCueRow({
    required BuildContext context,
    required int index,
    required int active,
    required int? focusedMatch,
  }) {
    final cue = widget.cues[index];
    final selected = index == active;
    final searchSelected = index == focusedMatch;
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => widget.onSelect(cue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.58)
              : searchSelected
              ? colorScheme.secondary.withValues(alpha: 0.28)
              : Colors.transparent,
          border: searchSelected
              ? Border(left: BorderSide(color: colorScheme.secondary, width: 3))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Text(
                formatSubtitleCueTimestamp(
                  subtitleCuePlaybackTime(
                    cue,
                    subtitleDelayMs: widget.subtitleDelayMs,
                  ),
                ),
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white60,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                cue.text,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  height: 1.3,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    final focusedMatch = matches.isEmpty
        ? null
        : matches[_matchCursor.clamp(0, matches.length - 1)];
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: SafeArea(
                child: Container(
                  width:
                      MediaQuery.sizeOf(context).width.clamp(280, 430) * 0.92,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.format_list_bulleted_rounded,
                          color: Colors.white,
                        ),
                        title: const Text(
                          'Subtitle list',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          widget.subtitleDelayMs == 0
                              ? 'Tap a line to seek'
                              : 'Tap to seek • ${widget.subtitleDelayMs > 0 ? '+' : ''}${widget.subtitleDelayMs} ms delay',
                          style: const TextStyle(color: Colors.white60),
                        ),
                        trailing: IconButton(
                          onPressed: widget.onDismiss,
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white24),
                      _buildSearchBar(context, matches),
                      const Divider(height: 1, color: Colors.white24),
                      Expanded(
                        child: ValueListenableBuilder<Duration>(
                          valueListenable: widget.position,
                          builder: (context, position, _) {
                            final active = activeSubtitleCueIndex(
                              cues: widget.cues,
                              playbackPosition: position,
                              subtitleDelayMs: widget.subtitleDelayMs,
                            );
                            if (active >= 0 && _searchController.text.isEmpty) {
                              _centerActive(active);
                            }
                            if (widget.cues.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'Subtitle lines will appear here',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              );
                            }
                            return ScrollablePositionedList.builder(
                              itemScrollController: _itemScrollController,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemCount: widget.cues.length,
                              itemBuilder: (context, index) => _buildCueRow(
                                context: context,
                                index: index,
                                active: active,
                                focusedMatch: focusedMatch,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
