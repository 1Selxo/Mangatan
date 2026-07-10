import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<String?> showEditTextDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  String? hint,
  int maxLines = 1,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _EditTextDialog(
      title: title,
      initialValue: initialValue,
      hint: hint,
      maxLines: maxLines,
    ),
  );
}

class _EditTextDialog extends StatefulWidget {
  const _EditTextDialog({
    required this.title,
    required this.initialValue,
    required this.hint,
    required this.maxLines,
  });

  final String title;
  final String initialValue;
  final String? hint;
  final int maxLines;

  @override
  State<_EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<_EditTextDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _dismissScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent && !_dismissScheduled) {
      _dismissScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
        Navigator.of(context).pop();
      });
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: widget.maxLines,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
