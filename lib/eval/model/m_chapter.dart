class MChapter {
  String? name;

  String? url;

  String? dateUpload;

  String? scanlator;

  double? chapterNumber;

  bool? isFiller;

  String? thumbnailUrl;

  String? description;

  /// video size
  String? downloadSize;

  /// video duration
  String? duration;

  MChapter({
    this.name,
    this.url,
    this.dateUpload,
    this.scanlator,
    this.chapterNumber,
    this.isFiller = false,
    this.thumbnailUrl,
    this.description,
    this.downloadSize,
    this.duration,
  });
  factory MChapter.fromJson(Map<String, dynamic> json) {
    return MChapter(
      name: json['name'],
      url: json['url'],
      dateUpload: json['dateUpload'],
      scanlator: json['scanlator'],
      chapterNumber: (json['chapterNumber'] as num?)?.toDouble(),
      isFiller: json['isFiller'] ?? false,
      thumbnailUrl: json['thumbnailUrl'],
      description: json['description'],
      downloadSize: json['downloadSize'],
      duration: json['duration'],
    );
  }
  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'dateUpload': dateUpload,
    'scanlator': scanlator,
    'chapterNumber': chapterNumber,
    'isFiller': isFiller,
    'thumbnailUrl': thumbnailUrl,
    'description': description,
    'downloadSize': downloadSize,
    'duration': duration,
  };
}
