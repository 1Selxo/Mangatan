import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mangayomi/services/mpv_config_file.dart';

Future<void> showMpvConfigEditor({
  required BuildContext context,
  required Directory directory,
  required String fileName,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => Dialog.fullscreen(
    child: MpvConfigEditor(directory: directory, fileName: fileName),
  ),
);

class MpvConfigEditor extends StatefulWidget {
  const MpvConfigEditor({
    required this.directory,
    required this.fileName,
    super.key,
  });

  final Directory directory;
  final String fileName;

  @override
  State<MpvConfigEditor> createState() => _MpvConfigEditorState();
}

class _MpvConfigEditorState extends State<MpvConfigEditor> {
  final _textController = TextEditingController();
  late final MpvConfigFile _config;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _config = MpvConfigFile(
      directory: widget.directory,
      fileName: widget.fileName,
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _textController.text = await _config.read();
    } catch (error) {
      _error = 'Could not read ${widget.fileName}: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _config.write(_textController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${widget.fileName} saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save ${widget.fileName}: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: Text('Edit ${widget.fileName}'),
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: _loading || _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Shortcuts(
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.keyS, control: true):
                    _SaveMpvConfigIntent(),
                SingleActivator(LogicalKeyboardKey.keyS, meta: true):
                    _SaveMpvConfigIntent(),
              },
              child: Actions(
                actions: {
                  _SaveMpvConfigIntent: CallbackAction<_SaveMpvConfigIntent>(
                    onInvoke: (_) {
                      _save();
                      return null;
                    },
                  ),
                },
                child: TextField(
                  controller: _textController,
                  autofocus: true,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 1.35,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
    );
  }
}

class _SaveMpvConfigIntent extends Intent {
  const _SaveMpvConfigIntent();
}
