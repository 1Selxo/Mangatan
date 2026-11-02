import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shiori/shiori.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/models/sync_preference.dart';
import 'package:mangayomi/modules/more/settings/sync/providers/sync_providers.dart';
import 'package:mangayomi/modules/more/widgets/dialog_actions.dart';
import 'package:mangayomi/providers/l10n_providers.dart';

class SyncListile extends ConsumerWidget {
  final VoidCallback onTap;
  final int id;
  final SyncPreference preference;
  final String? text;
  final bool enabled;

  /// Overrides the signed-in state read from [preference]'s token, for a
  /// service that keeps its own credentials.
  final bool? loggedIn;

  /// Signs out instead of the sync server's own logout.
  final FutureOr<void> Function()? onLogout;
  final IconData icon;
  const SyncListile({
    super.key,
    required this.onTap,
    required this.id,
    required this.preference,
    this.text,
    this.enabled = true,
    this.loggedIn,
    this.onLogout,
    this.icon = Symbols.dns_rounded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isLogged =
        loggedIn ?? (preference.authToken?.isNotEmpty ?? false);
    final l10n = l10nLocalizations(context)!;
    final c = context.shiori.color;
    // The same row as a tracking service: a tile for the service, its name,
    // the server signed in to or Login under it, a check once connected.
    return ShioriListRow(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(ShioriShape.cover),
        child: Container(
          width: context.shiori.scaled(44),
          height: context.shiori.scaled(44),
          color: c.ink3,
          child: Icon(icon, color: c.fgMuted),
        ),
      ),
      title: text ?? l10n.sync_server,
      subtitle: text != null
          ? null
          : (isLogged
                ? ((preference.server ?? '').isEmpty
                      ? l10n.log_out
                      : preference.server)
                : l10n.login),
      dimmed: !enabled,
      trailing: isLogged
          ? Icon(
              Symbols.check_circle_rounded,
              fill: 1,
              color: c.completed.foreground,
            )
          : const Icon(Symbols.chevron_forward_rounded),
      onTap: !enabled
          ? null
          : isLogged
          ? () => showLogOutDialog(
              context,
              serviceName: l10n.sync_server,
              onLogOut: () async {
                final logout = onLogout;
                if (logout != null) {
                  await logout();
                } else {
                  ref.read(synchingProvider(syncId: id).notifier).logout();
                }
              },
            )
          : onTap,
    );
  }
}
