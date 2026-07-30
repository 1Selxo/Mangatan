import 'dart:io';

import 'package:path/path.dart' as path;

class DesktopFfmpegTools {
  const DesktopFfmpegTools({required this.ffmpeg, required this.ffprobe});

  final String ffmpeg;
  final String ffprobe;

  static Future<DesktopFfmpegTools?> discover() async {
    if (!isDesktopPlatform) return null;
    final ffmpeg = await _findExecutable(
      environmentName: 'FFMPEG_PATH',
      executableName: Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg',
      macAppExecutable: '/Applications/IINA.app/Contents/MacOS/ffmpeg',
    );
    if (ffmpeg == null) return null;
    final ffprobe = await _findExecutable(
      environmentName: 'FFPROBE_PATH',
      executableName: Platform.isWindows ? 'ffprobe.exe' : 'ffprobe',
      siblingDirectory: path.dirname(ffmpeg),
    );
    if (ffprobe == null) return null;
    return DesktopFfmpegTools(ffmpeg: ffmpeg, ffprobe: ffprobe);
  }

  Future<bool> supportsAnimatedAvif() async {
    try {
      final results = await Future.wait([
        Process.run(ffmpeg, const ['-hide_banner', '-encoders']),
        Process.run(ffmpeg, const ['-hide_banner', '-muxers']),
      ]);
      return results[0].exitCode == 0 &&
          '${results[0].stdout}\n${results[0].stderr}'.contains('libaom-av1') &&
          results[1].exitCode == 0 &&
          RegExp(
            r'^\s*E\s+avif\s',
            multiLine: true,
          ).hasMatch('${results[1].stdout}\n${results[1].stderr}');
    } catch (_) {
      return false;
    }
  }
}

bool get isDesktopPlatform =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;

Future<String?> _findExecutable({
  required String environmentName,
  required String executableName,
  String? siblingDirectory,
  String? macAppExecutable,
}) async {
  final environmentPath = Platform.environment[environmentName];
  final candidates = <String>[
    if (environmentPath?.trim().isNotEmpty ?? false) environmentPath!,
    if (siblingDirectory != null) path.join(siblingDirectory, executableName),
    path.join(path.dirname(Platform.resolvedExecutable), executableName),
    if (Platform.isMacOS) '/opt/homebrew/bin/$executableName',
    if (Platform.isMacOS) '/usr/local/bin/$executableName',
    if (macAppExecutable != null && Platform.isMacOS) macAppExecutable,
    if (!Platform.isWindows) '/usr/bin/$executableName',
    if (!Platform.isWindows) '/usr/local/bin/$executableName',
  ];
  for (final candidate in candidates) {
    if (await File(candidate).exists()) return candidate;
  }
  try {
    final lookup = await Process.run(
      Platform.isWindows ? 'where' : '/usr/bin/which',
      [executableName],
    );
    if (lookup.exitCode == 0) {
      final paths = lookup.stdout.toString().trim().split(RegExp(r'\r?\n'));
      if (paths.isNotEmpty && paths.first.isNotEmpty) return paths.first;
    }
  } catch (_) {}
  return null;
}
