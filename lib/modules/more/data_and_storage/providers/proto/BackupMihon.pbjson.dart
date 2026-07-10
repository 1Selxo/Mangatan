// This is a generated file - do not edit.
//
// Generated from BackupMihon.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use backupMihonDescriptor instead')
const BackupMihon$json = {
  '1': 'BackupMihon',
  '2': [
    {
      '1': 'backupManga',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.BackupManga',
      '10': 'backupManga'
    },
    {
      '1': 'backupCategories',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.BackupCategory',
      '10': 'backupCategories'
    },
    {
      '1': 'backupSources',
      '3': 101,
      '4': 3,
      '5': 11,
      '6': '.BackupSource',
      '10': 'backupSources'
    },
    {
      '1': 'backupPreferences',
      '3': 104,
      '4': 3,
      '5': 11,
      '6': '.BackupPreference',
      '10': 'backupPreferences'
    },
    {
      '1': 'backupSourcePreferences',
      '3': 105,
      '4': 3,
      '5': 11,
      '6': '.BackupSourcePreferences',
      '10': 'backupSourcePreferences'
    },
    {
      '1': 'backupExtensionRepo',
      '3': 106,
      '4': 3,
      '5': 11,
      '6': '.BackupExtensionRepos',
      '10': 'backupExtensionRepo'
    },
    {
      '1': 'backupAnime',
      '3': 501,
      '4': 3,
      '5': 11,
      '6': '.BackupAnime',
      '10': 'backupAnime'
    },
    {
      '1': 'backupAnimeCategories',
      '3': 502,
      '4': 3,
      '5': 11,
      '6': '.BackupCategory',
      '10': 'backupAnimeCategories'
    },
    {
      '1': 'backupAnimeSources',
      '3': 503,
      '4': 3,
      '5': 11,
      '6': '.BackupSource',
      '10': 'backupAnimeSources'
    },
    {
      '1': 'backupAnimeExtensionRepo',
      '3': 505,
      '4': 3,
      '5': 11,
      '6': '.BackupExtensionRepos',
      '10': 'backupAnimeExtensionRepo'
    },
    {
      '1': 'backupSavedSearches',
      '3': 600,
      '4': 3,
      '5': 11,
      '6': '.BackupSavedSearch',
      '10': 'backupSavedSearches'
    },
    {
      '1': 'backupFeeds',
      '3': 610,
      '4': 3,
      '5': 11,
      '6': '.BackupFeed',
      '10': 'backupFeeds'
    },
    {
      '1': 'backupNovels',
      '3': 700,
      '4': 3,
      '5': 11,
      '6': '.BackupNovel',
      '10': 'backupNovels'
    },
    {
      '1': 'backupNovelCategories',
      '3': 701,
      '4': 3,
      '5': 11,
      '6': '.BackupNovelCategory',
      '10': 'backupNovelCategories'
    },
    {
      '1': 'backupMangaStats',
      '3': 710,
      '4': 3,
      '5': 11,
      '6': '.BackupMangaStats',
      '10': 'backupMangaStats'
    },
    {
      '1': 'backupAnkiStats',
      '3': 711,
      '4': 3,
      '5': 11,
      '6': '.BackupAnkiStats',
      '10': 'backupAnkiStats'
    },
  ],
};

/// Descriptor for `BackupMihon`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backupMihonDescriptor = $convert.base64Decode(
    'CgtCYWNrdXBNaWhvbhIuCgtiYWNrdXBNYW5nYRgBIAMoCzIMLkJhY2t1cE1hbmdhUgtiYWNrdX'
    'BNYW5nYRI7ChBiYWNrdXBDYXRlZ29yaWVzGAIgAygLMg8uQmFja3VwQ2F0ZWdvcnlSEGJhY2t1'
    'cENhdGVnb3JpZXMSMwoNYmFja3VwU291cmNlcxhlIAMoCzINLkJhY2t1cFNvdXJjZVINYmFja3'
    'VwU291cmNlcxI/ChFiYWNrdXBQcmVmZXJlbmNlcxhoIAMoCzIRLkJhY2t1cFByZWZlcmVuY2VS'
    'EWJhY2t1cFByZWZlcmVuY2VzElIKF2JhY2t1cFNvdXJjZVByZWZlcmVuY2VzGGkgAygLMhguQm'
    'Fja3VwU291cmNlUHJlZmVyZW5jZXNSF2JhY2t1cFNvdXJjZVByZWZlcmVuY2VzEkcKE2JhY2t1'
    'cEV4dGVuc2lvblJlcG8YaiADKAsyFS5CYWNrdXBFeHRlbnNpb25SZXBvc1ITYmFja3VwRXh0ZW'
    '5zaW9uUmVwbxIvCgtiYWNrdXBBbmltZRj1AyADKAsyDC5CYWNrdXBBbmltZVILYmFja3VwQW5p'
    'bWUSRgoVYmFja3VwQW5pbWVDYXRlZ29yaWVzGPYDIAMoCzIPLkJhY2t1cENhdGVnb3J5UhViYW'
    'NrdXBBbmltZUNhdGVnb3JpZXMSPgoSYmFja3VwQW5pbWVTb3VyY2VzGPcDIAMoCzINLkJhY2t1'
    'cFNvdXJjZVISYmFja3VwQW5pbWVTb3VyY2VzElIKGGJhY2t1cEFuaW1lRXh0ZW5zaW9uUmVwbx'
    'j5AyADKAsyFS5CYWNrdXBFeHRlbnNpb25SZXBvc1IYYmFja3VwQW5pbWVFeHRlbnNpb25SZXBv'
    'EkUKE2JhY2t1cFNhdmVkU2VhcmNoZXMY2AQgAygLMhIuQmFja3VwU2F2ZWRTZWFyY2hSE2JhY2'
    't1cFNhdmVkU2VhcmNoZXMSLgoLYmFja3VwRmVlZHMY4gQgAygLMgsuQmFja3VwRmVlZFILYmFj'
    'a3VwRmVlZHMSMQoMYmFja3VwTm92ZWxzGLwFIAMoCzIMLkJhY2t1cE5vdmVsUgxiYWNrdXBOb3'
    'ZlbHMSSwoVYmFja3VwTm92ZWxDYXRlZ29yaWVzGL0FIAMoCzIULkJhY2t1cE5vdmVsQ2F0ZWdv'
    'cnlSFWJhY2t1cE5vdmVsQ2F0ZWdvcmllcxI+ChBiYWNrdXBNYW5nYVN0YXRzGMYFIAMoCzIRLk'
    'JhY2t1cE1hbmdhU3RhdHNSEGJhY2t1cE1hbmdhU3RhdHMSOwoPYmFja3VwQW5raVN0YXRzGMcF'
    'IAMoCzIQLkJhY2t1cEFua2lTdGF0c1IPYmFja3VwQW5raVN0YXRz');
