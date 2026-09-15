import 'package:flutter/foundation.dart';
import 'package:mangayomi/services/hachidori/hachidori_models.dart';
import 'package:mangayomi/services/hachidori/hachidori_preferences.dart';

abstract interface class HachidoriLinkController implements Listenable {
  HachidoriLinkConfiguration get configuration;

  HachidoriClientState get clientState;

  bool get remoteEnabled;

  Future<void> initialize();

  Future<HachidoriProbeResult> probe(String address);

  Future<void> link(String address);

  Future<void> unlink();
}
