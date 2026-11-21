import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/eval/mihon/service.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/repositories/source_repository.dart';
import 'package:mangayomi/services/m_extension_server.dart';

/// The filters a Mihon source gives now, asked of the bridge again.
///
/// The list stored with the source is the one the extension gave when it was
/// installed, which may still lack filters it loads from the site later. A
/// list that differs from the stored one replaces it, so the next screen
/// starts from it. Refresh the provider to ask again.
final mihonFilterListProvider = FutureProvider.family<List<dynamic>?, Source>((
  ref,
  source,
) async {
  if (source.sourceCodeLanguage != SourceCodeLanguage.mihon) return null;
  final proxyServer = await prepareMihonBridge(ref, source);
  final service = MihonExtensionService(source, proxyServer);
  try {
    final fresh = await service.fetchFilterList();
    if (fresh == null) return null;
    final encoded = jsonEncode(fresh.toJson());
    if (encoded != source.filterList) {
      source.filterList = encoded;
      await sourceRepository.save(source);
    }
    return fresh.filters;
  } finally {
    service.dispose();
  }
});
