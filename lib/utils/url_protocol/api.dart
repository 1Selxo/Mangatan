import 'native_protocol.dart'
    if (dart.library.js_interop) 'web_url_protocol.dart';

/// Temporarily leases a previously unclaimed protocol [scheme].
///
/// An existing handler is accepted when its command already matches this
/// process. Mangatan may also repair an abandoned temporary lease bearing its
/// explicit ownership marker; unrelated handlers are never overwritten or
/// removed. This makes the function suitable for short-lived OAuth callbacks
/// using a globally shared custom URI scheme.
///
/// You may pass an [executable] to override the path to the executable to run
/// when accessing the URL.
///
/// [arguments] is a list of arguments to be used when running the executable.
/// If passed, the list must contain at least one element, and at least one of
/// those elements must contain the literal value `%s` to denote the URL to open.
/// Quoting arguments is not necessary, as this will be handled for you.
/// Escaping the `%s` as an unprocessed literal is currently unsupported.
void registerProtocolHandler(
  String scheme, {
  String? executable,
  List<String>? arguments,
}) {
  NativeProtocolHandler().register(
    scheme,
    executable: executable,
    arguments: arguments,
  );
}

/// Registers an application-owned protocol [scheme] persistently.
///
/// Unlike [registerProtocolHandler], this may update a stale registration that
/// can be identified as belonging to Mangatan. It still refuses to overwrite a
/// handler owned by another application.
void registerPersistentProtocolHandler(
  String scheme, {
  String? executable,
  List<String>? arguments,
}) {
  NativeProtocolHandler().registerPersistent(
    scheme,
    executable: executable,
    arguments: arguments,
  );
}

/// Releases this process's temporary protocol lease.
///
/// Only a temporary registration created by this process is removed. Persistent
/// registrations and pre-existing matching handlers are retained. Linux also
/// retains Mangatan's owned per-user entry because freedesktop provides no
/// atomic ownership-safe way to unset a default, and the entry is required for
/// cold-started callbacks.
void unregisterProtocolHandler(String scheme) {
  NativeProtocolHandler().unregister(scheme);
}
