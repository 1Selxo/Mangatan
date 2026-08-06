// This is a generated file - do not edit.
//
// Generated from BackupSearchHistory.proto.

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

class BackupSearchHistory extends $pb.GeneratedMessage {
  factory BackupSearchHistory({
    $core.String? scope,
    $core.String? query,
    $fixnum.Int64? lastSearchedAt,
  }) {
    final result = create();
    if (scope != null) result.scope = scope;
    if (query != null) result.query = query;
    if (lastSearchedAt != null) result.lastSearchedAt = lastSearchedAt;
    return result;
  }

  BackupSearchHistory._();

  factory BackupSearchHistory.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BackupSearchHistory.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupSearchHistory',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'scope')
    ..aOS(2, _omitFieldNames ? '' : 'query')
    ..aInt64(3, _omitFieldNames ? '' : 'lastSearchedAt',
        protoName: 'lastSearchedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupSearchHistory clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupSearchHistory copyWith(void Function(BackupSearchHistory) updates) =>
      super.copyWith((message) => updates(message as BackupSearchHistory))
          as BackupSearchHistory;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BackupSearchHistory create() => BackupSearchHistory._();
  @$core.override
  BackupSearchHistory createEmptyInstance() => create();
  static $pb.PbList<BackupSearchHistory> createRepeated() =>
      $pb.PbList<BackupSearchHistory>();
  @$core.pragma('dart2js:noInline')
  static BackupSearchHistory getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackupSearchHistory>(create);
  static BackupSearchHistory? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get scope => $_getSZ(0);
  @$pb.TagNumber(1)
  set scope($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasScope() => $_has(0);
  @$pb.TagNumber(1)
  void clearScope() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get query => $_getSZ(1);
  @$pb.TagNumber(2)
  set query($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuery() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuery() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get lastSearchedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set lastSearchedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastSearchedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastSearchedAt() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
