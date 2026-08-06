// This is a generated file - do not edit.
//
// Generated from BackupExtensionStore.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class BackupExtensionStore extends $pb.GeneratedMessage {
  factory BackupExtensionStore({
    $core.String? indexUrl,
    $core.String? name,
    $core.String? badgeLabel,
    $core.String? contactWebsite,
    $core.String? signingKey,
    $core.String? contactDiscord,
    $core.bool? isLegacy,
    $core.String? extensionListUrl,
  }) {
    final result = create();
    if (indexUrl != null) result.indexUrl = indexUrl;
    if (name != null) result.name = name;
    if (badgeLabel != null) result.badgeLabel = badgeLabel;
    if (contactWebsite != null) result.contactWebsite = contactWebsite;
    if (signingKey != null) result.signingKey = signingKey;
    if (contactDiscord != null) result.contactDiscord = contactDiscord;
    if (isLegacy != null) result.isLegacy = isLegacy;
    if (extensionListUrl != null) result.extensionListUrl = extensionListUrl;
    return result;
  }

  BackupExtensionStore._();

  factory BackupExtensionStore.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BackupExtensionStore.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupExtensionStore',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'indexUrl', protoName: 'indexUrl')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'badgeLabel', protoName: 'badgeLabel')
    ..aOS(4, _omitFieldNames ? '' : 'contactWebsite',
        protoName: 'contactWebsite')
    ..aOS(5, _omitFieldNames ? '' : 'signingKey', protoName: 'signingKey')
    ..aOS(6, _omitFieldNames ? '' : 'contactDiscord',
        protoName: 'contactDiscord')
    ..aOB(7, _omitFieldNames ? '' : 'isLegacy', protoName: 'isLegacy')
    ..aOS(8, _omitFieldNames ? '' : 'extensionListUrl',
        protoName: 'extensionListUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupExtensionStore clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupExtensionStore copyWith(void Function(BackupExtensionStore) updates) =>
      super.copyWith((message) => updates(message as BackupExtensionStore))
          as BackupExtensionStore;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BackupExtensionStore create() => BackupExtensionStore._();
  @$core.override
  BackupExtensionStore createEmptyInstance() => create();
  static $pb.PbList<BackupExtensionStore> createRepeated() =>
      $pb.PbList<BackupExtensionStore>();
  @$core.pragma('dart2js:noInline')
  static BackupExtensionStore getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackupExtensionStore>(create);
  static BackupExtensionStore? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get indexUrl => $_getSZ(0);
  @$pb.TagNumber(1)
  set indexUrl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIndexUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndexUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get badgeLabel => $_getSZ(2);
  @$pb.TagNumber(3)
  set badgeLabel($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBadgeLabel() => $_has(2);
  @$pb.TagNumber(3)
  void clearBadgeLabel() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get contactWebsite => $_getSZ(3);
  @$pb.TagNumber(4)
  set contactWebsite($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasContactWebsite() => $_has(3);
  @$pb.TagNumber(4)
  void clearContactWebsite() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get signingKey => $_getSZ(4);
  @$pb.TagNumber(5)
  set signingKey($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSigningKey() => $_has(4);
  @$pb.TagNumber(5)
  void clearSigningKey() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get contactDiscord => $_getSZ(5);
  @$pb.TagNumber(6)
  set contactDiscord($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasContactDiscord() => $_has(5);
  @$pb.TagNumber(6)
  void clearContactDiscord() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get isLegacy => $_getBF(6);
  @$pb.TagNumber(7)
  set isLegacy($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIsLegacy() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsLegacy() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get extensionListUrl => $_getSZ(7);
  @$pb.TagNumber(8)
  set extensionListUrl($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasExtensionListUrl() => $_has(7);
  @$pb.TagNumber(8)
  void clearExtensionListUrl() => $_clearField(8);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
