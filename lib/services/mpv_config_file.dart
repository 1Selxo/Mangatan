import 'dart:io';

class MpvConfigFile {
  MpvConfigFile({required this.directory, required String fileName})
    : fileName = _validateFileName(fileName);

  static const allowedFileNames = {'mpv.conf', 'input.conf'};

  final Directory directory;
  final String fileName;

  File get file => File('${directory.path}${Platform.pathSeparator}$fileName');

  Future<String> read() async {
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  Future<void> write(String content) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    await file.writeAsString(content, flush: true);
  }

  static String _validateFileName(String fileName) {
    if (!allowedFileNames.contains(fileName)) {
      throw ArgumentError.value(fileName, 'fileName', 'Unsupported MPV file');
    }
    return fileName;
  }
}
