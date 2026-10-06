import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';

/// Chimahon's SyncService uses these composite identities in both media maps.
/// The nullable author is significant: Kotlin spells an absent author `null`,
/// whereas an explicitly empty author contributes an empty string.
///
/// Database lookup by source + URL is a separate, lossy projection. Never use
/// that lookup key to overlay or validate full wire records.
String chimahonMangaIdentity(BackupManga manga) =>
    '${manga.source}|${manga.url}|${_normalized(manga.title)}|'
    '${manga.hasAuthor() ? _normalized(manga.author) : 'null'}';

String chimahonAnimeIdentity(BackupAnime anime) =>
    '${anime.source}|${anime.url}|${_normalized(anime.title)}|'
    '${anime.hasAuthor() ? _normalized(anime.author) : 'null'}';

String _normalized(String value) => value.trim().toLowerCase();
