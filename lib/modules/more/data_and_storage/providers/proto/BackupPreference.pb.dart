// This is a generated file - do not edit.
//
// Generated from BackupPreference.proto.

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

/// kotlinx.serialization represents sealed preference values as a polymorphic
/// envelope containing the concrete serial name and its encoded message bytes.
class BackupPreferenceValue extends $pb.GeneratedMessage {
  factory BackupPreferenceValue({
    $core.String? type,
    $core.List<$core.int>? value,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (value != null) result.value = value;
    return result;
  }

  BackupPreferenceValue._();

  factory BackupPreferenceValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BackupPreferenceValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupPreferenceValue',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'type')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupPreferenceValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupPreferenceValue copyWith(
          void Function(BackupPreferenceValue) updates) =>
      super.copyWith((message) => updates(message as BackupPreferenceValue))
          as BackupPreferenceValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BackupPreferenceValue create() => BackupPreferenceValue._();
  @$core.override
  BackupPreferenceValue createEmptyInstance() => create();
  static $pb.PbList<BackupPreferenceValue> createRepeated() =>
      $pb.PbList<BackupPreferenceValue>();
  @$core.pragma('dart2js:noInline')
  static BackupPreferenceValue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackupPreferenceValue>(create);
  static BackupPreferenceValue? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get type => $_getSZ(0);
  @$pb.TagNumber(1)
  set type($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);
}

class BackupPreference extends $pb.GeneratedMessage {
  factory BackupPreference({
    $core.String? key,
    BackupPreferenceValue? value,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (value != null) result.value = value;
    return result;
  }

  BackupPreference._();

  factory BackupPreference.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BackupPreference.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupPreference',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOM<BackupPreferenceValue>(2, _omitFieldNames ? '' : 'value',
        subBuilder: BackupPreferenceValue.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupPreference clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupPreference copyWith(void Function(BackupPreference) updates) =>
      super.copyWith((message) => updates(message as BackupPreference))
          as BackupPreference;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BackupPreference create() => BackupPreference._();
  @$core.override
  BackupPreference createEmptyInstance() => create();
  static $pb.PbList<BackupPreference> createRepeated() =>
      $pb.PbList<BackupPreference>();
  @$core.pragma('dart2js:noInline')
  static BackupPreference getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackupPreference>(create);
  static BackupPreference? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  BackupPreferenceValue get value => $_getN(1);
  @$pb.TagNumber(2)
  set value(BackupPreferenceValue value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);
  @$pb.TagNumber(2)
  BackupPreferenceValue ensureValue() => $_ensure(1);
}

class BackupSourcePreferences extends $pb.GeneratedMessage {
  factory BackupSourcePreferences({
    $core.String? sourceKey,
    $core.Iterable<BackupPreference>? prefs,
  }) {
    final result = create();
    if (sourceKey != null) result.sourceKey = sourceKey;
    if (prefs != null) result.prefs.addAll(prefs);
    return result;
  }

  BackupSourcePreferences._();

