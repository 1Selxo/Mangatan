// This is a generated file - do not edit.
//
// Generated from BackupPreference.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use backupPreferenceValueDescriptor instead')
const BackupPreferenceValue$json = {
  '1': 'BackupPreferenceValue',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 9, '10': 'type'},
    {'1': 'value', '3': 2, '4': 1, '5': 12, '10': 'value'},
  ],
};

/// Descriptor for `BackupPreferenceValue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backupPreferenceValueDescriptor = $convert.base64Decode(
    'ChVCYWNrdXBQcmVmZXJlbmNlVmFsdWUSEgoEdHlwZRgBIAEoCVIEdHlwZRIUCgV2YWx1ZRgCIA'
    'EoDFIFdmFsdWU=');

@$core.Deprecated('Use backupPreferenceDescriptor instead')
const BackupPreference$json = {
  '1': 'BackupPreference',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.BackupPreferenceValue',
      '10': 'value'
    },
  ],
};

/// Descriptor for `BackupPreference`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backupPreferenceDescriptor = $convert.base64Decode(
    'ChBCYWNrdXBQcmVmZXJlbmNlEhAKA2tleRgBIAEoCVIDa2V5EiwKBXZhbHVlGAIgASgLMhYuQm'
    'Fja3VwUHJlZmVyZW5jZVZhbHVlUgV2YWx1ZQ==');

@$core.Deprecated('Use backupSourcePreferencesDescriptor instead')
const BackupSourcePreferences$json = {
  '1': 'BackupSourcePreferences',
  '2': [
    {'1': 'sourceKey', '3': 1, '4': 1, '5': 9, '10': 'sourceKey'},
    {
      '1': 'prefs',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.BackupPreference',
      '10': 'prefs'
    },
  ],
};

/// Descriptor for `BackupSourcePreferences`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backupSourcePreferencesDescriptor =
    $convert.base64Decode(
        'ChdCYWNrdXBTb3VyY2VQcmVmZXJlbmNlcxIcCglzb3VyY2VLZXkYASABKAlSCXNvdXJjZUtleR'
        'InCgVwcmVmcxgCIAMoCzIRLkJhY2t1cFByZWZlcmVuY2VSBXByZWZz');

@$core.Deprecated('Use intPreferenceValueDescriptor instead')
const IntPreferenceValue$json = {
  '1': 'IntPreferenceValue',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 5, '10': 'value'},
  ],
};

/// Descriptor for `IntPreferenceValue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List intPreferenceValueDescriptor = $convert
    .base64Decode('ChJJbnRQcmVmZXJlbmNlVmFsdWUSFAoFdmFsdWUYASABKAVSBXZhbHVl');

@$core.Deprecated('Use longPreferenceValueDescriptor instead')
const LongPreferenceValue$json = {
  '1': 'LongPreferenceValue',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 3, '10': 'value'},
  ],
};

/// Descriptor for `LongPreferenceValue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List longPreferenceValueDescriptor =
    $convert.base64Decode(
        'ChNMb25nUHJlZmVyZW5jZVZhbHVlEhQKBXZhbHVlGAEgASgDUgV2YWx1ZQ==');

@$core.Deprecated('Use floatPreferenceValueDescriptor instead')
const FloatPreferenceValue$json = {
  '1': 'FloatPreferenceValue',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 2, '10': 'value'},
  ],
};

/// Descriptor for `FloatPreferenceValue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List floatPreferenceValueDescriptor =
    $convert.base64Decode(
        'ChRGbG9hdFByZWZlcmVuY2VWYWx1ZRIUCgV2YWx1ZRgBIAEoAlIFdmFsdWU=');

@$core.Deprecated('Use stringPreferenceValueDescriptor instead')
const StringPreferenceValue$json = {
  '1': 'StringPreferenceValue',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `StringPreferenceValue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stringPreferenceValueDescriptor =
    $convert.base64Decode(
        'ChVTdHJpbmdQcmVmZXJlbmNlVmFsdWUSFAoFdmFsdWUYASABKAlSBXZhbHVl');

@$core.Deprecated('Use booleanPreferenceValueDescriptor instead')
const BooleanPreferenceValue$json = {
  '1': 'BooleanPreferenceValue',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
  ],
};

/// Descriptor for `BooleanPreferenceValue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List booleanPreferenceValueDescriptor =
    $convert.base64Decode(
        'ChZCb29sZWFuUHJlZmVyZW5jZVZhbHVlEhQKBXZhbHVlGAEgASgIUgV2YWx1ZQ==');

@$core.Deprecated('Use stringSetPreferenceValueDescriptor instead')
const StringSetPreferenceValue$json = {
  '1': 'StringSetPreferenceValue',
  '2': [
    {'1': 'value', '3': 1, '4': 3, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `StringSetPreferenceValue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stringSetPreferenceValueDescriptor =
    $convert.base64Decode(
        'ChhTdHJpbmdTZXRQcmVmZXJlbmNlVmFsdWUSFAoFdmFsdWUYASADKAlSBXZhbHVl');
