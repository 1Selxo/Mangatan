import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/main_view/auto_sync_timer_controller.dart';
import 'package:mangayomi/modules/more/about/providers/check_for_update.dart';
import 'package:mangayomi/modules/more/about/providers/download_file_screen.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/auto_backup.dart';
import 'package:mangayomi/modules/more/settings/sync/providers/sync_providers.dart';
import 'package:mangayomi/services/discord_rpc.dart';
import 'package:mangayomi/services/fetch_item_sources.dart';
import 'package:mangayomi/services/sync_server.dart';
import 'package:mangayomi/utils/log/logger.dart';
import 'package:mangayomi/utils/platform_utils.dart';

mixin MainScreenLifecycleMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  Timer? _backupTimer;
  // One periodic timer for automatic sync, its ticks serialized so a slow
  // sync never overlaps the next one.
  late final AutoSyncTimerController _autoSync = AutoSyncTimerController(
    onTick: () => autoSyncIfDue(ref),
    onError: (error, stackTrace) => AppLogger.log(
      'Automatic sync failed: $error\n$stackTrace',
      logLevel: LogLevel.error,
    ),
  );

  void initLifecycleServices() {
    _initializeTimers();
    _initializeProviders();
    discordRpc?.connect(ref);
  }

  void disposeLifecycleServices() {
    _backupTimer?.cancel();
    _autoSync.dispose();
    discordRpc?.disconnect();
  }

  void _configureAutoSync() {
    if (!mounted) return;
    if (ref.read(restoreSyncGuardProvider)) {
      _autoSync.configure((syncOn: false, frequencySeconds: 0));
      return;
    }
    final preference = ref.read(synchingProvider(syncId: 1));
    _autoSync.configure((
      syncOn: preference.syncOn,
      frequencySeconds: preference.autoSyncFrequency,
    ));
  }

  void _initializeTimers() {
    _backupTimer = Timer.periodic(
      const Duration(minutes: 5),
      _onBackupTimerTick,
    );

    _configureAutoSync();

    // Pauses the auto-sync timer for the duration of a restore (and its
    // post-restore upload), instead of just rescheduling it — a restore can
    // outlast one sync interval, so a reschedule alone could still let the
    // timer fire mid-restore. syncServerProvider.startSync also checks this
    // guard directly, covering a manual sync trigger too.
    ref.listenManual<bool>(restoreSyncGuardProvider, (_, _) {
      _configureAutoSync();
    });

    // Listen to changes in sync preferences (frequency, syncOn, login/logout)
    // and immediately reschedule the timer and check if due.
    ref.listenManual(synchingProvider(syncId: 1), (prev, next) {
      _configureAutoSync();
      if (mounted) {
        unawaited(autoSyncIfDue(ref));
      }
    });
  }

  void _initializeProviders() {
    // Mihon sources start the embedded OpenJDK runtime. On iOS, leave that
    // heavyweight work to explicit extension and source actions instead of
    // starting Java as a side effect of opening the main screen.
    if (Platform.isIOS) return;

    // The extension-repo fetches (one per item type) and the GitHub update
    // check hit the network; delay them so they don't compete with the first
    // paint and the initial library queries.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        for (var type in ItemType.values) {
          ref.read(
            fetchItemSourcesListProvider(
              id: null,
              reFresh: false,
              itemType: type,
            ),
          );
        }
      }
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || isTv) return;
      ref.listenManual<AsyncValue<UpdateInfo?>>(checkForUpdateProvider, (
        _,
        next,
      ) {
        next.whenData((updateInfo) {
          if (updateInfo != null && mounted) {
            showUpdateDialog(context, updateInfo);
          }
        });
      });
    });
  }

  void _onBackupTimerTick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    ref.read(checkAndBackupProvider);
  }
}