  factory BackupSourcePreferences.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BackupSourcePreferences.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupSourcePreferences',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sourceKey', protoName: 'sourceKey')
    ..pPM<BackupPreference>(2, _omitFieldNames ? '' : 'prefs',
        subBuilder: BackupPreference.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupSourcePreferences clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupSourcePreferences copyWith(
          void Function(BackupSourcePreferences) updates) =>
      super.copyWith((message) => updates(message as BackupSourcePreferences))
          as BackupSourcePreferences;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BackupSourcePreferences create() => BackupSourcePreferences._();
  @$core.override
  BackupSourcePreferences createEmptyInstance() => create();
  static $pb.PbList<BackupSourcePreferences> createRepeated() =>
      $pb.PbList<BackupSourcePreferences>();
  @$core.pragma('dart2js:noInline')
  static BackupSourcePreferences getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackupSourcePreferences>(create);
  static BackupSourcePreferences? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sourceKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set sourceKey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSourceKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearSourceKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<BackupPreference> get prefs => $_getList(1);
}

class IntPreferenceValue extends $pb.GeneratedMessage {
  factory IntPreferenceValue({
    $core.int? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  IntPreferenceValue._();

  factory IntPreferenceValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IntPreferenceValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IntPreferenceValue',
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IntPreferenceValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IntPreferenceValue copyWith(void Function(IntPreferenceValue) updates) =>
      super.copyWith((message) => updates(message as IntPreferenceValue))
          as IntPreferenceValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IntPreferenceValue create() => IntPreferenceValue._();
  @$core.override
  IntPreferenceValue createEmptyInstance() => create();
  static $pb.PbList<IntPreferenceValue> createRepeated() =>
      $pb.PbList<IntPreferenceValue>();
  @$core.pragma('dart2js:noInline')
  static IntPreferenceValue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IntPreferenceValue>(create);
  static IntPreferenceValue? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get value => $_getIZ(0);
  @$pb.TagNumber(1)
  set value($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class LongPreferenceValue extends $pb.GeneratedMessage {
  factory LongPreferenceValue({
    $fixnum.Int64? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  LongPreferenceValue._();

  factory LongPreferenceValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LongPreferenceValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LongPreferenceValue',
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LongPreferenceValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LongPreferenceValue copyWith(void Function(LongPreferenceValue) updates) =>
      super.copyWith((message) => updates(message as LongPreferenceValue))
          as LongPreferenceValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LongPreferenceValue create() => LongPreferenceValue._();
  @$core.override
  LongPreferenceValue createEmptyInstance() => create();
  static $pb.PbList<LongPreferenceValue> createRepeated() =>
      $pb.PbList<LongPreferenceValue>();
  @$core.pragma('dart2js:noInline')
  static LongPreferenceValue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LongPreferenceValue>(create);
  static LongPreferenceValue? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get value => $_getI64(0);
  @$pb.TagNumber(1)
  set value($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class FloatPreferenceValue extends $pb.GeneratedMessage {
  factory FloatPreferenceValue({
    $core.double? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  FloatPreferenceValue._();

  factory FloatPreferenceValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FloatPreferenceValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FloatPreferenceValue',
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'value', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FloatPreferenceValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FloatPreferenceValue copyWith(void Function(FloatPreferenceValue) updates) =>
      super.copyWith((message) => updates(message as FloatPreferenceValue))
          as FloatPreferenceValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FloatPreferenceValue create() => FloatPreferenceValue._();
  @$core.override
  FloatPreferenceValue createEmptyInstance() => create();
  static $pb.PbList<FloatPreferenceValue> createRepeated() =>
      $pb.PbList<FloatPreferenceValue>();
  @$core.pragma('dart2js:noInline')
  static FloatPreferenceValue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FloatPreferenceValue>(create);
  static FloatPreferenceValue? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get value => $_getN(0);
  @$pb.TagNumber(1)
  set value($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class StringPreferenceValue extends $pb.GeneratedMessage {
  factory StringPreferenceValue({
    $core.String? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  StringPreferenceValue._();

  factory StringPreferenceValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StringPreferenceValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StringPreferenceValue',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StringPreferenceValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StringPreferenceValue copyWith(
          void Function(StringPreferenceValue) updates) =>
      super.copyWith((message) => updates(message as StringPreferenceValue))
          as StringPreferenceValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StringPreferenceValue create() => StringPreferenceValue._();
  @$core.override
  StringPreferenceValue createEmptyInstance() => create();
  static $pb.PbList<StringPreferenceValue> createRepeated() =>
      $pb.PbList<StringPreferenceValue>();
  @$core.pragma('dart2js:noInline')
  static StringPreferenceValue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StringPreferenceValue>(create);
  static StringPreferenceValue? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class BooleanPreferenceValue extends $pb.GeneratedMessage {
  factory BooleanPreferenceValue({
    $core.bool? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  BooleanPreferenceValue._();

  factory BooleanPreferenceValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BooleanPreferenceValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BooleanPreferenceValue',
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BooleanPreferenceValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BooleanPreferenceValue copyWith(
          void Function(BooleanPreferenceValue) updates) =>
      super.copyWith((message) => updates(message as BooleanPreferenceValue))
          as BooleanPreferenceValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BooleanPreferenceValue create() => BooleanPreferenceValue._();
  @$core.override
  BooleanPreferenceValue createEmptyInstance() => create();
  static $pb.PbList<BooleanPreferenceValue> createRepeated() =>
      $pb.PbList<BooleanPreferenceValue>();
  @$core.pragma('dart2js:noInline')
  static BooleanPreferenceValue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BooleanPreferenceValue>(create);
  static BooleanPreferenceValue? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get value => $_getBF(0);
  @$pb.TagNumber(1)
  set value($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class StringSetPreferenceValue extends $pb.GeneratedMessage {
  factory StringSetPreferenceValue({
    $core.Iterable<$core.String>? value,
  }) {
    final result = create();
    if (value != null) result.value.addAll(value);
    return result;
  }

  StringSetPreferenceValue._();

  factory StringSetPreferenceValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StringSetPreferenceValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StringSetPreferenceValue',
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StringSetPreferenceValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StringSetPreferenceValue copyWith(
          void Function(StringSetPreferenceValue) updates) =>
      super.copyWith((message) => updates(message as StringSetPreferenceValue))
          as StringSetPreferenceValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StringSetPreferenceValue create() => StringSetPreferenceValue._();
  @$core.override
  StringSetPreferenceValue createEmptyInstance() => create();
  static $pb.PbList<StringSetPreferenceValue> createRepeated() =>
      $pb.PbList<StringSetPreferenceValue>();
  @$core.pragma('dart2js:noInline')
  static StringSetPreferenceValue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StringSetPreferenceValue>(create);
  static StringSetPreferenceValue? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get value => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
