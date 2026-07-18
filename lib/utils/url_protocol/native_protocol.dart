import 'dart:io';

import './linux_protocol.dart';
import './protocol.dart';
import './windows_protocol.dart';

/// Dispatches URL-protocol registration to the supported native desktop.
///
/// Keeping this adapter platform-neutral lets OAuth share one browser/callback
/// flow while the operating-system-specific registration details remain small
/// and independently testable.
class NativeProtocolHandler extends ProtocolHandler {
  @override
  void register(String scheme, {String? executable, List<String>? arguments}) {
    if (Platform.isWindows) {
      WindowsProtocolHandler().register(
        scheme,
        executable: executable,
        arguments: arguments,
      );
    } else if (Platform.isLinux) {
      LinuxProtocolHandler().register(
        scheme,
        executable: executable,
        arguments: arguments,
      );
    }
  }

  @override
  void registerPersistent(
    String scheme, {
    String? executable,
    List<String>? arguments,
  }) {
    if (Platform.isWindows) {
      WindowsProtocolHandler().registerPersistent(
        scheme,
        executable: executable,
        arguments: arguments,
      );
    } else if (Platform.isLinux) {
      LinuxProtocolHandler().registerPersistent(
        scheme,
        executable: executable,
        arguments: arguments,
      );
    }
  }

  @override
  void unregister(String scheme) {
    if (Platform.isWindows) {
      WindowsProtocolHandler().unregister(scheme);
    } else if (Platform.isLinux) {
      LinuxProtocolHandler().unregister(scheme);
    }
  }
}
