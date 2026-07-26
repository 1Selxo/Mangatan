import 'package:isar_community/isar.dart';
import 'package:mangayomi/models/chapter.dart';
part 'manga.g.dart';

@collection
@Name("Manga")
class Manga {
  Id? id;

  String? name;

  /// Title reported by the source before any local display-title override.
  String? sourceTitle;

  String? link;

  String? imageUrl;

  String? description;

  String? author;

  String? artist;

  @enumerated
  late Status status;

  bool? isManga;

  @enumerated
  late ItemType itemType;

  List<String>? genre;

  bool? favorite;

  /// Unix epoch seconds of the last library favorite-state change.
  ///
  /// Chimahon persists this separately from general record updates so an
  /// unfavorite can be synchronized as a tombstone.
  int? favoriteModifiedAt;

  String? source;

  String? lang;

  int? dateAdded;

  int? lastUpdate;

  int? lastRead;

  List<int>? categories;

  bool? isLocalArchive;

  /// Keeps a source-backed title visible while it owns chapters whose files
  /// exist only on this device.
  ///
  /// This is deliberately independent from [favorite]: Chimahon can send an
  /// unfavorite tombstone for the portable title without making Mangatan's
  /// local-only chapter overlay inaccessible or resurrecting the title in the
  /// next portable export.
  bool? hasLocalChapterOverlay;

  List<byte>? customCoverImage;

  String? customCoverFromTracker;

  /// only update X days after `lastUpdate`
  int? smartUpdateDays;

  int? updatedAt;

  int? sourceId;

  @Backlink(to: "manga")
  final chapters = IsarLinks<Chapter>();

  Manga({
    this.id = Isar.autoIncrement,
    required this.source,
    required this.author,
    required this.artist,
    this.favorite = false,
    this.favoriteModifiedAt,
    required this.genre,
    required this.imageUrl,
    required this.lang,
    required this.link,
    required this.name,
    this.sourceTitle,
    required this.status,
    required this.description,
    required this.sourceId,
    this.isManga,
    this.itemType = ItemType.manga,
    this.dateAdded,
    this.lastUpdate,
    this.categories,
    this.lastRead = 0,
    this.isLocalArchive = false,
    this.hasLocalChapterOverlay = false,
    this.customCoverImage,
    this.customCoverFromTracker,
    this.smartUpdateDays,
    this.updatedAt = 0,
  }) {
    sourceTitle ??= name;
  }

  /// Applies refreshed source metadata without overwriting a custom display
  /// title. Legacy rows without [sourceTitle] are treated as uncustomized.
  void updateSourceTitle(String? title) {
    final displaysSourceTitle =
        name == null || sourceTitle == null || name == sourceTitle;
    sourceTitle = title;
    if (displaysSourceTitle) name = title;
  }

  /// Updates only the locally displayed title. The source title remains the
  /// stable identity used for Chimahon-compatible backups and sync.
  void updateDisplayTitle(String? title) {
    name = title;
  }

  /// Replaces the source identity and clears any display-title override. This
  /// is used when migrating a library entry to a different source item.
  void resetTitleFromSource(String? title) {
    sourceTitle = title;
    name = title;
  }

  /// Changes the library favorite state using Chimahon's seconds-based clock.
  ///
  /// The stored value is kept monotonic so two quick toggles, or a device with
  /// a clock behind the imported value, cannot make a newer tombstone look
  /// older during sync.
  void updateFavorite(bool value, {DateTime? modifiedAt}) {
    final timestamp = modifiedAt ?? DateTime.now();
    final clockSeconds = timestamp.millisecondsSinceEpoch ~/ 1000;
    final previousSeconds = favoriteModifiedAt;
    final modifiedSeconds =
        previousSeconds != null && clockSeconds <= previousSeconds
        ? previousSeconds + 1
        : clockSeconds;
    favorite = value;
    favoriteModifiedAt = modifiedSeconds;
    final logicalMilliseconds = modifiedSeconds * 1000;
    updatedAt = timestamp.millisecondsSinceEpoch > logicalMilliseconds
        ? timestamp.millisecondsSinceEpoch
        : logicalMilliseconds;
  }

  Manga.fromJson(Map<String, dynamic> json) {
    author = json['author'];
    artist = json['artist'];
    categories = json['categories']?.cast<int>();
    customCoverImage = json['customCoverImage']?.cast<int>();
    dateAdded = json['dateAdded'];
    description = json['description'];
    favorite = json['favorite']!;
    favoriteModifiedAt = json['favoriteModifiedAt'];
    genre = json['genre']?.cast<String>();
    id = json['id'];
    imageUrl = json['imageUrl'];
    isLocalArchive = json['isLocalArchive'];
    hasLocalChapterOverlay = json['hasLocalChapterOverlay'] ?? false;
    isManga = json['isManga'];
    itemType = ItemType.values[json['itemType'] ?? 0];
    lang = json['lang'];
    lastRead = json['lastRead'];
    lastUpdate = json['lastUpdate'];
    link = json['link'];
    name = json['name'];
    sourceTitle = json['sourceTitle'] ?? name;
    source = json['source'];
    status = Status.values[json['status']];
    customCoverFromTracker = json['customCoverFromTracker'];
    smartUpdateDays = json['smartUpdateDays'];
    updatedAt = json['updatedAt'];
    sourceId = json['sourceId'];
  }

  Map<String, dynamic> toJson() => {
    'author': author,
    'artist': artist,
    'categories': categories,
    'customCoverImage': customCoverImage,
    'dateAdded': dateAdded,
    'description': description,
    'favorite': favorite,
    'favoriteModifiedAt': favoriteModifiedAt,
    'genre': genre,
    'id': id,
    'imageUrl': imageUrl,
    'isLocalArchive': isLocalArchive,
    'hasLocalChapterOverlay': hasLocalChapterOverlay,
    'itemType': itemType.index,
    'lang': lang,
    'lastRead': lastRead,
    'lastUpdate': lastUpdate,
    'link': link,
    'name': name,
    'sourceTitle': sourceTitle,
    'source': source,
    'status': status.index,
    'customCoverFromTracker': customCoverFromTracker,
    'smartUpdateDays': smartUpdateDays,
    'updatedAt': updatedAt ?? 0,
    'sourceId': sourceId,
  };
}

extension MangaLibraryVisibility on Manga {
  /// A portable favorite or a title retained solely for device-local chapters.
  bool get isVisibleInLibrary =>
      (favorite ?? false) || (hasLocalChapterOverlay ?? false);
}

extension MangaSourceIdentityQuery
    on QueryBuilder<Manga, Manga, QAfterFilterCondition> {
  QueryBuilder<Manga, Manga, QAfterFilterCondition> titleMatchesSourceIdentity(
    String? title,
  ) {
    return group(
      (query) => query.nameEqualTo(title).or().sourceTitleEqualTo(title),
    );
  }
}

enum Status {
  ongoing,
  completed,
  canceled,
  unknown,
  onHiatus,
  publishingFinished,
}

enum ItemType { manga, anime, novel }
