import './protocol.dart';

class NativeProtocolHandler extends ProtocolHandler {
  @override
  void register(String scheme, {String? executable, List<String>? arguments}) {}

  @override
  void registerPersistent(
    String scheme, {
    String? executable,
    List<String>? arguments,
  }) {}

  @override
  void unregister(String scheme) {}
}
