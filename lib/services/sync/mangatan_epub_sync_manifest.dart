import 'dart:convert';

const mangatanEpubManifestFileName = 'Mangatan_epub_manifest_v1.json';
const mangatanEpubManifestProtocolVersion = 1;

class MangatanEpubManifest {
  const MangatanEpubManifest({
    this.protocolVersion = mangatanEpubManifestProtocolVersion,
    required this.generatedAtUtc,
    required this.deviceId,
    required this.entries,
  });

  factory MangatanEpubManifest.empty({required String deviceId}) =>
      MangatanEpubManifest(
        generatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
          0,
          isUtc: true,
        ),
        deviceId: deviceId,
        entries: const {},
      );

  factory MangatanEpubManifest.fromJson(Map<String, Object?> json) {
    final rawEntries = json['entries'];
    final entries = <String, MangatanEpubManifestEntry>{};
    if (rawEntries is List) {
      for (final raw in rawEntries.whereType<Map>()) {
        final entry = MangatanEpubManifestEntry.fromJson(
          raw.cast<String, Object?>(),
        );
        if (entry.stableNovelId.isNotEmpty) entries[entry.stableNovelId] = entry;
      }
    }
    return MangatanEpubManifest(
      protocolVersion:
          (json['protocolVersion'] as num?)?.toInt() ??
          mangatanEpubManifestProtocolVersion,
      generatedAtUtc:
          DateTime.tryParse(json['generatedAtUtc']?.toString() ?? '')
              ?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      deviceId: json['deviceId']?.toString() ?? '',
      entries: Map.unmodifiable(entries),
    );
  }

  factory MangatanEpubManifest.decode(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('EPUB manifest root must be an object');
    }
    final manifest = MangatanEpubManifest.fromJson(decoded);
    if (manifest.protocolVersion != mangatanEpubManifestProtocolVersion) {
      throw FormatException(
        'Unsupported EPUB manifest protocol ${manifest.protocolVersion}',
      );
    }
    return manifest;
  }

  final int protocolVersion;
  final DateTime generatedAtUtc;
  final String deviceId;
  final Map<String, MangatanEpubManifestEntry> entries;

  List<int> encode() => utf8.encode(
    const JsonEncoder.withIndent('  ').convert({
      'protocolVersion': protocolVersion,
      'generatedAtUtc': generatedAtUtc.toUtc().toIso8601String(),
      'deviceId': deviceId,
      'entries': [
        for (final entry in (entries.values.toList()
          ..sort((a, b) => a.stableNovelId.compareTo(b.stableNovelId))))
          entry.toJson(),
      ],
    }),
  );

  MangatanEpubManifest copyWith({
    DateTime? generatedAtUtc,
    String? deviceId,
    Map<String, MangatanEpubManifestEntry>? entries,
  }) => MangatanEpubManifest(
    protocolVersion: protocolVersion,
    generatedAtUtc: generatedAtUtc ?? this.generatedAtUtc,
    deviceId: deviceId ?? this.deviceId,
    entries: Map.unmodifiable(entries ?? this.entries),
  );

  MangatanEpubManifest mergeLocalEntries({
    required String deviceId,
    required Map<String, MangatanEpubManifestEntry> localEntries,
    required DateTime generatedAtUtc,
  }) => copyWith(
    deviceId: deviceId,
    generatedAtUtc: generatedAtUtc,
    entries: {...entries, ...localEntries},
  );
}

class MangatanEpubManifestEntry {
  const MangatanEpubManifestEntry({
    required this.stableNovelId,
    required this.sha256,
    required this.sizeBytes,
    required this.fileName,
    required this.title,
    this.author,
    this.lang,
    required this.updatedAtUtc,
    this.deleted = false,
  });

  factory MangatanEpubManifestEntry.fromJson(Map<String, Object?> json) =>
      MangatanEpubManifestEntry(
        stableNovelId: json['stableNovelId']?.toString() ?? '',
        sha256: json['sha256']?.toString() ?? '',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        fileName: json['fileName']?.toString() ?? 'book.epub',
        title: json['title']?.toString() ?? '',
        author: json['author']?.toString(),
        lang: json['lang']?.toString(),
        updatedAtUtc:
            DateTime.tryParse(json['updatedAtUtc']?.toString() ?? '')
                ?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        deleted: json['deleted'] == true,
      );

  final String stableNovelId;
  final String sha256;
  final int sizeBytes;
  final String fileName;
  final String title;
  final String? author;
  final String? lang;
  final DateTime updatedAtUtc;
  final bool deleted;

  Map<String, Object?> toJson() => {
    'stableNovelId': stableNovelId,
    'sha256': sha256,
    'sizeBytes': sizeBytes,
    'fileName': fileName,
    'title': title,
    if (author != null) 'author': author,
    if (lang != null) 'lang': lang,
    'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
    if (deleted) 'deleted': true,
  };
}
