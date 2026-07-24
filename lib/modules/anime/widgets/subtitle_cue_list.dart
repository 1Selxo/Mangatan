import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
    required this.onSelect,
    required this.onDismiss,
  });

  final List<AnimeSubtitleCue> cues;
  final ValueListenable<Duration> position;
  final ValueChanged<AnimeSubtitleCue> onSelect;
  final VoidCallback onDismiss;

  @override
  State<AnimeSubtitleListPanel> createState() => _AnimeSubtitleListPanelState();
}

class _AnimeSubtitleListPanelState extends State<AnimeSubtitleListPanel> {
  final ScrollController _scrollController = ScrollController();
  int? _lastActive;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _centerActive(int index) {
    if (_lastActive == index || !_scrollController.hasClients) return;
    _lastActive = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      const estimatedHeight = 66.0;
      final target =
          index * estimatedHeight -
          _scrollController.position.viewportDimension / 2;
      _scrollController.animateTo(
        target.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
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
                        trailing: IconButton(
                          onPressed: widget.onDismiss,
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white24),
                      Expanded(
                        child: ValueListenableBuilder<Duration>(
                          valueListenable: widget.position,
                          builder: (context, position, _) {
                            final active = widget.cues.lastIndexWhere(
                              (cue) => cue.contains(position),
                            );
                            if (active >= 0) _centerActive(active);
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
                            return ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemCount: widget.cues.length,
                              itemBuilder: (context, index) {
                                final cue = widget.cues[index];
                                final selected = index == active;
                                return InkWell(
                                  onTap: () => widget.onSelect(cue),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                              .withValues(alpha: 0.58)
                                        : Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      cue.text,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black,
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
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
