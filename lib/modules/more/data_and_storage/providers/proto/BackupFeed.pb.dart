// This is a generated file - do not edit.
//
// Generated from BackupFeed.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'BackupSavedSearch.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class BackupFeed extends $pb.GeneratedMessage {
  factory BackupFeed({
    $fixnum.Int64? source,
    $core.bool? global,
    $0.BackupSavedSearch? savedSearch,
  }) {
    final result = create();
    if (source != null) result.source = source;
    if (global != null) result.global = global;
    if (savedSearch != null) result.savedSearch = savedSearch;
    return result;
  }

  BackupFeed._();

  factory BackupFeed.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BackupFeed.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupFeed',
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'source')
    ..aOB(2, _omitFieldNames ? '' : 'global')
    ..aOM<$0.BackupSavedSearch>(9, _omitFieldNames ? '' : 'savedSearch',
        protoName: 'savedSearch', subBuilder: $0.BackupSavedSearch.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupFeed clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupFeed copyWith(void Function(BackupFeed) updates) =>
      super.copyWith((message) => updates(message as BackupFeed)) as BackupFeed;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BackupFeed create() => BackupFeed._();
  @$core.override
  BackupFeed createEmptyInstance() => create();
  static $pb.PbList<BackupFeed> createRepeated() => $pb.PbList<BackupFeed>();
  @$core.pragma('dart2js:noInline')
  static BackupFeed getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackupFeed>(create);
  static BackupFeed? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get source => $_getI64(0);
  @$pb.TagNumber(1)
  set source($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSource() => $_has(0);
  @$pb.TagNumber(1)
  void clearSource() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get global => $_getBF(1);
  @$pb.TagNumber(2)
  set global($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGlobal() => $_has(1);
  @$pb.TagNumber(2)
  void clearGlobal() => $_clearField(2);

  @$pb.TagNumber(9)
  $0.BackupSavedSearch get savedSearch => $_getN(2);
  @$pb.TagNumber(9)
  set savedSearch($0.BackupSavedSearch value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasSavedSearch() => $_has(2);
  @$pb.TagNumber(9)
  void clearSavedSearch() => $_clearField(9);
  @$pb.TagNumber(9)
  $0.BackupSavedSearch ensureSavedSearch() => $_ensure(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
