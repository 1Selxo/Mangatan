// This is a generated file - do not edit.
//
// Generated from BackupStatistics.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class BackupMangaStats extends $pb.GeneratedMessage {
  factory BackupMangaStats({
    $core.String? dateKey,
    $core.int? charactersRead,
    $fixnum.Int64? readingTime,
    $fixnum.Int64? mangaId,
  }) {
    final result = create();
    if (dateKey != null) result.dateKey = dateKey;
    if (charactersRead != null) result.charactersRead = charactersRead;
    if (readingTime != null) result.readingTime = readingTime;
    if (mangaId != null) result.mangaId = mangaId;
    return result;
  }

  BackupMangaStats._();

  factory BackupMangaStats.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BackupMangaStats.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupMangaStats',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'dateKey', protoName: 'dateKey')
    ..aI(2, _omitFieldNames ? '' : 'charactersRead',
        protoName: 'charactersRead')
    ..aInt64(3, _omitFieldNames ? '' : 'readingTime', protoName: 'readingTime')
    ..aInt64(4, _omitFieldNames ? '' : 'mangaId', protoName: 'mangaId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupMangaStats clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupMangaStats copyWith(void Function(BackupMangaStats) updates) =>
      super.copyWith((message) => updates(message as BackupMangaStats))
          as BackupMangaStats;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BackupMangaStats create() => BackupMangaStats._();
  @$core.override
  BackupMangaStats createEmptyInstance() => create();
  static $pb.PbList<BackupMangaStats> createRepeated() =>
      $pb.PbList<BackupMangaStats>();
  @$core.pragma('dart2js:noInline')
  static BackupMangaStats getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackupMangaStats>(create);
  static BackupMangaStats? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get dateKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set dateKey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDateKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearDateKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get charactersRead => $_getIZ(1);
  @$pb.TagNumber(2)
  set charactersRead($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCharactersRead() => $_has(1);
  @$pb.TagNumber(2)
  void clearCharactersRead() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get readingTime => $_getI64(2);
  @$pb.TagNumber(3)
  set readingTime($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReadingTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearReadingTime() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get mangaId => $_getI64(3);
  @$pb.TagNumber(4)
  set mangaId($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMangaId() => $_has(3);
  @$pb.TagNumber(4)
  void clearMangaId() => $_clearField(4);
}

class BackupAnkiStats extends $pb.GeneratedMessage {
  factory BackupAnkiStats({
    $core.String? dateKey,
    $core.int? mangaCards,
    $core.int? novelCards,
    $core.String? profileId,
    $core.String? titleId,
  }) {
    final result = create();
    if (dateKey != null) result.dateKey = dateKey;
    if (mangaCards != null) result.mangaCards = mangaCards;
    if (novelCards != null) result.novelCards = novelCards;
    if (profileId != null) result.profileId = profileId;
    if (titleId != null) result.titleId = titleId;
    return result;
  }

  BackupAnkiStats._();

  factory BackupAnkiStats.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BackupAnkiStats.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupAnkiStats',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'dateKey', protoName: 'dateKey')
    ..aI(2, _omitFieldNames ? '' : 'mangaCards', protoName: 'mangaCards')
    ..aI(3, _omitFieldNames ? '' : 'novelCards', protoName: 'novelCards')
    ..aOS(4, _omitFieldNames ? '' : 'profileId', protoName: 'profileId')
    ..aOS(5, _omitFieldNames ? '' : 'titleId', protoName: 'titleId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupAnkiStats clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupAnkiStats copyWith(void Function(BackupAnkiStats) updates) =>
      super.copyWith((message) => updates(message as BackupAnkiStats))
          as BackupAnkiStats;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BackupAnkiStats create() => BackupAnkiStats._();
  @$core.override
  BackupAnkiStats createEmptyInstance() => create();
  static $pb.PbList<BackupAnkiStats> createRepeated() =>
      $pb.PbList<BackupAnkiStats>();
  @$core.pragma('dart2js:noInline')
  static BackupAnkiStats getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackupAnkiStats>(create);
  static BackupAnkiStats? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get dateKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set dateKey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDateKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearDateKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get mangaCards => $_getIZ(1);
  @$pb.TagNumber(2)
  set mangaCards($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMangaCards() => $_has(1);
  @$pb.TagNumber(2)
  void clearMangaCards() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get novelCards => $_getIZ(2);
  @$pb.TagNumber(3)
  set novelCards($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNovelCards() => $_has(2);
  @$pb.TagNumber(3)
  void clearNovelCards() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get profileId => $_getSZ(3);
  @$pb.TagNumber(4)
  set profileId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasProfileId() => $_has(3);
  @$pb.TagNumber(4)
  void clearProfileId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get titleId => $_getSZ(4);
  @$pb.TagNumber(5)
  set titleId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTitleId() => $_has(4);
  @$pb.TagNumber(5)
  void clearTitleId() => $_clearField(5);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
