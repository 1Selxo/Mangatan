import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/services/sync/chimahon_media_parent_projection_proof.dart';

BackupManga _manga({
  String title = 'Title',
  String? author,
  String? customTitle,
  bool? favorite,
  int? favoriteModifiedAt,
  int version = 0,
}) {
  final manga = BackupManga(source: Int64(7), url: '/series', title: title)
    ..version = Int64(version);
  if (author != null) manga.author = author;
  if (customTitle != null) manga.customTitle = customTitle;
  if (favorite != null) manga.favorite = favorite;
  if (favoriteModifiedAt != null) {
    manga.favoriteModifiedAt = Int64(favoriteModifiedAt);
  }
  return manga;
}

BackupManga? _rebase(
  BackupManga local,
  BackupManga remote, {
  bool unique = true,
}) => ChimahonMediaParentProjectionProof.tryRebaseLocalMangaIdentity(
  localProjection: local,
  remote: remote,
  localSourceUrlIsUnique: unique,
  remoteSourceUrlIsUnique: unique,
);

void main() {
  group('manga', () {
    test('an absent versus empty author is rebased onto the remote', () {
      final rebased = _rebase(_manga(), _manga(author: ''))!;
      expect(rebased.hasAuthor(), isTrue);
      expect(rebased.author, '');
    });

    test('a legacy title projection adopts the remote custom title', () {
      final rebased = _rebase(
        _manga(title: 'My name'),
        _manga(title: 'Source name', customTitle: 'My name'),
      )!;
      expect(rebased.title, 'Source name');
      expect(rebased.customTitle, 'My name');
    });

    test('matching tombstones are rebased even with different authors', () {
      final rebased = _rebase(
        _manga(author: 'Old', favorite: false, favoriteModifiedAt: 5),
        _manga(author: 'New', favorite: false, favoriteModifiedAt: 5),
      )!;
      expect(rebased.author, 'New');
    });

    test('tombstones with different timestamps are not a proof', () {
      expect(
        _rebase(
          _manga(author: 'Old', favorite: false, favoriteModifiedAt: 5),
          _manga(author: 'New', favorite: false, favoriteModifiedAt: 6),
        ),
        isNull,
      );
    });

    test('a genuinely different title fails closed', () {
      expect(_rebase(_manga(title: 'One'), _manga(title: 'Two')), isNull);
    });

    test('an identity that already matches needs no rebase', () {
      expect(_rebase(_manga(author: 'A'), _manga(author: ' a ')), isNull);
    });

    test('ambiguous source and URL groups are never rebased', () {
      expect(_rebase(_manga(), _manga(author: ''), unique: false), isNull);
    });

    test('a versioned local row is not a lossy projection', () {
      expect(_rebase(_manga(version: 1), _manga(author: '')), isNull);
    });
  });

  group('anime', () {
    BackupAnime anime({String? author}) {
      final value = BackupAnime(source: Int64(7), url: '/series', title: 'T');
      if (author != null) value.author = author;
      return value;
    }

    test('an absent versus empty author is rebased onto the remote', () {
      final rebased =
          ChimahonMediaParentProjectionProof.tryRebaseLocalAnimeIdentity(
            localProjection: anime(author: ''),
            remote: anime(),
            localSourceUrlIsUnique: true,
            remoteSourceUrlIsUnique: true,
          )!;
      expect(rebased.hasAuthor(), isFalse);
    });

    // Deliberate change: anime now pairs any one-to-one title or author drift
    // and keeps Chimahon's spelling (the remote), including a null author.
    test('one-to-one title or author drift adopts the remote identity', () {
      final rebased =
          ChimahonMediaParentProjectionProof.tryRebaseLocalAnimeIdentity(
            localProjection: anime(author: 'Studio list')
              ..title = 'Local title'
              ..description = 'Local description',
            remote: anime(),
            localSourceUrlIsUnique: true,
            remoteSourceUrlIsUnique: true,
          )!;
      expect(rebased.title, 'T');
      expect(rebased.hasAuthor(), isFalse);
      expect(rebased.description, 'Local description');

      expect(
        ChimahonMediaParentProjectionProof.tryRebaseLocalAnimeIdentity(
          localProjection: anime(author: 'One'),
          remote: anime(author: 'Two'),
          localSourceUrlIsUnique: true,
          remoteSourceUrlIsUnique: true,
        )?.author,
        'Two',
      );
    });

    test('ambiguous groups, versioned rows and other URLs never pair', () {
      BackupAnime? rebase({
        bool localUnique = true,
        bool remoteUnique = true,
        BackupAnime? local,
        BackupAnime? remote,
      }) => ChimahonMediaParentProjectionProof.tryRebaseLocalAnimeIdentity(
        localProjection: local ?? anime(author: 'One'),
        remote: remote ?? anime(author: 'Two'),
        localSourceUrlIsUnique: localUnique,
        remoteSourceUrlIsUnique: remoteUnique,
      );

      expect(rebase(localUnique: false), isNull);
      expect(rebase(remoteUnique: false), isNull);
      expect(rebase(local: anime(author: 'One')..version = Int64(3)), isNull);
      expect(rebase(remote: anime(author: 'Two')..url = '/other'), isNull);
      expect(rebase(remote: anime(author: 'Two')..source = Int64(8)), isNull);
    });
  });
}
