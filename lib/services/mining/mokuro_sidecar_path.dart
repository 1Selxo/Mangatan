import 'dart:io';

import 'package:path/path.dart' as p;

File mokuroSidecarFor(FileSystemEntity artifact) {
  if (artifact is Directory) {
    return File(p.join(artifact.path, '${p.basename(artifact.path)}.mokuro'));
  }
  return File(p.setExtension(artifact.path, '.mokuro'));
}
