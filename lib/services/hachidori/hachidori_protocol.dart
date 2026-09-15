const hachidoriProtocolVersion = 1;
const hachidoriDefaultPort = 8771;
const hachidoriDefaultOrigin = 'hoshi://hoshidicts';
const hachidoriLinkPath = '/link';

const _addressHint = 'Enter a Hachidori sharing address, such as 192.168.1.20.';

class HachidoriLinkAddress {
  const HachidoriLinkAddress({required this.uri, required this.display});

  factory HachidoriLinkAddress.parse(String value) {
    final trimmed = value.trim();
    final source = trimmed.isEmpty
        ? 'ws://127.0.0.1:$hachidoriDefaultPort$hachidoriLinkPath'
        : trimmed.contains('://')
        ? trimmed
        : 'ws://$trimmed';
    final parsed = Uri.tryParse(source);
    if (parsed == null ||
        parsed.scheme != 'ws' ||
        parsed.host.isEmpty ||
        !const {'', '/', hachidoriLinkPath}.contains(parsed.path)) {
      throw const FormatException(_addressHint);
    }

    late final int port;
    try {
      port = parsed.hasPort ? parsed.port : hachidoriDefaultPort;
    } on FormatException {
      throw const FormatException(_addressHint);
    }
    final rawHost = parsed.host.toLowerCase();
    final host = const {'127.0.0.1', 'localhost', '::1'}.contains(rawHost)
        ? '127.0.0.1'
        : parsed.host;
    final canonical = Uri(
      scheme: 'ws',
      host: host,
      port: port,
      path: hachidoriLinkPath,
    ).toString();
    final display = host == '127.0.0.1'
        ? 'this computer'
        : port == hachidoriDefaultPort
        ? host
        : '$host:$port';
    return HachidoriLinkAddress(uri: canonical, display: display);
  }

  final String uri;
  final String display;

  Uri get parsedUri => Uri.parse(uri);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HachidoriLinkAddress &&
          runtimeType == other.runtimeType &&
          uri == other.uri &&
          display == other.display;

  @override
  int get hashCode => Object.hash(uri, display);

  @override
  String toString() => uri;
}
