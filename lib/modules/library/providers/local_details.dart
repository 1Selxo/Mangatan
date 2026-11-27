import 'dart:convert';

import 'package:mangayomi/models/manga.dart';

/// A local series' metadata file, read the way both formats write it.
///
/// Mihon's local source uses `details.json` with `title` and its own status
/// codes, often as strings (https://mihon.app/docs/guides/local-source/advanced).
/// Mangayomi's local source reads any `.json` with the app's own field names,
/// `name` and `status` as a position in [Status]. Both are accepted: keys of
/// either format, numbers with or without quotes, and a genre list or a
/// comma-separated genre string. A field the file does not have is null, so
/// it never blanks what the series already shows.
class LocalDetails {
  const LocalDetails({
    this.title,
    this.author,
    this.artist,
    this.description,
    this.genres,
    this.status,
  });

  final String? title;
  final String? author;
  final String? artist;
  final String? description;
  final List<String>? genres;
  final Status? status;

  /// Parses [source], the contents of the file named [fileName]. Throws a
  /// [FormatException] whose message says what is wrong in words a person
  /// can act on.
  factory LocalDetails.parse(String source, {required String fileName}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('not valid JSON (${e.message})');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('expected an object { ... }');
    }
    final data = decoded;
    String? text(String key) {
      final value = data[key];
      if (value == null) return null;
      if (value is String) return value.trim().isEmpty ? null : value.trim();
      if (value is num || value is bool) return '$value';
      throw FormatException('"$key" should be text');
    }

    final mihon =
        fileName.toLowerCase() == 'details.json' ||
        (data.containsKey('title') && !data.containsKey('name'));
    return LocalDetails(
      title: text('name') ?? text('title'),
      author: text('author'),
      artist: text('artist'),
      description: text('description'),
      genres: _genres(data['genre'] ?? data['genres']),
      status: _status(data['status'], mihon: mihon),
    );
  }

  static List<String>? _genres(Object? value) {
    if (value == null) return null;
    final items = switch (value) {
      String s => s.split(','),
      List l => l.map((e) => '$e'),
      _ => throw const FormatException('"genre" should be a list of text'),
    };
    return [
      for (final genre in items)
        if (genre.trim().isNotEmpty) genre.trim(),
    ];
  }

  static Status? _status(Object? value, {required bool mihon}) {
    if (value == null) return null;
    final code = switch (value) {
      int n => n,
      double d when d == d.roundToDouble() => d.toInt(),
      String s => int.tryParse(s.trim()),
      _ => null,
    };
    if (code == null) {
      throw FormatException('"status" should be a number, not "$value"');
    }
    if (mihon) {
      return switch (code) {
        1 => Status.ongoing,
        2 => Status.completed,
        4 => Status.publishingFinished,
        5 => Status.canceled,
        6 => Status.onHiatus,
        // 0 unknown, 3 licensed (no equivalent here), anything newer.
        _ => Status.unknown,
      };
    }
    return code >= 0 && code < Status.values.length
        ? Status.values[code]
        : Status.unknown;
  }
}
