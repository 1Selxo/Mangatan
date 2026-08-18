// This is a generated file - do not edit.
//
// Generated from BackupFeed.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use backupFeedDescriptor instead')
const BackupFeed$json = {
  '1': 'BackupFeed',
  '2': [
    {'1': 'source', '3': 1, '4': 1, '5': 3, '10': 'source'},
    {'1': 'global', '3': 2, '4': 1, '5': 8, '10': 'global'},
    {
      '1': 'savedSearch',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.BackupSavedSearch',
      '9': 0,
      '10': 'savedSearch',
      '17': true
    },
  ],
  '8': [
    {'1': '_savedSearch'},
  ],
};

/// Descriptor for `BackupFeed`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backupFeedDescriptor = $convert.base64Decode(
    'CgpCYWNrdXBGZWVkEhYKBnNvdXJjZRgBIAEoA1IGc291cmNlEhYKBmdsb2JhbBgCIAEoCFIGZ2'
    'xvYmFsEjkKC3NhdmVkU2VhcmNoGAkgASgLMhIuQmFja3VwU2F2ZWRTZWFyY2hIAFILc2F2ZWRT'
    'ZWFyY2iIAQFCDgoMX3NhdmVkU2VhcmNo');
