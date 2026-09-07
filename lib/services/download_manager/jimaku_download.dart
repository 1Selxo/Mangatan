import 'dart:io';

import 'package:mangayomi/services/mining/jimaku_service.dart';

/// The same persistent sidecar directory read by getVideoList for offline video.
Future<List<File>> downloadJimakuSidecars({
  required JimakuSubtitleService service,
  required String apiKey,
  required JimakuMediaGuess guess,
  required String chapterDirectory,
}) async {
  // Without an episode match, the API can return an entire series archive.
  if (apiKey.trim().isEmpty ||
      guess.title.trim().isEmpty ||
      guess.episode == null) {
    return [];
  }
  final entries = await service.searchEntries(
    apiKey: apiKey,
    query: guess.title,
  );
  final entry = selectBestJimakuEntry(entries, guess.title);
  if (entry == null) return [];
  final files = await service.matchingFiles(
    apiKey: apiKey,
    entry: entry,
    guess: guess,
  );
  return service.downloadFiles(
    apiKey: apiKey,
    files: files,
    outputDirectory: Directory('${chapterDirectory}_subtitles'),
  );
}
