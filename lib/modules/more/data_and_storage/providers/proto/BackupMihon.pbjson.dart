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
      '1': 'backupExtensionStores',
      '3': 106,
      '4': 3,
      '5': 11,
      '6': '.BackupExtensionStore',
      '10': 'backupExtensionStores'
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
      '1': 'backupSearchHistory',
      '3': 650,
      '4': 3,
      '5': 11,
      '6': '.BackupSearchHistory',
      '10': 'backupSearchHistory'
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
    'Fja3VwU291cmNlUHJlZmVyZW5jZXNSF2JhY2t1cFNvdXJjZVByZWZlcmVuY2VzEksKFWJhY2t1'
    'cEV4dGVuc2lvblN0b3JlcxhqIAMoCzIVLkJhY2t1cEV4dGVuc2lvblN0b3JlUhViYWNrdXBFeH'
    'RlbnNpb25TdG9yZXMSLwoLYmFja3VwQW5pbWUY9QMgAygLMgwuQmFja3VwQW5pbWVSC2JhY2t1'
    'cEFuaW1lEkYKFWJhY2t1cEFuaW1lQ2F0ZWdvcmllcxj2AyADKAsyDy5CYWNrdXBDYXRlZ29yeV'
    'IVYmFja3VwQW5pbWVDYXRlZ29yaWVzEj4KEmJhY2t1cEFuaW1lU291cmNlcxj3AyADKAsyDS5C'
    'YWNrdXBTb3VyY2VSEmJhY2t1cEFuaW1lU291cmNlcxJSChhiYWNrdXBBbmltZUV4dGVuc2lvbl'
    'JlcG8Y+QMgAygLMhUuQmFja3VwRXh0ZW5zaW9uUmVwb3NSGGJhY2t1cEFuaW1lRXh0ZW5zaW9u'
    'UmVwbxJFChNiYWNrdXBTYXZlZFNlYXJjaGVzGNgEIAMoCzISLkJhY2t1cFNhdmVkU2VhcmNoUh'
    'NiYWNrdXBTYXZlZFNlYXJjaGVzEi4KC2JhY2t1cEZlZWRzGOIEIAMoCzILLkJhY2t1cEZlZWRS'
    'C2JhY2t1cEZlZWRzEkcKE2JhY2t1cFNlYXJjaEhpc3RvcnkYigUgAygLMhQuQmFja3VwU2Vhcm'
    'NoSGlzdG9yeVITYmFja3VwU2VhcmNoSGlzdG9yeRIxCgxiYWNrdXBOb3ZlbHMYvAUgAygLMgwu'
    'QmFja3VwTm92ZWxSDGJhY2t1cE5vdmVscxJLChViYWNrdXBOb3ZlbENhdGVnb3JpZXMYvQUgAy'
    'gLMhQuQmFja3VwTm92ZWxDYXRlZ29yeVIVYmFja3VwTm92ZWxDYXRlZ29yaWVzEj4KEGJhY2t1'
    'cE1hbmdhU3RhdHMYxgUgAygLMhEuQmFja3VwTWFuZ2FTdGF0c1IQYmFja3VwTWFuZ2FTdGF0cx'
    'I7Cg9iYWNrdXBBbmtpU3RhdHMYxwUgAygLMhAuQmFja3VwQW5raVN0YXRzUg9iYWNrdXBBbmtp'
    'U3RhdHM=');
