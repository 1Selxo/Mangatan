import 'package:fixnum/fixnum.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';

/// Proofs for rebasing Mangatan's lossy media-parent projections onto an
/// existing Chimahon wire identity.
///
/// A shared source and URL are not a wire identity in Chimahon: title and
/// author also participate. Manga rebases only proven Mangatan projection
/// artifacts; anime also pairs one-to-one metadata drift (see
/// [tryRebaseLocalAnimeIdentity]). Callers must therefore establish that both
/// the local and remote source+URL groups contain exactly one row before
/// asking for a rebase. The nullable result makes an unproved identity mismatch fail closed
/// in both the merger and its pre-upload audit.
abstract final class ChimahonMediaParentProjectionProof {
  /// Returns a local manga projection carrying [remote]'s canonical identity
  /// fields only when the mismatch is a known Mangatan projection artifact.
  static BackupManga? tryRebaseLocalMangaIdentity({
    required BackupManga localProjection,
    required BackupManga remote,
    required bool localSourceUrlIsUnique,
    required bool remoteSourceUrlIsUnique,
  }) {
    if (!_canTryRebase(
          localVersion: localProjection.version,
          localSource: localProjection.source,
          localUrl: localProjection.url,
          remoteSource: remote.source,
          remoteUrl: remote.url,
          localSourceUrlIsUnique: localSourceUrlIsUnique,
          remoteSourceUrlIsUnique: remoteSourceUrlIsUnique,
        ) ||
        _mangaIdentityEqual(localProjection, remote)) {
      return null;
    }

    final isTombstoneProjection = _isMatchingMangaTombstoneProjection(
      localProjection,
      remote,
    );
    final isLegacyTitleProjection = _isLegacyMangaTitleProjection(
      localProjection,
      remote,
    );
    final isSparseAuthorProjection =
        localProjection.title == remote.title &&
        _isAbsentEmptyAuthorPair(
          localHasAuthor: localProjection.hasAuthor(),
          localAuthor: localProjection.author,
          remoteHasAuthor: remote.hasAuthor(),
          remoteAuthor: remote.author,
        );
    if (!isTombstoneProjection &&
        !isLegacyTitleProjection &&
        !isSparseAuthorProjection) {
      return null;
    }

    final rebased = localProjection.deepCopy()..title = remote.title;
    if (isLegacyTitleProjection) {
      rebased.customTitle = remote.customTitle;
    }
    if (isTombstoneProjection || isSparseAuthorProjection) {
      _copyMangaAuthorIdentity(rebased, remote);
    }
    return rebased;
  }

  /// Returns a local anime projection carrying [remote]'s canonical identity
  /// whenever the source+URL groups pair one-to-one.
  ///
  /// Unlike manga, any title or author difference is accepted. Chimahon keeps
  /// exactly one database row per anime source+URL (browse and restore both
  /// look the row up by URL and source first), and its restorer never adopts
  /// a synced title or a null author for an existing row. A one-to-one drift
  /// is therefore the same entry with device-local metadata. Leaving it split
  /// makes Mangatan's importer create a second library entry, while Chimahon
  /// folds both records onto its one row. Keeping Chimahon's spelling is the
  /// only stable choice: a Mangatan spelling would split again every sync.
  ///
  /// Known risk: a source that reuses a URL for a different show pairs with
  /// the old record and shows its title until the next metadata refresh.
  /// Chimahon itself collapses that case onto one row, so it cannot be
  /// represented more faithfully. Groups with more than one row on either
  /// side are never paired.
  static BackupAnime? tryRebaseLocalAnimeIdentity({
    required BackupAnime localProjection,
    required BackupAnime remote,
    required bool localSourceUrlIsUnique,
    required bool remoteSourceUrlIsUnique,
  }) {
    if (!_canTryRebase(
          localVersion: localProjection.version,
          localSource: localProjection.source,
          localUrl: localProjection.url,
          remoteSource: remote.source,
          remoteUrl: remote.url,
          localSourceUrlIsUnique: localSourceUrlIsUnique,
          remoteSourceUrlIsUnique: remoteSourceUrlIsUnique,
        ) ||
        _animeIdentityEqual(localProjection, remote)) {
      return null;
    }

    final rebased = localProjection.deepCopy()..title = remote.title;
    _copyAnimeAuthorIdentity(rebased, remote);
    return rebased;
  }

  static bool _canTryRebase({
    required Int64 localVersion,
    required Int64 localSource,
    required String localUrl,
    required Int64 remoteSource,
    required String remoteUrl,
    required bool localSourceUrlIsUnique,
    required bool remoteSourceUrlIsUnique,
  }) =>
      localVersion == Int64.ZERO &&
      localSource == remoteSource &&
      localUrl == remoteUrl &&
      localSourceUrlIsUnique &&
      remoteSourceUrlIsUnique;

  static bool _isMatchingMangaTombstoneProjection(
    BackupManga local,
    BackupManga remote,
  ) =>
      local.hasFavorite() &&
      !local.favorite &&
      remote.hasFavorite() &&
      !remote.favorite &&
      local.hasFavoriteModifiedAt() &&
      remote.hasFavoriteModifiedAt() &&
      local.favoriteModifiedAt == remote.favoriteModifiedAt;

  static bool _isLegacyMangaTitleProjection(
    BackupManga local,
    BackupManga remote,
  ) =>
      !local.hasCustomTitle() &&
      remote.hasCustomTitle() &&
      local.title == remote.customTitle &&
      _authorIdentity(local.hasAuthor(), local.author) ==
          _authorIdentity(remote.hasAuthor(), remote.author);

  static bool _mangaIdentityEqual(BackupManga left, BackupManga right) =>
      left.source == right.source &&
      left.url == right.url &&
      _normalized(left.title) == _normalized(right.title) &&
      _authorIdentity(left.hasAuthor(), left.author) ==
          _authorIdentity(right.hasAuthor(), right.author);

  static bool _animeIdentityEqual(BackupAnime left, BackupAnime right) =>
      left.source == right.source &&
      left.url == right.url &&
      _normalized(left.title) == _normalized(right.title) &&
      _authorIdentity(left.hasAuthor(), left.author) ==
          _authorIdentity(right.hasAuthor(), right.author);

  static String _authorIdentity(bool hasAuthor, String author) =>
      hasAuthor ? _normalized(author) : 'null';

  static bool _isAbsentEmptyAuthorPair({
    required bool localHasAuthor,
    required String localAuthor,
    required bool remoteHasAuthor,
    required String remoteAuthor,
  }) =>
      localHasAuthor != remoteHasAuthor &&
      (!localHasAuthor || localAuthor.isEmpty) &&
      (!remoteHasAuthor || remoteAuthor.isEmpty);

  static void _copyMangaAuthorIdentity(BackupManga target, BackupManga source) {
    if (source.hasAuthor()) {
      target.author = source.author;
    } else {
      target.clearAuthor();
    }
  }

  static void _copyAnimeAuthorIdentity(BackupAnime target, BackupAnime source) {
    if (source.hasAuthor()) {
      target.author = source.author;
    } else {
      target.clearAuthor();
    }
  }

  static String _normalized(String value) => value.trim().toLowerCase();
}
