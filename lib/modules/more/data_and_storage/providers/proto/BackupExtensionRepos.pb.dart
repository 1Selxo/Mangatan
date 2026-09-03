// This is a generated file - do not edit.
//
// Generated from BackupExtensionRepos.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class BackupExtensionRepos extends $pb.GeneratedMessage {
  factory BackupExtensionRepos({
    $core.String? baseUrl,
    $core.String? name,
    $core.String? shortName,
    $core.String? website,
    $core.String? signingKeyFingerprint,
  }) {
    final result = create();
    if (baseUrl != null) result.baseUrl = baseUrl;
    if (name != null) result.name = name;
    if (shortName != null) result.shortName = shortName;
    if (website != null) result.website = website;
    if (signingKeyFingerprint != null)
      result.signingKeyFingerprint = signingKeyFingerprint;
    return result;
  }

  BackupExtensionRepos._();

  factory BackupExtensionRepos.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BackupExtensionRepos.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupExtensionRepos',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'baseUrl', protoName: 'baseUrl')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'shortName', protoName: 'shortName')
    ..aOS(4, _omitFieldNames ? '' : 'website')
    ..aOS(5, _omitFieldNames ? '' : 'signingKeyFingerprint',
        protoName: 'signingKeyFingerprint')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupExtensionRepos clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupExtensionRepos copyWith(void Function(BackupExtensionRepos) updates) =>
      super.copyWith((message) => updates(message as BackupExtensionRepos))
          as BackupExtensionRepos;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BackupExtensionRepos create() => BackupExtensionRepos._();
  @$core.override
  BackupExtensionRepos createEmptyInstance() => create();
  static $pb.PbList<BackupExtensionRepos> createRepeated() =>
      $pb.PbList<BackupExtensionRepos>();
  @$core.pragma('dart2js:noInline')
  static BackupExtensionRepos getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackupExtensionRepos>(create);
  static BackupExtensionRepos? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get baseUrl => $_getSZ(0);
  @$pb.TagNumber(1)
  set baseUrl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBaseUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearBaseUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get shortName => $_getSZ(2);
  @$pb.TagNumber(3)
  set shortName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasShortName() => $_has(2);
  @$pb.TagNumber(3)
  void clearShortName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get website => $_getSZ(3);
  @$pb.TagNumber(4)
  set website($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasWebsite() => $_has(3);
  @$pb.TagNumber(4)
  void clearWebsite() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get signingKeyFingerprint => $_getSZ(4);
  @$pb.TagNumber(5)
  set signingKeyFingerprint($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSigningKeyFingerprint() => $_has(4);
  @$pb.TagNumber(5)
  void clearSigningKeyFingerprint() => $_clearField(5);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
