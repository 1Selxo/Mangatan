// This is a generated file - do not edit.
//
// Generated from BackupStatistics.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use backupMangaStatsDescriptor instead')
const BackupMangaStats$json = {
  '1': 'BackupMangaStats',
  '2': [
    {'1': 'dateKey', '3': 1, '4': 1, '5': 9, '10': 'dateKey'},
    {'1': 'charactersRead', '3': 2, '4': 1, '5': 5, '10': 'charactersRead'},
    {'1': 'readingTime', '3': 3, '4': 1, '5': 3, '10': 'readingTime'},
    {'1': 'mangaId', '3': 4, '4': 1, '5': 3, '10': 'mangaId'},
  ],
};

/// Descriptor for `BackupMangaStats`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backupMangaStatsDescriptor = $convert.base64Decode(
    'ChBCYWNrdXBNYW5nYVN0YXRzEhgKB2RhdGVLZXkYASABKAlSB2RhdGVLZXkSJgoOY2hhcmFjdG'
    'Vyc1JlYWQYAiABKAVSDmNoYXJhY3RlcnNSZWFkEiAKC3JlYWRpbmdUaW1lGAMgASgDUgtyZWFk'
    'aW5nVGltZRIYCgdtYW5nYUlkGAQgASgDUgdtYW5nYUlk');

@$core.Deprecated('Use backupAnkiStatsDescriptor instead')
const BackupAnkiStats$json = {
  '1': 'BackupAnkiStats',
  '2': [
    {'1': 'dateKey', '3': 1, '4': 1, '5': 9, '10': 'dateKey'},
    {'1': 'mangaCards', '3': 2, '4': 1, '5': 5, '10': 'mangaCards'},
    {'1': 'novelCards', '3': 3, '4': 1, '5': 5, '10': 'novelCards'},
    {'1': 'profileId', '3': 4, '4': 1, '5': 9, '10': 'profileId'},
    {
      '1': 'titleId',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'titleId',
      '17': true
    },
  ],
  '8': [
    {'1': '_titleId'},
  ],
};

/// Descriptor for `BackupAnkiStats`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backupAnkiStatsDescriptor = $convert.base64Decode(
    'Cg9CYWNrdXBBbmtpU3RhdHMSGAoHZGF0ZUtleRgBIAEoCVIHZGF0ZUtleRIeCgptYW5nYUNhcm'
    'RzGAIgASgFUgptYW5nYUNhcmRzEh4KCm5vdmVsQ2FyZHMYAyABKAVSCm5vdmVsQ2FyZHMSHAoJ'
    'cHJvZmlsZUlkGAQgASgJUglwcm9maWxlSWQSHQoHdGl0bGVJZBgFIAEoCUgAUgd0aXRsZUlkiA'
    'EBQgoKCF90aXRsZUlk');
