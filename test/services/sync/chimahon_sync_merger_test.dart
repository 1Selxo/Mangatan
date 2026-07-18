import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupEpisode.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupExtensionRepos.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupFeed.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupHistory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSavedSearch.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupStatistics.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupTracking.pb.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:protobuf/protobuf.dart';

void main() {
  const merger = ChimahonSyncMerger();
  const preferenceCodec = ChimahonPreferenceCodec();

  test('merges manga chapters, categories, history, and remote settings', () {
    final local = BackupMihon(
      backupCategories: [BackupCategory(name: 'Reading', order: Int64(0))],
      backupManga: [
        BackupManga(
          source: Int64(1),
          url: '/same',
          title: 'Same',
          author: 'Author',
          version: Int64(2),
          categories: [Int64(0)],
          chapters: [
            BackupChapter(url: '/1', name: 'Chapter 1', version: Int64(1)),
          ],
        ),
      ],
      backupPreferences: [
        preferenceCodec.encode('pref_anki_profiles', 'local defaults'),
      ],
    );
    final remote = BackupMihon(
      backupCategories: [BackupCategory(name: 'Reading', order: Int64(3))],
      backupManga: [
        BackupManga(
          source: Int64(1),
          url: '/same',
          title: 'Same',
          author: 'Author',
          version: Int64(1),
          categories: [Int64(3)],
          chapters: [
            BackupChapter(url: '/2', name: 'Chapter 2', version: Int64(1)),
          ],
        ),
      ],
      backupPreferences: [
        preferenceCodec.encode('pref_anki_profiles', 'filled Chimahon fields'),
      ],
    );

    final merged = merger.merge(local: local, remote: remote);

    expect(merged.backupManga.single.version, Int64(2));
    expect(
      merged.backupManga.single.chapters.map((chapter) => chapter.name),
      containsAll(['Chapter 1', 'Chapter 2']),
    );
    expect(merged.backupCategories.single.order, Int64(3));
    expect(merged.backupManga.single.categories, [Int64(3)]);
    expect(
      preferenceCodec.decode(merged.backupPreferences.single).value,
      'filled Chimahon fields',
    );
  });

  test('retains exact remote history milliseconds on a projection tie', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            version: Int64.ZERO,
            lastModifiedAt: Int64(20),
            history: [
              BackupHistory(
                url: '/one',
                lastRead: Int64(10),
                readDuration: Int64.ZERO,
              ),
              BackupHistory(
                url: '/long',
                lastRead: Int64(11),
                readDuration: Int64(1765000),
              ),
            ],
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            version: Int64(4),
            lastModifiedAt: Int64(20),
            history: [
              BackupHistory(
                url: '/one',
                lastRead: Int64(10),
                readDuration: Int64(1),
              ),
              BackupHistory(
                url: '/long',
                lastRead: Int64(11),
                readDuration: Int64(1765281),
              ),
            ],
          ),
        ],
      ),
    );

    expect(merged.backupManga.single.history.map((item) => item.readDuration), [
      Int64(1),
      Int64(1765281),
    ]);
  });

  test('uses source title as identity and keeps the newest custom title', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Source title',
            customTitle: 'Old custom title',
            author: 'Author',
            version: Int64(1),
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Source title',
            customTitle: 'New custom title',
            author: 'Author',
            version: Int64(2),
          ),
        ],
      ),
    );

    expect(merged.backupManga, hasLength(1));
    expect(merged.backupManga.single.title, 'Source title');
    expect(merged.backupManga.single.customTitle, 'New custom title');
  });

  test('does not collapse distinct Chimahon manga sharing a source URL', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/shared',
            title: 'First edition',
            author: 'Author',
            version: Int64(2),
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/shared',
            title: 'Second edition',
            author: 'Author',
            version: Int64(3),
          ),
        ],
      ),
    );

    expect(merged.backupManga, hasLength(2));
    expect(
      merged.backupManga.map((manga) => manga.title),
      containsAll(['First edition', 'Second edition']),
    );
  });

  test('uses Chimahon chapter URL, name, and number as identity', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            author: 'Author',
            version: Int64(2),
            chapters: [
              BackupChapter(
                url: '/chapter',
                name: 'Chapter 1',
                chapterNumber: 1,
                version: Int64(1),
              ),
            ],
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            author: 'Author',
            version: Int64(3),
            chapters: [
              BackupChapter(
                url: '/chapter',
                name: 'Chapter 1 corrected',
                chapterNumber: 1,
                version: Int64(2),
              ),
              BackupChapter(
                url: '/chapter',
                name: 'Chapter 1',
                chapterNumber: 1.5,
                version: Int64(2),
              ),
            ],
          ),
        ],
      ),
    );

    expect(merged.backupManga, hasLength(1));
    expect(merged.backupManga.single.chapters, hasLength(3));
  });

  test('metadata refresh cannot clear custom title field 800', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Source title',
            author: 'Author',
            version: Int64(3),
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Source title',
            customTitle: 'Chimahon custom title',
            author: 'Author',
            version: Int64(2),
          ),
        ],
      ),
    );

    expect(merged.backupManga, hasLength(1));
    expect(merged.backupManga.single.version, Int64(3));
    expect(merged.backupManga.single.customTitle, 'Chimahon custom title');
  });

  test('newer unversioned source refresh preserves Chimahon custom title', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Source title',
            lastModifiedAt: Int64(300),
            version: Int64.ZERO,
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Source title',
            customTitle: 'Chimahon custom title',
            lastModifiedAt: Int64(200),
            version: Int64(267),
          ),
        ],
      ),
    );

    expect(merged.backupManga.single.version, Int64(268));
    expect(merged.backupManga.single.customTitle, 'Chimahon custom title');
  });

  test('keeps the local custom title when manga versions tie', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Source title',
            customTitle: 'Local custom title',
            author: 'Author',
            version: Int64(2),
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Source title',
            customTitle: 'Remote custom title',
            author: 'Author',
            version: Int64(2),
          ),
        ],
      ),
    );

    expect(merged.backupManga.single.customTitle, 'Local custom title');
  });

  test('repairs a legacy local custom title by stable source URL', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Legacy display title',
            author: 'Current author metadata',
            lastModifiedAt: Int64(300),
            version: Int64.ZERO,
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Canonical source title',
            customTitle: 'Legacy display title',
            author: 'Current author metadata',
            lastModifiedAt: Int64(200),
            version: Int64(7),
          ),
        ],
      ),
    );

    expect(merged.backupManga, hasLength(1));
    expect(merged.backupManga.single.title, 'Canonical source title');
    expect(merged.backupManga.single.customTitle, 'Legacy display title');
    expect(merged.backupManga.single.version, Int64(8));
  });

  test(
    'rebases an activated custom-title tombstone without duplicating it',
    () {
      final merged = merger.merge(
        local: BackupMihon(
          backupManga: [
            BackupManga(
              source: Int64(1),
              url: '/same',
              title: 'Stale source title',
              customTitle: 'My title',
              author: 'Stale author',
              favorite: false,
              favoriteModifiedAt: Int64(100),
              lastModifiedAt: Int64(100),
              version: Int64.ZERO,
            ),
          ],
        ),
        remote: BackupMihon(
          backupManga: [
            BackupManga(
              source: Int64(1),
              url: '/same',
              title: 'Canonical source title',
              favorite: false,
              favoriteModifiedAt: Int64(100),
              lastModifiedAt: Int64(100),
              version: Int64(7),
            ),
          ],
        ),
        remoteWinsProjectionTies: true,
      );

      expect(merged.backupManga, hasLength(1));
      expect(merged.backupManga.single.title, 'Canonical source title');
      expect(merged.backupManga.single.hasAuthor(), isFalse);
      expect(merged.backupManga.single.customTitle, 'My title');
    },
  );

  test('rebases an activated anime tombstone by unique source URL', () {
    final remote = BackupAnime(
      source: Int64(2),
      url: '/same',
      title: 'Canonical anime title',
      favorite: false,
      favoriteModifiedAt: Int64(100),
      lastModifiedAt: Int64(100),
      version: Int64(7),
    );
    final merged = merger.merge(
      local: BackupMihon(
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/same',
            title: 'Stale anime title',
            author: 'Stale author',
            favorite: false,
            favoriteModifiedAt: Int64(100),
            lastModifiedAt: Int64(100),
            version: Int64.ZERO,
          ),
        ],
      ),
      remote: BackupMihon(backupAnime: [remote]),
      remoteWinsProjectionTies: true,
    );

    expect(merged.backupAnime, hasLength(1));
    expect(
      merged.backupAnime.single.writeToBuffer(),
      orderedEquals(remote.writeToBuffer()),
    );
  });

  test('duplicate local source URL parents do not collapse through rebase', () {
    BackupManga localManga(String title) => BackupManga(
      source: Int64(1),
      url: '/shared-manga',
      title: title,
      author: '$title author',
      favorite: false,
      favoriteModifiedAt: Int64(100),
      lastModifiedAt: Int64(100),
      version: Int64.ZERO,
    );
    BackupAnime localAnime(String title) => BackupAnime(
      source: Int64(2),
      url: '/shared-anime',
      title: title,
      author: '$title author',
      favorite: false,
      favoriteModifiedAt: Int64(100),
      lastModifiedAt: Int64(100),
      version: Int64.ZERO,
    );
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [localManga('Local manga A'), localManga('Local manga B')],
        backupAnime: [localAnime('Local anime A'), localAnime('Local anime B')],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/shared-manga',
            title: 'Remote manga',
            favorite: false,
            favoriteModifiedAt: Int64(100),
            lastModifiedAt: Int64(100),
            version: Int64(7),
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/shared-anime',
            title: 'Remote anime',
            favorite: false,
            favoriteModifiedAt: Int64(100),
            lastModifiedAt: Int64(100),
            version: Int64(8),
          ),
        ],
      ),
      remoteWinsProjectionTies: true,
    );

    expect(merged.backupManga, hasLength(3));
    expect(
      merged.backupManga.map((manga) => manga.title),
      containsAll(['Remote manga', 'Local manga A', 'Local manga B']),
    );
    expect(merged.backupAnime, hasLength(3));
    expect(
      merged.backupAnime.map((anime) => anime.title),
      containsAll(['Remote anime', 'Local anime A', 'Local anime B']),
    );
  });

  test(
    'duplicate remote source URL parents do not collapse through rebase',
    () {
      final merged = merger.merge(
        local: BackupMihon(
          backupManga: [
            BackupManga(
              source: Int64(1),
              url: '/shared-manga',
              title: 'Local manga',
              author: 'Local manga author',
              favorite: false,
              favoriteModifiedAt: Int64(100),
              lastModifiedAt: Int64(100),
              version: Int64.ZERO,
            ),
          ],
          backupAnime: [
            BackupAnime(
              source: Int64(2),
              url: '/shared-anime',
              title: 'Local anime',
              author: 'Local anime author',
              favorite: false,
              favoriteModifiedAt: Int64(100),
              lastModifiedAt: Int64(100),
              version: Int64.ZERO,
            ),
          ],
        ),
        remote: BackupMihon(
          backupManga: [
            for (final title in ['Remote manga A', 'Remote manga B'])
              BackupManga(
                source: Int64(1),
                url: '/shared-manga',
                title: title,
                favorite: false,
                favoriteModifiedAt: Int64(100),
                lastModifiedAt: Int64(100),
                version: Int64(7),
              ),
          ],
          backupAnime: [
            for (final title in ['Remote anime A', 'Remote anime B'])
              BackupAnime(
                source: Int64(2),
                url: '/shared-anime',
                title: title,
                favorite: false,
                favoriteModifiedAt: Int64(100),
                lastModifiedAt: Int64(100),
                version: Int64(8),
              ),
          ],
        ),
        remoteWinsProjectionTies: true,
      );

      expect(merged.backupManga, hasLength(3));
      expect(
        merged.backupManga.map((manga) => manga.title),
        containsAll(['Remote manga A', 'Remote manga B', 'Local manga']),
      );
      expect(merged.backupAnime, hasLength(3));
      expect(
        merged.backupAnime.map((anime) => anime.title),
        containsAll(['Remote anime A', 'Remote anime B', 'Local anime']),
      );
    },
  );

  test('does not rebase newer source metadata by source URL alone', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/shared-manga',
            title: 'Refreshed manga title',
            author: 'Refreshed manga author',
            lastModifiedAt: Int64(300),
            version: Int64.ZERO,
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/shared-anime',
            title: 'Refreshed anime title',
            author: 'Refreshed anime author',
            lastModifiedAt: Int64(400),
            version: Int64.ZERO,
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/shared-manga',
            title: 'Previous manga title',
            author: 'Previous manga author',
            lastModifiedAt: Int64(200),
            version: Int64(7),
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/shared-anime',
            title: 'Previous anime title',
            author: 'Previous anime author',
            lastModifiedAt: Int64(200),
            version: Int64(8),
          ),
        ],
      ),
    );

    expect(merged.backupManga, hasLength(2));
    expect(
      merged.backupManga.map((manga) => manga.title),
      containsAll(['Previous manga title', 'Refreshed manga title']),
    );
    expect(merged.backupAnime, hasLength(2));
    expect(
      merged.backupAnime.map((anime) => anime.title),
      containsAll(['Previous anime title', 'Refreshed anime title']),
    );
  });

  test('does not rebase newer chapter or episode identity edits by URL', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/manga',
            title: 'Manga',
            lastModifiedAt: Int64(300),
            version: Int64.ZERO,
            chapters: [
              BackupChapter(
                url: '/chapter',
                name: 'Chapter 1 corrected',
                chapterNumber: 5,
                lastModifiedAt: Int64(300),
                version: Int64.ZERO,
              ),
            ],
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            lastModifiedAt: Int64(300),
            version: Int64.ZERO,
            episodes: [
              BackupEpisode(
                url: '/episode',
                name: 'Episode 1',
                episodeNumber: 5,
                lastModifiedAt: Int64(300),
                version: Int64.ZERO,
              ),
            ],
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/manga',
            title: 'Manga',
            lastModifiedAt: Int64(200),
            version: Int64(7),
            chapters: [
              BackupChapter(
                url: '/chapter',
                name: 'Chapter 1',
                chapterNumber: 1,
                lastModifiedAt: Int64(200),
                version: Int64(6),
              ),
            ],
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            lastModifiedAt: Int64(200),
            version: Int64(8),
            episodes: [
              BackupEpisode(
                url: '/episode',
                name: 'Episode 1',
                episodeNumber: 1,
                lastModifiedAt: Int64(200),
                version: Int64(6),
              ),
            ],
          ),
        ],
      ),
    );

    expect(merged.backupManga.single.chapters, hasLength(2));
    expect(
      merged.backupManga.single.chapters.map(
        (chapter) => (chapter.name, chapter.chapterNumber),
      ),
      containsAll([('Chapter 1', 1.0), ('Chapter 1 corrected', 5.0)]),
    );
    expect(merged.backupAnime.single.episodes, hasLength(2));
    expect(
      merged.backupAnime.single.episodes.map(
        (episode) => (episode.name, episode.episodeNumber),
      ),
      containsAll([('Episode 1', 1.0), ('Episode 1', 5.0)]),
    );
  });

  test('duplicate local child URLs do not collapse distinct identities', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/manga',
            title: 'Manga',
            version: Int64.ZERO,
            chapters: [
              BackupChapter(
                url: '/shared-chapter',
                name: 'Local chapter A',
                chapterNumber: 1,
                lastModifiedAt: Int64(100),
                version: Int64.ZERO,
              ),
              BackupChapter(
                url: '/shared-chapter',
                name: 'Local chapter B',
                chapterNumber: 2,
                lastModifiedAt: Int64(100),
                version: Int64.ZERO,
              ),
            ],
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            version: Int64.ZERO,
            episodes: [
              BackupEpisode(
                url: '/shared-episode',
                name: 'Local episode A',
                episodeNumber: 1,
                lastModifiedAt: Int64(100),
                version: Int64.ZERO,
              ),
              BackupEpisode(
                url: '/shared-episode',
                name: 'Local episode B',
                episodeNumber: 2,
                lastModifiedAt: Int64(100),
                version: Int64.ZERO,
              ),
            ],
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/manga',
            title: 'Manga',
            version: Int64(7),
            chapters: [
              BackupChapter(
                url: '/shared-chapter',
                name: 'Remote chapter',
                chapterNumber: 9,
                lastModifiedAt: Int64(100),
                version: Int64(5),
              ),
            ],
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            version: Int64(8),
            episodes: [
              BackupEpisode(
                url: '/shared-episode',
                name: 'Remote episode',
                episodeNumber: 9,
                lastModifiedAt: Int64(100),
                version: Int64(5),
              ),
            ],
          ),
        ],
      ),
    );

    expect(merged.backupManga.single.chapters, hasLength(3));
    expect(
      merged.backupManga.single.chapters.map((chapter) => chapter.name),
      containsAll(['Remote chapter', 'Local chapter A', 'Local chapter B']),
    );
    expect(merged.backupAnime.single.episodes, hasLength(3));
    expect(
      merged.backupAnime.single.episodes.map((episode) => episode.name),
      containsAll(['Remote episode', 'Local episode A', 'Local episode B']),
    );
  });

  test('duplicate remote child URLs do not collapse distinct identities', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/manga',
            title: 'Manga',
            version: Int64.ZERO,
            chapters: [
              BackupChapter(
                url: '/shared-chapter',
                name: 'Chapter 10',
                chapterNumber: 10,
                lastModifiedAt: Int64(100),
                version: Int64.ZERO,
              ),
            ],
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            version: Int64.ZERO,
            episodes: [
              BackupEpisode(
                url: '/shared-episode',
                name: 'Episode 10',
                episodeNumber: 10,
                lastModifiedAt: Int64(100),
                version: Int64.ZERO,
              ),
            ],
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/manga',
            title: 'Manga',
            version: Int64(7),
            chapters: [
              BackupChapter(
                url: '/shared-chapter',
                name: 'Chapter 10',
                chapterNumber: 9.5,
                lastModifiedAt: Int64(100),
                version: Int64(5),
              ),
              BackupChapter(
                url: '/shared-chapter',
                name: 'Chapter 11',
                chapterNumber: 11,
                lastModifiedAt: Int64(100),
                version: Int64(5),
              ),
            ],
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            version: Int64(8),
            episodes: [
              BackupEpisode(
                url: '/shared-episode',
                name: 'Episode 10',
                episodeNumber: 9.5,
                lastModifiedAt: Int64(100),
                version: Int64(5),
              ),
              BackupEpisode(
                url: '/shared-episode',
                name: 'Episode 11',
                episodeNumber: 11,
                lastModifiedAt: Int64(100),
                version: Int64(5),
              ),
            ],
          ),
        ],
      ),
    );

    expect(merged.backupManga.single.chapters, hasLength(3));
    expect(
      merged.backupManga.single.chapters.map(
        (chapter) => (chapter.name, chapter.chapterNumber),
      ),
      containsAll([
        ('Chapter 10', 9.5),
        ('Chapter 11', 11.0),
        ('Chapter 10', 10.0),
      ]),
    );
    expect(merged.backupAnime.single.episodes, hasLength(3));
    expect(
      merged.backupAnime.single.episodes.map(
        (episode) => (episode.name, episode.episodeNumber),
      ),
      containsAll([
        ('Episode 10', 9.5),
        ('Episode 11', 11.0),
        ('Episode 10', 10.0),
      ]),
    );
  });

  test('remote absent child numbers do not erase newer parsed identities', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/manga',
            title: 'Manga',
            lastModifiedAt: Int64(300),
            version: Int64.ZERO,
            chapters: [
              BackupChapter(
                url: '/chapter',
                name: 'Chapter 9',
                chapterNumber: 9,
                lastModifiedAt: Int64(300),
                version: Int64.ZERO,
              ),
            ],
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            lastModifiedAt: Int64(300),
            version: Int64.ZERO,
            episodes: [
              BackupEpisode(
                url: '/episode',
                name: 'Episode 9',
                episodeNumber: 9,
                lastModifiedAt: Int64(300),
                version: Int64.ZERO,
              ),
            ],
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/manga',
            title: 'Manga',
            lastModifiedAt: Int64(200),
            version: Int64(7),
            chapters: [
              BackupChapter(
                url: '/chapter',
                name: 'Chapter 9',
                lastModifiedAt: Int64(200),
                version: Int64(6),
              ),
            ],
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            lastModifiedAt: Int64(200),
            version: Int64(8),
            episodes: [
              BackupEpisode(
                url: '/episode',
                name: 'Episode 9',
                lastModifiedAt: Int64(200),
                version: Int64(6),
              ),
            ],
          ),
        ],
      ),
    );

    final chapters = merged.backupManga.single.chapters;
    expect(chapters, hasLength(2));
    expect(
      chapters
          .where((chapter) => chapter.hasChapterNumber())
          .single
          .chapterNumber,
      9,
    );
    expect(
      chapters.where((chapter) => !chapter.hasChapterNumber()),
      hasLength(1),
    );

    final episodes = merged.backupAnime.single.episodes;
    expect(episodes, hasLength(2));
    expect(
      episodes
          .where((episode) => episode.hasEpisodeNumber())
          .single
          .episodeNumber,
      9,
    );
    expect(
      episodes.where((episode) => !episode.hasEpisodeNumber()),
      hasLength(1),
    );
  });

  test('exact-clock child projections retain the remote wire identity', () {
    final remote = BackupMihon(
      backupManga: [
        BackupManga(
          source: Int64(1),
          url: '/manga',
          title: 'Manga',
          lastModifiedAt: Int64(100),
          version: Int64(7),
          chapters: [
            BackupChapter(
              url: '/chapter',
              name: 'Remote chapter name',
              dateFetch: Int64(11),
              sourceOrder: Int64(12),
              lastModifiedAt: Int64(100),
              version: Int64(6),
            ),
          ],
        ),
      ],
      backupAnime: [
        BackupAnime(
          source: Int64(2),
          url: '/anime',
          title: 'Anime',
          lastModifiedAt: Int64(200),
          version: Int64(8),
          episodes: [
            BackupEpisode(
              url: '/episode',
              name: 'Remote episode name',
              dateFetch: Int64(21),
              sourceOrder: Int64(22),
              lastModifiedAt: Int64(200),
              version: Int64(6),
            ),
          ],
        ),
      ],
    );
    final localProjection = BackupMihon(
      backupManga: [
        BackupManga(
          source: Int64(1),
          url: '/manga',
          title: 'Manga',
          lastModifiedAt: Int64(100),
          version: Int64.ZERO,
          chapters: [
            BackupChapter(
              url: '/chapter',
              name: 'Legacy chapter name',
              chapterNumber: 9,
              lastModifiedAt: Int64(100),
              version: Int64.ZERO,
            ),
          ],
        ),
      ],
      backupAnime: [
        BackupAnime(
          source: Int64(2),
          url: '/anime',
          title: 'Anime',
          lastModifiedAt: Int64(200),
          version: Int64.ZERO,
          episodes: [
            BackupEpisode(
              url: '/episode',
              name: 'Legacy episode name',
              episodeNumber: 9,
              lastModifiedAt: Int64(200),
              version: Int64.ZERO,
            ),
          ],
        ),
      ],
    );

    final merged = merger.merge(
      local: localProjection,
      remote: remote,
      remoteWinsProjectionTies: true,
    );

    expect(merged.writeToBuffer(), orderedEquals(remote.writeToBuffer()));
  });

  test('preserves Chimahon-only manga and chapter structure fields', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            description: 'new local metadata',
            lastModifiedAt: Int64(300),
            version: Int64.ZERO,
            chapters: [
              BackupChapter(
                url: '/chapter',
                name: 'Vol.1 Ch.32 - Hybrid 2',
                chapterNumber: 2,
                lastModifiedAt: Int64(300),
                version: Int64.ZERO,
              ),
            ],
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            viewer: 4,
            chapterFlags: 7,
            viewerFlags: 9,
            updateStrategy: 2,
            notes: 'Chimahon note',
            initialized: false,
            excludedScanlators: const ['Group'],
            lastModifiedAt: Int64(200),
            version: Int64(7),
            chapters: [
              BackupChapter(
                url: '/chapter',
                name: 'Vol.1 Ch.32 - Hybrid 2',
                chapterNumber: 32,
                dateFetch: Int64(123),
                sourceOrder: Int64(456),
                lastModifiedAt: Int64(200),
                version: Int64(6),
              ),
            ],
          ),
        ],
      ),
    );

    final manga = merged.backupManga.single;
    expect(manga.description, 'new local metadata');
    expect(manga.viewer, 4);
    expect(manga.chapterFlags, 7);
    expect(manga.viewerFlags, 9);
    expect(manga.updateStrategy, 2);
    expect(manga.notes, 'Chimahon note');
    expect(manga.hasInitialized(), isTrue);
    expect(manga.initialized, isFalse);
    expect(manga.excludedScanlators, ['Group']);
    expect(manga.chapters, hasLength(1));
    expect(manga.chapters.single.chapterNumber, 32);
    expect(manga.chapters.single.dateFetch, Int64(123));
    expect(manga.chapters.single.sourceOrder, Int64(456));
  });

  test('preserves Chimahon category flags and identity on an order tie', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupCategories: [
          BackupCategory(
            name: 'Reading',
            order: Int64(3),
            id: Int64(12),
            flags: Int64.ZERO,
            hidden: false,
          ),
        ],
      ),
      remote: BackupMihon(
        backupCategories: [
          BackupCategory(
            name: 'Reading',
            order: Int64(3),
            id: Int64(99),
            flags: Int64(3),
            hidden: true,
          ),
        ],
      ),
    );

    expect(merged.backupCategories.single.order, Int64(3));
    expect(merged.backupCategories.single.id, Int64(99));
    expect(merged.backupCategories.single.flags, Int64(3));
    expect(merged.backupCategories.single.hidden, isTrue);
  });

  test('makes distinct category orders unique and remaps memberships', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupCategories: [
          BackupCategory(name: 'Local category', order: Int64.ZERO),
        ],
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/local',
            title: 'Local title',
            categories: [Int64.ZERO],
          ),
        ],
      ),
      remote: BackupMihon(
        backupCategories: [
          BackupCategory(name: 'Remote category', order: Int64.ZERO),
        ],
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/remote',
            title: 'Remote title',
            categories: [Int64.ZERO],
          ),
        ],
      ),
    );

    final categoriesByName = {
      for (final category in merged.backupCategories)
        category.name: category.order,
    };
    expect(categoriesByName.values.toSet(), hasLength(2));
    expect(
      merged.backupManga
          .singleWhere((manga) => manga.url == '/local')
          .categories,
      [categoriesByName['Local category']],
    );
    expect(
      merged.backupManga
          .singleWhere((manga) => manga.url == '/remote')
          .categories,
      [categoriesByName['Remote category']],
    );
  });

  test('media record merges retain unknown fields from both winners', () {
    final local = BackupMihon(
      backupManga: [
        _withUnknownMarker(
          BackupManga(
            source: Int64(1),
            url: '/manga',
            title: 'Manga',
            version: Int64(2),
            chapters: [
              _withUnknownMarker(
                BackupChapter(
                  url: '/chapter',
                  name: 'Chapter',
                  version: Int64(2),
                ),
                11,
              ),
            ],
            history: [
              _withUnknownMarker(
                BackupHistory(url: '/chapter', lastRead: Int64(20)),
                13,
              ),
            ],
            tracking: [_withUnknownMarker(BackupTracking(syncId: 1), 15)],
          ),
          1,
        ),
      ],
      backupAnime: [
        _withUnknownMarker(
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            version: Int64(1),
            episodes: [
              _withUnknownMarker(
                BackupEpisode(
                  url: '/episode',
                  name: 'Episode',
                  version: Int64(1),
                ),
                23,
              ),
            ],
            history: [
              _withUnknownMarker(
                BackupHistory(url: '/episode', lastRead: Int64(10)),
                25,
              ),
            ],
            tracking: [_withUnknownMarker(BackupTracking(syncId: 2), 27)],
          ),
          21,
        ),
      ],
    );
    final remote = BackupMihon(
      backupManga: [
        _withUnknownMarker(
          BackupManga(
            source: Int64(1),
            url: '/manga',
            title: 'Manga',
            version: Int64(1),
            chapters: [
              _withUnknownMarker(
                BackupChapter(
                  url: '/chapter',
                  name: 'Chapter',
                  version: Int64(1),
                ),
                12,
              ),
            ],
            history: [
              _withUnknownMarker(
                BackupHistory(url: '/chapter', lastRead: Int64(10)),
                14,
              ),
            ],
            tracking: [_withUnknownMarker(BackupTracking(syncId: 1), 16)],
          ),
          2,
        ),
      ],
      backupAnime: [
        _withUnknownMarker(
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            version: Int64(2),
            episodes: [
              _withUnknownMarker(
                BackupEpisode(
                  url: '/episode',
                  name: 'Episode',
                  version: Int64(2),
                ),
                24,
              ),
            ],
            history: [
              _withUnknownMarker(
                BackupHistory(url: '/episode', lastRead: Int64(20)),
                26,
              ),
            ],
            tracking: [_withUnknownMarker(BackupTracking(syncId: 2), 28)],
          ),
          22,
        ),
      ],
    );

    final merged = merger.merge(local: local, remote: remote);
    final manga = merged.backupManga.single;
    expect(_unknownMarkers(manga), [Int64(2), Int64(1)]);
    expect(_unknownMarkers(manga.chapters.single), [Int64(12), Int64(11)]);
    expect(_unknownMarkers(manga.history.single), [Int64(14), Int64(13)]);
    expect(_unknownMarkers(manga.tracking.single), [Int64(16), Int64(15)]);

    final anime = merged.backupAnime.single;
    expect(_unknownMarkers(anime), [Int64(21), Int64(22)]);
    expect(_unknownMarkers(anime.episodes.single), [Int64(23), Int64(24)]);
    expect(_unknownMarkers(anime.history.single), [Int64(25), Int64(26)]);
    expect(_unknownMarkers(anime.tracking.single), [Int64(27), Int64(28)]);
  });

  test('keyed metadata merges retain unknown fields from both sides', () {
    BackupSavedSearch search(int marker, String query) => _withUnknownMarker(
      BackupSavedSearch(source: Int64(7), name: 'Search', query: query),
      marker,
    );

    final merged = merger.merge(
      local: BackupMihon(
        backupCategories: [
          _withUnknownMarker(
            BackupCategory(name: 'Reading', order: Int64(1)),
            31,
          ),
        ],
        backupSources: [
          _withUnknownMarker(
            BackupSource(name: 'Local source', sourceId: Int64(7)),
            33,
          ),
        ],
        backupExtensionRepo: [
          _withUnknownMarker(
            BackupExtensionRepos(baseUrl: 'https://repo', name: 'Local'),
            35,
          ),
        ],
        backupSavedSearches: [search(37, 'local query')],
        backupFeeds: [
          _withUnknownMarker(
            BackupFeed(source: Int64(7), savedSearch: search(41, 'local')),
            39,
          ),
        ],
      ),
      remote: BackupMihon(
        backupCategories: [
          _withUnknownMarker(
            BackupCategory(name: 'Reading', order: Int64(2)),
            32,
          ),
        ],
        backupSources: [
          _withUnknownMarker(
            BackupSource(name: 'Remote source', sourceId: Int64(7)),
            34,
          ),
        ],
        backupExtensionRepo: [
          _withUnknownMarker(
            BackupExtensionRepos(baseUrl: 'https://repo', name: 'Remote'),
            36,
          ),
        ],
        backupSavedSearches: [search(38, 'remote query')],
        backupFeeds: [
          _withUnknownMarker(
            BackupFeed(source: Int64(7), savedSearch: search(42, 'remote')),
            40,
          ),
        ],
      ),
    );

    expect(merged.backupCategories.single.order, Int64(2));
    expect(_unknownMarkers(merged.backupCategories.single), [
      Int64(31),
      Int64(32),
    ]);
    expect(merged.backupSources.single.name, 'Local source');
    expect(_unknownMarkers(merged.backupSources.single), [
      Int64(34),
      Int64(33),
    ]);
    expect(merged.backupExtensionRepo.single.name, 'Local');
    expect(_unknownMarkers(merged.backupExtensionRepo.single), [
      Int64(36),
      Int64(35),
    ]);
    expect(merged.backupSavedSearches.single.query, 'local query');
    expect(_unknownMarkers(merged.backupSavedSearches.single), [
      Int64(38),
      Int64(37),
    ]);
    expect(_unknownMarkers(merged.backupFeeds.single), [Int64(40), Int64(39)]);
    expect(_unknownMarkers(merged.backupFeeds.single.savedSearch), [
      Int64(42),
      Int64(41),
    ]);
  });

  test(
    'remote profile snapshot authoritatively replaces cascade overrides',
    () {
      final merged = merger.merge(
        local: BackupMihon(
          backupPreferences: [
            preferenceCodec.encode('pref_anki_profiles', 'local profiles'),
            preferenceCodec.encode('pref_dict_profile_manga_42', 'local'),
            preferenceCodec.encode('pref_dict_profile_novel_old', 'local'),
          ],
        ),
        remote: BackupMihon(
          backupPreferences: [
            preferenceCodec.encode('pref_anki_profiles', 'remote profiles'),
            preferenceCodec.encode('pref_dict_profile_source_7', 'remote'),
          ],
        ),
      );

      final preferences = {
        for (final preference in merged.backupPreferences)
          preference.key: preferenceCodec.decode(preference).value,
      };
      expect(preferences['pref_anki_profiles'], 'remote profiles');
      expect(preferences['pref_dict_profile_source_7'], 'remote');
      expect(preferences, isNot(contains('pref_dict_profile_manga_42')));
      expect(preferences, isNot(contains('pref_dict_profile_novel_old')));
      expect(
        merged.backupPreferences.map((preference) => preference.key),
        ['pref_anki_profiles', 'pref_dict_profile_source_7'],
        reason: 'Filtering cleared overrides must not reorder the remote list.',
      );
    },
  );

  test('profile override snapshot preserves preference envelope unknowns', () {
    final localOverride = _withUnknownMarker(
      preferenceCodec.encode('pref_dict_profile_source_7', 'local'),
      51,
    );
    _withUnknownMarker(localOverride.value, 53);
    final remoteOverride = _withUnknownMarker(
      preferenceCodec.encode('pref_dict_profile_source_7', 'remote'),
      52,
    );
    _withUnknownMarker(remoteOverride.value, 54);

    final merged = merger.merge(
      local: BackupMihon(backupPreferences: [localOverride]),
      remote: BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('pref_anki_profiles', 'profiles'),
          remoteOverride,
        ],
      ),
    );
    final override = merged.backupPreferences.singleWhere(
      (preference) => preference.key == 'pref_dict_profile_source_7',
    );

    expect(preferenceCodec.decode(override).value, 'remote');
    expect(_unknownMarkers(override), [Int64(51), Int64(52)]);
    expect(_unknownMarkers(override.value), [Int64(53), Int64(54)]);
  });

  test('source preference merge preserves unknown fields from both sides', () {
    final localPreference = _withUnknownMarker(
      preferenceCodec.encode('setting', 'local'),
      3,
    );
    _withUnknownMarker(localPreference.value, 5);
    final remotePreference = _withUnknownMarker(
      preferenceCodec.encode('setting', 'remote'),
      4,
    );
    _withUnknownMarker(remotePreference.value, 6);
    final localSource =
        BackupSourcePreferences(sourceKey: 'source', prefs: [localPreference])
          ..unknownFields.mergeVarintField(90, Int64(1))
          ..unknownFields.mergeLengthDelimitedField(91, [1, 2]);
    final remoteSource =
        BackupSourcePreferences(sourceKey: 'source', prefs: [remotePreference])
          ..unknownFields.mergeVarintField(90, Int64(2))
          ..unknownFields.mergeLengthDelimitedField(92, [3, 4]);

    final merged = merger.merge(
      local: BackupMihon(backupSourcePreferences: [localSource]),
      remote: BackupMihon(backupSourcePreferences: [remoteSource]),
    );

    final source = merged.backupSourcePreferences.single;
    expect(preferenceCodec.decode(source.prefs.single).value, 'remote');
    expect(_unknownMarkers(source.prefs.single), [Int64(3), Int64(4)]);
    expect(_unknownMarkers(source.prefs.single.value), [Int64(5), Int64(6)]);
    expect(source.unknownFields.getField(90)!.varints, [Int64(1), Int64(2)]);
    expect(source.unknownFields.getField(91)!.lengthDelimited, [
      [1, 2],
    ]);
    expect(source.unknownFields.getField(92)!.lengthDelimited, [
      [3, 4],
    ]);
  });

  // Adapted from Chimahon's SyncServiceTest.
  test('preserves anime categories and merges episodes', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupAnime: [
          BackupAnime(
            source: Int64(1),
            url: '/same',
            title: 'Anime',
            version: Int64(2),
            episodes: [
              BackupEpisode(url: '/1', name: 'Episode 1', version: Int64(1)),
            ],
          ),
        ],
      ),
      remote: BackupMihon(
        backupAnime: [
          BackupAnime(
            source: Int64(1),
            url: '/same',
            title: 'Anime',
            version: Int64(1),
            episodes: [
              BackupEpisode(url: '/2', name: 'Episode 2', version: Int64(1)),
            ],
          ),
        ],
      ),
    );

    expect(merged.backupAnime.single.version, Int64(2));
    expect(
      merged.backupAnime.single.episodes.map((episode) => episode.name),
      containsAll(['Episode 1', 'Episode 2']),
    );
  });

  test('preserves Chimahon-only anime hierarchy and season fields', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            description: 'new local metadata',
            lastModifiedAt: Int64(300),
            version: Int64.ZERO,
          ),
        ],
      ),
      remote: BackupMihon(
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            episodeFlags: 3,
            viewerFlags: 4,
            updateStrategy: 5,
            excludedScanlators: const ['Group'],
            backgroundUrl: 'background',
            parentId: Int64(6),
            id: Int64(7),
            seasonFlags: Int64(8),
            seasonNumber: 2.5,
            seasonSourceOrder: Int64(9),
            fetchType: 10,
            lastModifiedAt: Int64(200),
            version: Int64(11),
          ),
        ],
      ),
    );

    final anime = merged.backupAnime.single;
    expect(anime.description, 'new local metadata');
    expect(anime.episodeFlags, 3);
    expect(anime.viewerFlags, 4);
    expect(anime.updateStrategy, 5);
    expect(anime.excludedScanlators, ['Group']);
    expect(anime.backgroundUrl, 'background');
    expect(anime.parentId, Int64(6));
    expect(anime.id, Int64(7));
    expect(anime.seasonFlags, Int64(8));
    expect(anime.seasonNumber, 2.5);
    expect(anime.seasonSourceOrder, Int64(9));
    expect(anime.fetchType, 10);
  });

  test('merges novels while retaining opaque root statistics', () {
    BackupNovel novel(
      int modified,
      int statModified,
      int characters, {
      List<String> categoryIds = const [],
      String? lang,
    }) => BackupNovel(
      id: 'different-device-id-$modified',
      title: 'Novel',
      author: 'Author',
      lastModified: Int64(modified),
      categoryIds: categoryIds,
      lang: lang,
      stats: [
        BackupNovelStat(
          dateKey: '2026-07-10',
          charactersRead: characters,
          lastStatisticModified: Int64(statModified),
        ),
      ],
    );

    final merged = merger.merge(
      local: BackupMihon(
        backupNovels: [
          novel(10, 10, 100, categoryIds: ['default'], lang: 'ja'),
        ],
        backupMangaStats: [
          BackupMangaStats(
            dateKey: '2026-07-10',
            charactersRead: 100,
            readingTime: Int64(200),
            mangaId: Int64(1),
          ),
        ],
      ),
      remote: BackupMihon(
        backupNovels: [
          novel(20, 20, 250, categoryIds: ['reading']),
        ],
        backupMangaStats: [
          BackupMangaStats(
            dateKey: '2026-07-10',
            charactersRead: 250,
            readingTime: Int64(180),
            mangaId: Int64(1),
          ),
        ],
      ),
    );

    expect(merged.backupNovels, hasLength(1));
    expect(merged.backupNovels.single.lastModified, Int64(20));
    expect(merged.backupNovels.single.stats.single.charactersRead, 250);
    expect(merged.backupNovels.single.categoryIds, ['reading']);
    expect(merged.backupNovels.single.lang, 'ja');
    expect(merged.backupMangaStats, hasLength(2));
    expect(
      merged.backupMangaStats.map((stat) => stat.charactersRead),
      containsAll([100, 250]),
    );
    expect(
      merged.backupMangaStats.map((stat) => stat.readingTime),
      containsAll([Int64(200), Int64(180)]),
    );
  });

  test('does not materialize a synthetic default novel category on a tie', () {
    BackupNovel novel({required List<String> categoryIds}) => BackupNovel(
      id: 'wire-id',
      title: 'Novel',
      author: 'Author',
      lastModified: Int64(10),
      categoryIds: categoryIds,
    );

    final merged = merger.merge(
      local: BackupMihon(
        backupNovels: [
          novel(categoryIds: const ['default']),
        ],
      ),
      remote: BackupMihon(backupNovels: [novel(categoryIds: const [])]),
      remoteWinsProjectionTies: true,
    );

    expect(merged.backupNovels.single.categoryIds, isEmpty);
  });

  test('metadata-empty novels merge only by their exact retained IDs', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupNovels: [
          BackupNovel(
            id: 'book-a',
            title: '',
            chapterIndex: 1,
            lastModified: Int64(100),
          ),
        ],
      ),
      remote: BackupMihon(
        backupNovels: [
          BackupNovel(
            id: 'book-a',
            title: ' ',
            chapterIndex: 2,
            lastModified: Int64(200),
          ),
          BackupNovel(
            id: 'book-b',
            title: '',
            chapterIndex: 3,
            lastModified: Int64(300),
          ),
        ],
      ),
    );

    expect(merged.backupNovels, hasLength(2));
    expect(
      merged.backupNovels
          .singleWhere((novel) => novel.id == 'book-a')
          .chapterIndex,
      2,
    );
    expect(
      merged.backupNovels
          .singleWhere((novel) => novel.id == 'book-b')
          .chapterIndex,
      3,
    );
  });

  test('preserves a Chimahon novel cover omitted by local progress', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupNovels: [
          BackupNovel(
            id: 'local-id',
            title: 'Novel',
            author: 'Author',
            chapterIndex: 3,
            lastModified: Int64(300),
          ),
        ],
      ),
      remote: BackupMihon(
        backupNovels: [
          BackupNovel(
            id: 'remote-id',
            title: 'Novel',
            author: 'Author',
            cover: 'cover.jpg',
            chapterIndex: 2,
            lastModified: Int64(200),
          ),
        ],
      ),
    );

    expect(merged.backupNovels.single.chapterIndex, 3);
    expect(merged.backupNovels.single.cover, 'cover.jpg');
  });

  test('preserves a novel cover across duplicate rows on one side', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupNovels: [
          BackupNovel(
            id: 'older-id',
            title: 'Novel',
            author: 'Author',
            cover: 'cover.jpg',
            lastModified: Int64(100),
          ),
          BackupNovel(
            id: 'newer-id',
            title: 'Novel',
            author: 'Author',
            chapterIndex: 4,
            lastModified: Int64(200),
          ),
        ],
      ),
      remote: BackupMihon(),
    );

    expect(merged.backupNovels.single.chapterIndex, 4);
    expect(merged.backupNovels.single.cover, 'cover.jpg');
  });

  test('keeps local novel language while preserving remote cover on a tie', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupNovelCategories: [
          BackupNovelCategory(
            id: 'reading',
            name: 'Reading',
            order: Int64(5),
            flags: Int64(1),
          ),
        ],
        backupNovels: [
          BackupNovel(
            id: 'novel',
            title: 'Novel',
            author: 'Author',
            cover: 'old.jpg',
            lang: 'ja',
            lastModified: Int64(100),
          ),
        ],
      ),
      remote: BackupMihon(
        backupNovelCategories: [
          BackupNovelCategory(
            id: 'reading',
            name: 'Reading',
            order: Int64(2),
            flags: Int64(9),
          ),
        ],
        backupNovels: [
          BackupNovel(
            id: 'novel',
            title: 'Novel',
            author: 'Author',
            cover: 'new.jpg',
            lang: 'en',
            lastModified: Int64(100),
          ),
        ],
      ),
    );

    expect(merged.backupNovels.single.cover, 'new.jpg');
    expect(merged.backupNovels.single.lang, 'ja');
    expect(merged.backupNovelCategories.single.order, Int64(2));
    expect(merged.backupNovelCategories.single.flags, Int64(9));
  });

  test('remaps a name-derived desktop category to the Chimahon wire ID', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupNovelCategories: [
          BackupNovelCategory(
            id: 'desktop-name-hash',
            name: 'Reading',
            order: Int64(4),
          ),
        ],
        backupNovels: [
          BackupNovel(
            title: 'Novel',
            author: 'Author',
            categoryIds: const ['desktop-name-hash'],
          ),
        ],
      ),
      remote: BackupMihon(
        backupNovelCategories: [
          BackupNovelCategory(
            id: 'chimahon-category-uuid',
            name: ' reading ',
            order: Int64(2),
            flags: Int64(9),
          ),
        ],
        backupNovels: [
          BackupNovel(
            title: 'Novel',
            author: 'Author',
            categoryIds: const ['chimahon-category-uuid'],
          ),
        ],
      ),
    );

    expect(merged.backupNovelCategories, hasLength(1));
    expect(merged.backupNovelCategories.single.id, 'chimahon-category-uuid');
    expect(merged.backupNovelCategories.single.flags, Int64(9));
    expect(merged.backupNovels.single.categoryIds, ['chimahon-category-uuid']);
  });

  test('novel merges retain unknown fields on records and daily stats', () {
    BackupNovel novel({
      required int marker,
      required int modified,
      required int statMarker,
      required int statModified,
    }) => _withUnknownMarker(
      BackupNovel(
        id: 'device-$marker',
        title: 'Novel',
        author: 'Author',
        lastModified: Int64(modified),
        categoryIds: ['reading'],
        stats: [
          _withUnknownMarker(
            BackupNovelStat(
              dateKey: '2026-07-10',
              lastStatisticModified: Int64(statModified),
            ),
            statMarker,
          ),
        ],
      ),
      marker,
    );

    final merged = merger.merge(
      local: BackupMihon(
        backupNovelCategories: [
          _withUnknownMarker(
            BackupNovelCategory(
              id: 'reading',
              name: 'Reading',
              order: Int64(1),
            ),
            61,
          ),
        ],
        backupNovels: [
          novel(marker: 63, modified: 20, statMarker: 65, statModified: 10),
        ],
      ),
      remote: BackupMihon(
        backupNovelCategories: [
          _withUnknownMarker(
            BackupNovelCategory(
              id: 'reading',
              name: 'Reading',
              order: Int64(2),
            ),
            62,
          ),
        ],
        backupNovels: [
          novel(marker: 64, modified: 10, statMarker: 66, statModified: 20),
        ],
      ),
    );

    expect(_unknownMarkers(merged.backupNovelCategories.single), [
      Int64(61),
      Int64(62),
    ]);
    expect(_unknownMarkers(merged.backupNovels.single), [Int64(64), Int64(63)]);
    expect(_unknownMarkers(merged.backupNovels.single.stats.single), [
      Int64(65),
      Int64(66),
    ]);
  });

  test('manga statistics preserve both exact opaque rows', () {
    final localStat =
        BackupMangaStats(
            dateKey: '2026-07-10',
            charactersRead: 100,
            readingTime: Int64(200),
            mangaId: Int64(1),
          )
          ..unknownFields.mergeVarintField(90, Int64(1))
          ..unknownFields.mergeLengthDelimitedField(91, [1, 2]);
    final remoteStat =
        BackupMangaStats(
            dateKey: '2026-07-10',
            charactersRead: 250,
            readingTime: Int64(180),
            mangaId: Int64(1),
          )
          ..unknownFields.mergeVarintField(90, Int64(2))
          ..unknownFields.mergeLengthDelimitedField(92, [3, 4]);

    final merged = merger.merge(
      local: BackupMihon(backupMangaStats: [localStat]),
      remote: BackupMihon(backupMangaStats: [remoteStat]),
    );

    expect(merged.backupMangaStats, hasLength(2));
    final local = merged.backupMangaStats.first;
    final remote = merged.backupMangaStats.last;
    expect(local.charactersRead, 100);
    expect(local.readingTime, Int64(200));
    expect(local.unknownFields.getField(90)!.varints, [Int64(1)]);
    expect(local.unknownFields.getField(91)!.lengthDelimited, [
      [1, 2],
    ]);
    expect(remote.charactersRead, 250);
    expect(remote.readingTime, Int64(180));
    expect(remote.unknownFields.getField(90)!.varints, [Int64(2)]);
    expect(remote.unknownFields.getField(92)!.lengthDelimited, [
      [3, 4],
    ]);
  });

  test('Anki statistics preserve both exact opaque rows', () {
    final localStat =
        BackupAnkiStats(
            dateKey: '2026-07-10',
            mangaCards: 7,
            novelCards: 3,
            profileId: 'profile',
            titleId: 'title',
          )
          ..unknownFields.mergeVarintField(90, Int64(1))
          ..unknownFields.mergeLengthDelimitedField(91, [1, 2]);
    final remoteStat =
        BackupAnkiStats(
            dateKey: '2026-07-10',
            mangaCards: 5,
            novelCards: 9,
            profileId: 'profile',
            titleId: 'title',
          )
          ..unknownFields.mergeVarintField(90, Int64(2))
          ..unknownFields.mergeLengthDelimitedField(92, [3, 4]);

    final merged = merger.merge(
      local: BackupMihon(backupAnkiStats: [localStat]),
      remote: BackupMihon(backupAnkiStats: [remoteStat]),
    );

    expect(merged.backupAnkiStats, hasLength(2));
    final local = merged.backupAnkiStats.first;
    final remote = merged.backupAnkiStats.last;
    expect(local.mangaCards, 7);
    expect(local.novelCards, 3);
    expect(local.unknownFields.getField(90)!.varints, [Int64(1)]);
    expect(local.unknownFields.getField(91)!.lengthDelimited, [
      [1, 2],
    ]);
    expect(remote.mangaCards, 5);
    expect(remote.novelCards, 9);
    expect(remote.unknownFields.getField(90)!.varints, [Int64(2)]);
    expect(remote.unknownFields.getField(92)!.lengthDelimited, [
      [3, 4],
    ]);
  });

  test('Anki statistics distinguish absent and explicitly empty title IDs', () {
    final withoutTitle = BackupAnkiStats(
      dateKey: '2026-07-10',
      mangaCards: 7,
      profileId: 'profile',
    );
    final emptyTitle = BackupAnkiStats(
      dateKey: '2026-07-10',
      novelCards: 9,
      profileId: 'profile',
      titleId: '',
    );

    final merged = merger.merge(
      local: BackupMihon(backupAnkiStats: [withoutTitle]),
      remote: BackupMihon(backupAnkiStats: [emptyTitle]),
    );

    expect(merged.backupAnkiStats, hasLength(2));
    expect(merged.backupAnkiStats.map((stat) => stat.hasTitleId()).toList(), [
      isFalse,
      isTrue,
    ]);
  });

  test('promotes a newer unversioned favorite tombstone above remote', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            favorite: false,
            favoriteModifiedAt: Int64(200),
            lastModifiedAt: Int64(200),
            version: Int64.ZERO,
            chapters: [
              BackupChapter(
                url: '/chapter',
                name: 'Chapter',
                read: true,
                lastModifiedAt: Int64(250),
                version: Int64.ZERO,
              ),
            ],
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            favorite: true,
            favoriteModifiedAt: Int64(100),
            lastModifiedAt: Int64(100),
            version: Int64(7),
            chapters: [
              BackupChapter(
                url: '/chapter',
                name: 'Chapter',
                read: false,
                lastModifiedAt: Int64(100),
                version: Int64(5),
              ),
            ],
          ),
        ],
      ),
    );

    final manga = merged.backupManga.single;
    expect(manga.favorite, isFalse);
    expect(manga.favoriteModifiedAt, Int64(200));
    expect(manga.version, Int64(8));
    expect(manga.chapters.single.read, isTrue);
    expect(manga.chapters.single.version, Int64(6));
  });

  test(
    'preserves Chimahon absent favorite while accepting a newer local clock',
    () {
      final merged = merger.merge(
        local: BackupMihon(
          backupManga: [
            BackupManga(
              source: Int64(1),
              url: '/same',
              title: 'Same',
              favorite: true,
              favoriteModifiedAt: Int64(200),
              lastModifiedAt: Int64(200),
              version: Int64.ZERO,
            ),
          ],
        ),
        remote: BackupMihon(
          backupManga: [
            BackupManga(
              source: Int64(1),
              url: '/same',
              title: 'Same',
              favoriteModifiedAt: Int64(100),
              lastModifiedAt: Int64(100),
              version: Int64(7),
            ),
          ],
        ),
      );

      final manga = merged.backupManga.single;
      expect(manga.hasFavorite(), isFalse);
      expect(manga.favoriteModifiedAt, Int64(200));
      expect(manga.version, Int64(8));
    },
  );

  test('keeps a genuinely local favorite when remote has no matching row', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/local-only',
            title: 'Local only',
            favorite: true,
            favoriteModifiedAt: Int64(200),
            lastModifiedAt: Int64(200),
          ),
        ],
      ),
      remote: BackupMihon(),
    );

    final manga = merged.backupManga.single;
    expect(manga.url, '/local-only');
    expect(manga.hasFavorite(), isTrue);
    expect(manga.favorite, isTrue);
  });

  test('fails closed instead of wrapping a maximum Chimahon version', () {
    expect(
      () => merger.merge(
        local: BackupMihon(
          backupManga: [
            BackupManga(
              source: Int64(1),
              url: '/same',
              title: 'Same',
              description: 'new local metadata',
              lastModifiedAt: Int64(200),
              version: Int64.ZERO,
            ),
          ],
        ),
        remote: BackupMihon(
          backupManga: [
            BackupManga(
              source: Int64(1),
              url: '/same',
              title: 'Same',
              description: 'remote metadata',
              lastModifiedAt: Int64(100),
              version: Int64.MAX_VALUE,
            ),
          ],
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Int64.MAX_VALUE'),
        ),
      ),
    );
  });

  test('favorite timestamp is resolved independently from metadata', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            description: 'new local metadata',
            favorite: true,
            favoriteModifiedAt: Int64(100),
            lastModifiedAt: Int64(300),
            version: Int64.ZERO,
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            description: 'old remote metadata',
            favorite: false,
            favoriteModifiedAt: Int64(200),
            lastModifiedAt: Int64(200),
            version: Int64(9),
          ),
        ],
      ),
    );

    final manga = merged.backupManga.single;
    expect(manga.description, 'new local metadata');
    expect(manga.favorite, isFalse);
    expect(manga.favoriteModifiedAt, Int64(200));
    expect(manga.lastModifiedAt, Int64(300));
    expect(manga.version, Int64(10));
  });

  test('real Chimahon versions remain authoritative over timestamps', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            description: 'older counter',
            favorite: false,
            favoriteModifiedAt: Int64(500),
            lastModifiedAt: Int64(999),
            version: Int64(2),
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            description: 'newer counter',
            favorite: true,
            favoriteModifiedAt: Int64(500),
            lastModifiedAt: Int64(1),
            version: Int64(3),
          ),
        ],
      ),
    );

    expect(merged.backupManga.single.description, 'newer counter');
    expect(merged.backupManga.single.favorite, isTrue);
    expect(merged.backupManga.single.version, Int64(3));
  });

  test('anime favorite tombstones use the same independent clock', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupAnime: [
          BackupAnime(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            favorite: false,
            favoriteModifiedAt: Int64(300),
            lastModifiedAt: Int64(300),
            version: Int64.ZERO,
          ),
        ],
      ),
      remote: BackupMihon(
        backupAnime: [
          BackupAnime(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            favorite: true,
            favoriteModifiedAt: Int64(200),
            lastModifiedAt: Int64(200),
            version: Int64(4),
          ),
        ],
      ),
    );

    final anime = merged.backupAnime.single;
    expect(anime.favorite, isFalse);
    expect(anime.favoriteModifiedAt, Int64(300));
    expect(anime.version, Int64(5));
  });

  test('anime preserves Chimahon absent favorite with a newer local clock', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupAnime: [
          BackupAnime(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            favorite: true,
            favoriteModifiedAt: Int64(400),
            lastModifiedAt: Int64(400),
            version: Int64.ZERO,
          ),
        ],
      ),
      remote: BackupMihon(
        backupAnime: [
          BackupAnime(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            favoriteModifiedAt: Int64(300),
            lastModifiedAt: Int64(300),
            version: Int64(4),
          ),
        ],
      ),
    );

    final anime = merged.backupAnime.single;
    expect(anime.hasFavorite(), isFalse);
    expect(anime.favoriteModifiedAt, Int64(400));
    expect(anime.version, Int64(5));
  });

  test('tracking merge keeps loser-only tracker services', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            version: Int64(2),
            tracking: [
              BackupTracking(syncId: 1, title: 'local winner'),
              BackupTracking(syncId: 2, title: 'local only'),
            ],
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            version: Int64(1),
            tracking: [
              BackupTracking(syncId: 1, title: 'remote loser'),
              BackupTracking(syncId: 3, title: 'remote only'),
              BackupTracking(syncId: 4, title: 'remote unsupported'),
            ],
          ),
        ],
      ),
    );

    final tracking = {
      for (final record in merged.backupManga.single.tracking)
        record.syncId: record.title,
    };
    expect(tracking, {
      1: 'local winner',
      2: 'local only',
      3: 'remote only',
      4: 'remote unsupported',
    });
  });

  test('an explicit local tracker deletion removes only that service', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            version: Int64(2),
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            version: Int64(1),
            tracking: [
              BackupTracking(syncId: 3, title: 'deleted Kitsu'),
              BackupTracking(syncId: 4, title: 'unsupported stays opaque'),
            ],
          ),
        ],
      ),
      localTrackingDeletions: const {(source: 1, url: '/same', syncId: 3)},
    );

    expect(merged.backupManga.single.tracking.map((track) => track.syncId), [
      4,
    ]);
  });

  test(
    'durable manga tracker deletion survives a higher-version remote parent',
    () {
      final merged = merger.merge(
        local: BackupMihon(
          backupManga: [
            BackupManga(
              source: Int64(1),
              url: '/same',
              title: 'Same',
              version: Int64(1),
            ),
          ],
        ),
        remote: BackupMihon(
          backupManga: [
            BackupManga(
              source: Int64(1),
              url: '/same',
              title: 'Same',
              version: Int64(9),
              tracking: [
                BackupTracking(syncId: 2, title: 'deleted AniList'),
                BackupTracking(syncId: 4, title: 'opaque Shikimori'),
              ],
            ),
          ],
        ),
        localTrackingDeletions: const {(source: 1, url: '/same', syncId: 2)},
      );

      final manga = merged.backupManga.single;
      expect(manga.version, Int64(9));
      expect(manga.tracking.map((track) => (track.syncId, track.title)), [
        (4, 'opaque Shikimori'),
      ]);
    },
  );

  test(
    'durable anime tracker deletion survives a higher-version remote parent',
    () {
      final merged = merger.merge(
        local: BackupMihon(
          backupAnime: [
            BackupAnime(
              source: Int64(2),
              url: '/same',
              title: 'Same',
              version: Int64(1),
            ),
          ],
        ),
        remote: BackupMihon(
          backupAnime: [
            BackupAnime(
              source: Int64(2),
              url: '/same',
              title: 'Same',
              version: Int64(9),
              tracking: [
                BackupTracking(syncId: 3, title: 'deleted Kitsu'),
                BackupTracking(syncId: 5, title: 'opaque Bangumi'),
              ],
            ),
          ],
        ),
        localTrackingDeletions: const {(source: 2, url: '/same', syncId: 3)},
      );

      final anime = merged.backupAnime.single;
      expect(anime.version, Int64(9));
      expect(anime.tracking.map((track) => (track.syncId, track.title)), [
        (5, 'opaque Bangumi'),
      ]);
    },
  );

  test('current local tracker rows make stale deletion markers harmless', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/manga',
            title: 'Manga',
            version: Int64(1),
            tracking: [BackupTracking(syncId: 1, title: 'local MAL')],
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            version: Int64(1),
            tracking: [BackupTracking(syncId: 3, title: 'local Kitsu')],
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/manga',
            title: 'Manga',
            version: Int64(9),
            tracking: [BackupTracking(syncId: 1, title: 'remote MAL')],
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            version: Int64(9),
            tracking: [BackupTracking(syncId: 3, title: 'remote Kitsu')],
          ),
        ],
      ),
      localTrackingDeletions: const {
        (source: 1, url: '/manga', syncId: 1),
        (source: 2, url: '/anime', syncId: 3),
      },
    );

    expect(merged.backupManga.single.tracking.single.syncId, 1);
    expect(merged.backupManga.single.tracking.single.title, 'remote MAL');
    expect(merged.backupAnime.single.tracking.single.syncId, 3);
    expect(merged.backupAnime.single.tracking.single.title, 'remote Kitsu');
  });

  test('tracking merge retains fields omitted by the local model', () {
    final merged = merger.merge(
      local: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            version: Int64(2),
            tracking: [
              BackupTracking(
                syncId: 2,
                title: 'local winner',
                mediaId: Int64(123),
                lastChapterRead: 132,
                score: 8,
              ),
            ],
          ),
        ],
      ),
      remote: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/same',
            title: 'Same',
            version: Int64(1),
            tracking: [
              BackupTracking(
                syncId: 2,
                title: 'remote loser',
                libraryId: Int64(456),
                mediaIdInt: 123,
                trackingUrl: 'https://anilist.co/manga/123',
                lastChapterRead: 132.01,
                totalChapters: 12,
                score: 8.5,
                status: 1,
                startedReadingDate: Int64(1000),
                finishedReadingDate: Int64(2000),
                private: true,
              ),
            ],
          ),
        ],
      ),
    );

    final tracking = merged.backupManga.single.tracking.single;
    expect(tracking.title, 'local winner');
    expect(tracking.libraryId, Int64(456));
    expect(tracking.mediaId, Int64(123));
    expect(tracking.mediaIdInt, 123);
    expect(tracking.trackingUrl, 'https://anilist.co/manga/123');
    expect(tracking.lastChapterRead, closeTo(132.01, 0.0001));
    expect(tracking.totalChapters, 12);
    expect(tracking.score, closeTo(8.5, 0.0001));
    expect(tracking.status, 1);
    expect(tracking.startedReadingDate, Int64(1000));
    expect(tracking.finishedReadingDate, Int64(2000));
    expect(tracking.private, isTrue);
  });

  test(
    'routine sync keeps exact sparse manga bytes after a clock-only refresh',
    () {
      final remote = _withUnknownMarker(
        BackupManga(
          source: Int64(1),
          url: '/same',
          title: 'Same',
          genre: const ['Drama', 'Action'],
          lastModifiedAt: Int64(100),
          version: Int64(7),
          chapters: [
            _withUnknownMarker(
              BackupChapter(
                url: '/chapter',
                name: 'Chapter 1',
                chapterNumber: 1,
                dateFetch: Int64(50),
                sourceOrder: Int64(9),
                lastModifiedAt: Int64(100),
                version: Int64(5),
              ),
              2,
            ),
          ],
          tracking: [
            BackupTracking(
              syncId: 2,
              title: 'Same',
              mediaIdInt: 123,
              lastChapterRead: 132.01,
              score: 8.5,
              status: 1,
              private: true,
            ),
          ],
        ),
        1,
      );
      final local = BackupManga(
        source: Int64(1),
        url: '/same',
        title: 'Same',
        artist: '',
        author: '',
        description: '',
        thumbnailUrl: '',
        genre: const ['Action', 'Drama'],
        favorite: true,
        initialized: true,
        lastModifiedAt: Int64(200),
        version: Int64.ZERO,
        chapters: [
          BackupChapter(
            url: '/chapter',
            name: 'Chapter 1',
            scanlator: '',
            read: false,
            bookmark: false,
            lastPageRead: Int64.ZERO,
            dateFetch: Int64.ZERO,
            dateUpload: Int64.ZERO,
            chapterNumber: 1,
            sourceOrder: Int64.ZERO,
            lastModifiedAt: Int64(200),
            version: Int64.ZERO,
          ),
        ],
        tracking: [
          BackupTracking(
            syncId: 2,
            title: 'Same',
            mediaId: Int64(123),
            lastChapterRead: 132,
            score: 8,
            status: 1,
          ),
        ],
      );

      final merged = merger.merge(
        local: BackupMihon(backupManga: [local]),
        remote: BackupMihon(backupManga: [remote]),
        remoteWinsProjectionTies: true,
      );

      expect(
        merged.backupManga.single.writeToBuffer(),
        orderedEquals(remote.writeToBuffer()),
      );
    },
  );

  test(
    'routine sync still promotes real newer manga progress and metadata',
    () {
      final merged = merger.merge(
        local: BackupMihon(
          backupManga: [
            BackupManga(
              source: Int64(1),
              url: '/same',
              title: 'Same',
              description: 'new local description',
              lastModifiedAt: Int64(200),
              version: Int64.ZERO,
              chapters: [
                BackupChapter(
                  url: '/chapter',
                  name: 'Chapter 1',
                  chapterNumber: 1,
                  read: true,
                  lastModifiedAt: Int64(200),
                  version: Int64.ZERO,
                ),
              ],
            ),
          ],
        ),
        remote: BackupMihon(
          backupManga: [
            BackupManga(
              source: Int64(1),
              url: '/same',
              title: 'Same',
              description: 'remote description',
              lastModifiedAt: Int64(100),
              version: Int64(7),
              chapters: [
                BackupChapter(
                  url: '/chapter',
                  name: 'Chapter 1',
                  chapterNumber: 1,
                  lastModifiedAt: Int64(100),
                  version: Int64(5),
                ),
              ],
            ),
          ],
        ),
        remoteWinsProjectionTies: true,
      );

      final manga = merged.backupManga.single;
      expect(manga.description, 'new local description');
      expect(manga.lastModifiedAt, Int64(200));
      expect(manga.version, Int64(8));
      expect(manga.chapters.single.read, isTrue);
      expect(manga.chapters.single.lastModifiedAt, Int64(200));
      expect(manga.chapters.single.version, Int64(6));
    },
  );

  test(
    'routine sync keeps exact sparse anime bytes after a clock-only refresh',
    () {
      final remote = _withUnknownMarker(
        BackupAnime(
          source: Int64(2),
          url: '/anime',
          title: 'Anime',
          lastModifiedAt: Int64(100),
          version: Int64(11),
          backgroundUrl: 'remote-only',
          episodes: [
            _withUnknownMarker(
              BackupEpisode(
                url: '/episode',
                name: 'Episode 1',
                episodeNumber: 1,
                dateFetch: Int64(50),
                sourceOrder: Int64(9),
                totalSeconds: Int64(120),
                lastModifiedAt: Int64(100),
                version: Int64(4),
              ),
              4,
            ),
          ],
        ),
        3,
      );
      final local = BackupAnime(
        source: Int64(2),
        url: '/anime',
        title: 'Anime',
        artist: '',
        author: '',
        description: '',
        thumbnailUrl: '',
        favorite: true,
        lastModifiedAt: Int64(200),
        version: Int64.ZERO,
        episodes: [
          BackupEpisode(
            url: '/episode',
            name: 'Episode 1',
            scanlator: '',
            seen: false,
            bookmark: false,
            lastSecondSeen: Int64.ZERO,
            dateFetch: Int64.ZERO,
            dateUpload: Int64.ZERO,
            episodeNumber: 1,
            sourceOrder: Int64.ZERO,
            totalSeconds: Int64.ZERO,
            fillermark: false,
            lastModifiedAt: Int64(200),
            version: Int64.ZERO,
          ),
        ],
      );

      final merged = merger.merge(
        local: BackupMihon(backupAnime: [local]),
        remote: BackupMihon(backupAnime: [remote]),
        remoteWinsProjectionTies: true,
      );

      expect(
        merged.backupAnime.single.writeToBuffer(),
        orderedEquals(remote.writeToBuffer()),
      );
    },
  );

  test(
    'routine sync still promotes real newer anime progress and metadata',
    () {
      final merged = merger.merge(
        local: BackupMihon(
          backupAnime: [
            BackupAnime(
              source: Int64(2),
              url: '/anime',
              title: 'Anime',
              description: 'new local description',
              lastModifiedAt: Int64(200),
              version: Int64.ZERO,
              episodes: [
                BackupEpisode(
                  url: '/episode',
                  name: 'Episode 1',
                  episodeNumber: 1,
                  seen: true,
                  lastSecondSeen: Int64(45),
                  lastModifiedAt: Int64(200),
                  version: Int64.ZERO,
                ),
              ],
            ),
          ],
        ),
        remote: BackupMihon(
          backupAnime: [
            BackupAnime(
              source: Int64(2),
              url: '/anime',
              title: 'Anime',
              description: 'remote description',
              lastModifiedAt: Int64(100),
              version: Int64(11),
              episodes: [
                BackupEpisode(
                  url: '/episode',
                  name: 'Episode 1',
                  episodeNumber: 1,
                  lastModifiedAt: Int64(100),
                  version: Int64(4),
                ),
              ],
            ),
          ],
        ),
        remoteWinsProjectionTies: true,
      );

      final anime = merged.backupAnime.single;
      expect(anime.description, 'new local description');
      expect(anime.lastModifiedAt, Int64(200));
      expect(anime.version, Int64(12));
      expect(anime.episodes.single.seen, isTrue);
      expect(anime.episodes.single.lastSecondSeen, Int64(45));
      expect(anime.episodes.single.version, Int64(5));
    },
  );
}

T _withUnknownMarker<T extends GeneratedMessage>(T message, int marker) {
  message.unknownFields.mergeVarintField(90, Int64(marker));
  return message;
}

List<Int64> _unknownMarkers(GeneratedMessage message) =>
    message.unknownFields.getField(90)?.varints ?? const [];
