import 'package:mangayomi/eval/model/m_pages.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/services/local_source_browser.dart';
import 'package:mangayomi/services/m_extension_server.dart';
import 'package:mangayomi/services/isolate_service.dart';
import 'package:mangayomi/services/perf/perf_metrics.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search.g.dart';

@riverpod
Future<MPages?> search(
  Ref ref, {
  required Source source,
  required String query,
  required int page,
  required List<dynamic> filterList,
}) => PerfMetrics.trace(PerfFlow.browseSource, label: 'search', () async {
  if (source.name == "local" && source.lang == "") {
    return buildLocalSourcePage(
      await loadLocalSourceNames(isar, itemType: source.itemType),
      page: page,
      query: query,
    );
  }
  final proxyServer = await prepareMihonBridge(ref, source);
  return getIsolateService.get<MPages?>(
    query: query,
    filterList: filterList,
    source: source,
    page: page,
    serviceType: 'search',
    proxyServer: proxyServer,
  );
});
