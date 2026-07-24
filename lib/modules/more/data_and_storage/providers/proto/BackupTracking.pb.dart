// This is a generated file - do not edit.
//
// Generated from BackupTracking.proto.

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

class BackupTracking extends $pb.GeneratedMessage {
  factory BackupTracking({
    $core.int? syncId,
    $fixnum.Int64? libraryId,
    $core.int? mediaIdInt,
    $core.String? trackingUrl,
    $core.String? title,
    $core.double? lastChapterRead,
    $core.int? totalChapters,
    $core.double? score,
    $core.int? status,
    $fixnum.Int64? startedReadingDate,
    $fixnum.Int64? finishedReadingDate,
    $core.bool? private,
    $fixnum.Int64? mediaId,
  }) {
    final result = create();
    if (syncId != null) result.syncId = syncId;
    if (libraryId != null) result.libraryId = libraryId;
    if (mediaIdInt != null) result.mediaIdInt = mediaIdInt;
    if (trackingUrl != null) result.trackingUrl = trackingUrl;
    if (title != null) result.title = title;
    if (lastChapterRead != null) result.lastChapterRead = lastChapterRead;
    if (totalChapters != null) result.totalChapters = totalChapters;
    if (score != null) result.score = score;
    if (status != null) result.status = status;
    if (startedReadingDate != null)
      result.startedReadingDate = startedReadingDate;
    if (finishedReadingDate != null)
      result.finishedReadingDate = finishedReadingDate;
    if (private != null) result.private = private;
    if (mediaId != null) result.mediaId = mediaId;
    return result;
  }

  BackupTracking._();

  factory BackupTracking.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BackupTracking.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupTracking',
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'syncId', protoName: 'syncId')
    ..aInt64(2, _omitFieldNames ? '' : 'libraryId', protoName: 'libraryId')
    ..aI(3, _omitFieldNames ? '' : 'mediaIdInt', protoName: 'mediaIdInt')
    ..aOS(4, _omitFieldNames ? '' : 'trackingUrl', protoName: 'trackingUrl')
    ..aOS(5, _omitFieldNames ? '' : 'title')
    ..aD(6, _omitFieldNames ? '' : 'lastChapterRead',
        protoName: 'lastChapterRead', fieldType: $pb.PbFieldType.OF)
    ..aI(7, _omitFieldNames ? '' : 'totalChapters', protoName: 'totalChapters')
    ..aD(8, _omitFieldNames ? '' : 'score', fieldType: $pb.PbFieldType.OF)
    ..aI(9, _omitFieldNames ? '' : 'status')
    ..aInt64(10, _omitFieldNames ? '' : 'startedReadingDate',
        protoName: 'startedReadingDate')
    ..aInt64(11, _omitFieldNames ? '' : 'finishedReadingDate',
        protoName: 'finishedReadingDate')
    ..aOB(12, _omitFieldNames ? '' : 'private')
    ..aInt64(100, _omitFieldNames ? '' : 'mediaId', protoName: 'mediaId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupTracking clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupTracking copyWith(void Function(BackupTracking) updates) =>
      super.copyWith((message) => updates(message as BackupTracking))
          as BackupTracking;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BackupTracking create() => BackupTracking._();
  @$core.override
  BackupTracking createEmptyInstance() => create();
  static $pb.PbList<BackupTracking> createRepeated() =>
      $pb.PbList<BackupTracking>();
  @$core.pragma('dart2js:noInline')
  static BackupTracking getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackupTracking>(create);
  static BackupTracking? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get syncId => $_getIZ(0);
  @$pb.TagNumber(1)
  set syncId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSyncId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSyncId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get libraryId => $_getI64(1);
  @$pb.TagNumber(2)
  set libraryId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLibraryId() => $_has(1);
  @$pb.TagNumber(2)
  void clearLibraryId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get mediaIdInt => $_getIZ(2);
  @$pb.TagNumber(3)
  set mediaIdInt($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMediaIdInt() => $_has(2);
  @$pb.TagNumber(3)
  void clearMediaIdInt() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get trackingUrl => $_getSZ(3);
  @$pb.TagNumber(4)
  set trackingUrl($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTrackingUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearTrackingUrl() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get title => $_getSZ(4);
  @$pb.TagNumber(5)
  set title($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTitle() => $_has(4);
  @$pb.TagNumber(5)
  void clearTitle() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get lastChapterRead => $_getN(5);
  @$pb.TagNumber(6)
  set lastChapterRead($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLastChapterRead() => $_has(5);
  @$pb.TagNumber(6)
  void clearLastChapterRead() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get totalChapters => $_getIZ(6);
  @$pb.TagNumber(7)
  set totalChapters($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTotalChapters() => $_has(6);
  @$pb.TagNumber(7)
  void clearTotalChapters() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get score => $_getN(7);
  @$pb.TagNumber(8)
  set score($core.double value) => $_setFloat(7, value);
  @$pb.TagNumber(8)
  $core.bool hasScore() => $_has(7);
  @$pb.TagNumber(8)
  void clearScore() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get status => $_getIZ(8);
  @$pb.TagNumber(9)
  set status($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasStatus() => $_has(8);
  @$pb.TagNumber(9)
  void clearStatus() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get startedReadingDate => $_getI64(9);
  @$pb.TagNumber(10)
  set startedReadingDate($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasStartedReadingDate() => $_has(9);
  @$pb.TagNumber(10)
  void clearStartedReadingDate() => $_clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get finishedReadingDate => $_getI64(10);
  @$pb.TagNumber(11)
  set finishedReadingDate($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasFinishedReadingDate() => $_has(10);
  @$pb.TagNumber(11)
  void clearFinishedReadingDate() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get private => $_getBF(11);
  @$pb.TagNumber(12)
  set private($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasPrivate() => $_has(11);
  @$pb.TagNumber(12)
  void clearPrivate() => $_clearField(12);

  @$pb.TagNumber(100)
  $fixnum.Int64 get mediaId => $_getI64(12);
  @$pb.TagNumber(100)
  set mediaId($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(100)
  $core.bool hasMediaId() => $_has(12);
  @$pb.TagNumber(100)
  void clearMediaId() => $_clearField(100);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
