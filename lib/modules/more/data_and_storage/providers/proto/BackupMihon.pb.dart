// This is a generated file - do not edit.
//
// Generated from BackupMihon.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'BackupAnime.pb.dart' as $5;
import 'BackupCategory.pb.dart' as $1;
import 'BackupExtensionRepos.pb.dart' as $4;
import 'BackupFeed.pb.dart' as $7;
import 'BackupManga.pb.dart' as $0;
import 'BackupNovel.pb.dart' as $8;
import 'BackupPreference.pb.dart' as $3;
import 'BackupSavedSearch.pb.dart' as $6;
import 'BackupSource.pb.dart' as $2;
import 'BackupStatistics.pb.dart' as $9;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class BackupMihon extends $pb.GeneratedMessage {
  factory BackupMihon({
    $core.Iterable<$0.BackupManga>? backupManga,
    $core.Iterable<$1.BackupCategory>? backupCategories,
    $core.Iterable<$2.BackupSource>? backupSources,
    $core.Iterable<$3.BackupPreference>? backupPreferences,
    $core.Iterable<$3.BackupSourcePreferences>? backupSourcePreferences,
    $core.Iterable<$4.BackupExtensionRepos>? backupExtensionRepo,
    $core.Iterable<$5.BackupAnime>? backupAnime,
    $core.Iterable<$1.BackupCategory>? backupAnimeCategories,
    $core.Iterable<$2.BackupSource>? backupAnimeSources,
    $core.Iterable<$4.BackupExtensionRepos>? backupAnimeExtensionRepo,
    $core.Iterable<$6.BackupSavedSearch>? backupSavedSearches,
    $core.Iterable<$7.BackupFeed>? backupFeeds,
    $core.Iterable<$8.BackupNovel>? backupNovels,
    $core.Iterable<$8.BackupNovelCategory>? backupNovelCategories,
    $core.Iterable<$9.BackupMangaStats>? backupMangaStats,
    $core.Iterable<$9.BackupAnkiStats>? backupAnkiStats,
  }) {
    final result = create();
    if (backupManga != null) result.backupManga.addAll(backupManga);
    if (backupCategories != null)
      result.backupCategories.addAll(backupCategories);
    if (backupSources != null) result.backupSources.addAll(backupSources);
    if (backupPreferences != null)
      result.backupPreferences.addAll(backupPreferences);
    if (backupSourcePreferences != null)
      result.backupSourcePreferences.addAll(backupSourcePreferences);
    if (backupExtensionRepo != null)
      result.backupExtensionRepo.addAll(backupExtensionRepo);
    if (backupAnime != null) result.backupAnime.addAll(backupAnime);
    if (backupAnimeCategories != null)
      result.backupAnimeCategories.addAll(backupAnimeCategories);
    if (backupAnimeSources != null)
      result.backupAnimeSources.addAll(backupAnimeSources);
    if (backupAnimeExtensionRepo != null)
      result.backupAnimeExtensionRepo.addAll(backupAnimeExtensionRepo);
    if (backupSavedSearches != null)
      result.backupSavedSearches.addAll(backupSavedSearches);
    if (backupFeeds != null) result.backupFeeds.addAll(backupFeeds);
    if (backupNovels != null) result.backupNovels.addAll(backupNovels);
    if (backupNovelCategories != null)
      result.backupNovelCategories.addAll(backupNovelCategories);
    if (backupMangaStats != null)
      result.backupMangaStats.addAll(backupMangaStats);
    if (backupAnkiStats != null) result.backupAnkiStats.addAll(backupAnkiStats);
    return result;
  }

  BackupMihon._();

  factory BackupMihon.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BackupMihon.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupMihon',
      createEmptyInstance: create)
    ..pPM<$0.BackupManga>(1, _omitFieldNames ? '' : 'backupManga',
        protoName: 'backupManga', subBuilder: $0.BackupManga.create)
    ..pPM<$1.BackupCategory>(2, _omitFieldNames ? '' : 'backupCategories',
        protoName: 'backupCategories', subBuilder: $1.BackupCategory.create)
    ..pPM<$2.BackupSource>(101, _omitFieldNames ? '' : 'backupSources',
        protoName: 'backupSources', subBuilder: $2.BackupSource.create)
    ..pPM<$3.BackupPreference>(104, _omitFieldNames ? '' : 'backupPreferences',
        protoName: 'backupPreferences', subBuilder: $3.BackupPreference.create)
    ..pPM<$3.BackupSourcePreferences>(
        105, _omitFieldNames ? '' : 'backupSourcePreferences',
        protoName: 'backupSourcePreferences',
        subBuilder: $3.BackupSourcePreferences.create)
    ..pPM<$4.BackupExtensionRepos>(
        106, _omitFieldNames ? '' : 'backupExtensionRepo',
        protoName: 'backupExtensionRepo',
        subBuilder: $4.BackupExtensionRepos.create)
    ..pPM<$5.BackupAnime>(501, _omitFieldNames ? '' : 'backupAnime',
        protoName: 'backupAnime', subBuilder: $5.BackupAnime.create)
    ..pPM<$1.BackupCategory>(
        502, _omitFieldNames ? '' : 'backupAnimeCategories',
        protoName: 'backupAnimeCategories',
        subBuilder: $1.BackupCategory.create)
    ..pPM<$2.BackupSource>(503, _omitFieldNames ? '' : 'backupAnimeSources',
        protoName: 'backupAnimeSources', subBuilder: $2.BackupSource.create)
    ..pPM<$4.BackupExtensionRepos>(
        505, _omitFieldNames ? '' : 'backupAnimeExtensionRepo',
        protoName: 'backupAnimeExtensionRepo',
        subBuilder: $4.BackupExtensionRepos.create)
    ..pPM<$6.BackupSavedSearch>(
        600, _omitFieldNames ? '' : 'backupSavedSearches',
        protoName: 'backupSavedSearches',
        subBuilder: $6.BackupSavedSearch.create)
    ..pPM<$7.BackupFeed>(610, _omitFieldNames ? '' : 'backupFeeds',
        protoName: 'backupFeeds', subBuilder: $7.BackupFeed.create)
    ..pPM<$8.BackupNovel>(700, _omitFieldNames ? '' : 'backupNovels',
        protoName: 'backupNovels', subBuilder: $8.BackupNovel.create)
    ..pPM<$8.BackupNovelCategory>(
        701, _omitFieldNames ? '' : 'backupNovelCategories',
        protoName: 'backupNovelCategories',
        subBuilder: $8.BackupNovelCategory.create)
    ..pPM<$9.BackupMangaStats>(710, _omitFieldNames ? '' : 'backupMangaStats',
        protoName: 'backupMangaStats', subBuilder: $9.BackupMangaStats.create)
    ..pPM<$9.BackupAnkiStats>(711, _omitFieldNames ? '' : 'backupAnkiStats',
        protoName: 'backupAnkiStats', subBuilder: $9.BackupAnkiStats.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupMihon clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupMihon copyWith(void Function(BackupMihon) updates) =>
      super.copyWith((message) => updates(message as BackupMihon))
          as BackupMihon;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BackupMihon create() => BackupMihon._();
  @$core.override
  BackupMihon createEmptyInstance() => create();
  static $pb.PbList<BackupMihon> createRepeated() => $pb.PbList<BackupMihon>();
  @$core.pragma('dart2js:noInline')
  static BackupMihon getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackupMihon>(create);
  static BackupMihon? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$0.BackupManga> get backupManga => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<$1.BackupCategory> get backupCategories => $_getList(1);

  @$pb.TagNumber(101)
  $pb.PbList<$2.BackupSource> get backupSources => $_getList(2);

  @$pb.TagNumber(104)
  $pb.PbList<$3.BackupPreference> get backupPreferences => $_getList(3);

  @$pb.TagNumber(105)
  $pb.PbList<$3.BackupSourcePreferences> get backupSourcePreferences =>
      $_getList(4);

  @$pb.TagNumber(106)
  $pb.PbList<$4.BackupExtensionRepos> get backupExtensionRepo => $_getList(5);

  /// Aniyomi/Anikku fields used by Chimahon's common backup envelope.
  @$pb.TagNumber(501)
  $pb.PbList<$5.BackupAnime> get backupAnime => $_getList(6);

  @$pb.TagNumber(502)
  $pb.PbList<$1.BackupCategory> get backupAnimeCategories => $_getList(7);

  @$pb.TagNumber(503)
  $pb.PbList<$2.BackupSource> get backupAnimeSources => $_getList(8);

  @$pb.TagNumber(505)
  $pb.PbList<$4.BackupExtensionRepos> get backupAnimeExtensionRepo =>
      $_getList(9);

  /// TachiyomiSY and Komikku additions.
  @$pb.TagNumber(600)
  $pb.PbList<$6.BackupSavedSearch> get backupSavedSearches => $_getList(10);

  @$pb.TagNumber(610)
  $pb.PbList<$7.BackupFeed> get backupFeeds => $_getList(11);

  /// Chimahon additions. Keep these tags stable for cross-device sync.
  @$pb.TagNumber(700)
  $pb.PbList<$8.BackupNovel> get backupNovels => $_getList(12);

  @$pb.TagNumber(701)
  $pb.PbList<$8.BackupNovelCategory> get backupNovelCategories => $_getList(13);

  @$pb.TagNumber(710)
  $pb.PbList<$9.BackupMangaStats> get backupMangaStats => $_getList(14);

  @$pb.TagNumber(711)
  $pb.PbList<$9.BackupAnkiStats> get backupAnkiStats => $_getList(15);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
