import 'package:flutter/material.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/services/extension_icon_resolver.dart';
import 'package:mangayomi/utils/cached_network.dart';

class SourceExtensionIcon extends StatelessWidget {
  const SourceExtensionIcon({
    super.key,
    required this.source,
    required this.size,
    this.fallbackIcon = Icons.extension_rounded,
    this.fallbackIconSize,
  });

  final Source source;
  final double size;
  final IconData fallbackIcon;
  final double? fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    final candidates = extensionIconCandidates(source);
    return _candidate(candidates, 0);
  }

  Widget _candidate(List<String> candidates, int index) {
    if (index >= candidates.length) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: Icon(fallbackIcon, size: fallbackIconSize)),
      );
    }

    return cachedNetworkImage(
      imageUrl: candidates[index],
      fit: BoxFit.contain,
      width: size,
      height: size,
      errorWidget: _candidate(candidates, index + 1),
      useCustomNetworkImage: false,
    );
  }
}
