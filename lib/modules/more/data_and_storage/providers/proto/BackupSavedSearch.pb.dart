// This is a generated file - do not edit.
//
// Generated from BackupSavedSearch.proto.

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

class BackupSavedSearch extends $pb.GeneratedMessage {
  factory BackupSavedSearch({
    $core.String? name,
    $core.String? query,
    $core.String? filterList,
    $fixnum.Int64? source,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (query != null) result.query = query;
    if (filterList != null) result.filterList = filterList;
    if (source != null) result.source = source;
    return result;
  }

  BackupSavedSearch._();

  factory BackupSavedSearch.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BackupSavedSearch.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupSavedSearch',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'query')
    ..aOS(3, _omitFieldNames ? '' : 'filterList', protoName: 'filterList')
    ..aInt64(4, _omitFieldNames ? '' : 'source')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupSavedSearch clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupSavedSearch copyWith(void Function(BackupSavedSearch) updates) =>
      super.copyWith((message) => updates(message as BackupSavedSearch))
          as BackupSavedSearch;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BackupSavedSearch create() => BackupSavedSearch._();
  @$core.override
  BackupSavedSearch createEmptyInstance() => create();
  static $pb.PbList<BackupSavedSearch> createRepeated() =>
      $pb.PbList<BackupSavedSearch>();
  @$core.pragma('dart2js:noInline')
  static BackupSavedSearch getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackupSavedSearch>(create);
  static BackupSavedSearch? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get query => $_getSZ(1);
  @$pb.TagNumber(2)
  set query($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuery() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuery() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get filterList => $_getSZ(2);
  @$pb.TagNumber(3)
  set filterList($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFilterList() => $_has(2);
  @$pb.TagNumber(3)
  void clearFilterList() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get source => $_getI64(3);
  @$pb.TagNumber(4)
  set source($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSource() => $_has(3);
  @$pb.TagNumber(4)
  void clearSource() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
