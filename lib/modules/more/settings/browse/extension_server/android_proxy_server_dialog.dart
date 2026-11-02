import 'package:flutter/material.dart';
import 'package:shiori/shiori.dart';
import 'package:mangayomi/eval/mihon/bridge_http_client.dart';
import 'package:mangayomi/providers/l10n_providers.dart';

/// Asks for the Android proxy's address, normalized to the bridge's base URL
/// ([normalizeMihonBridgeBaseUrl]); an address it rejects is not accepted.
Future<void> showAndroidProxyServerDialog(
  BuildContext context, {
  required String proxyServer,
  required ValueChanged<String> onConfirm,
}) async {
  final l10n = context.l10n;
  String? validationError(String value) {
    try {
      normalizeMihonBridgeBaseUrl(value);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  final server = await showShioriPrompt(
    context,
    title: l10n.android_proxy_server,
    confirmLabel: l10n.dialog_confirm,
    initialValue: proxyServer,
    hint: l10n.proxy_server_ip_hint,
    keyboardType: TextInputType.url,
    allowEmpty: true,
    validator: validationError,
  );
  if (server == null) return;
  onConfirm(normalizeMihonBridgeBaseUrl(server));
}
