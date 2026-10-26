import 'dart:io';

import 'package:devkit/src/widgets/tool_scaffold.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

const maxTextBytes = 20 * 1024 * 1024;

class IoPane extends StatelessWidget {
  const IoPane({
    super.key,
    required this.input,
    required this.output,
    required this.inputLabel,
    required this.outputLabel,
    required this.actionLabel,
    required this.onAction,
  });

  final TextEditingController input;
  final TextEditingController output;
  final String inputLabel;
  final String outputLabel;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _Box(label: inputLabel, controller: input, onOpen: () => loadFileInto(context, input))),
              const SizedBox(width: 16),
              Expanded(child: _Box(label: outputLabel, controller: output, onCopy: () => copyText(context, output.text))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.label, required this.controller, this.onOpen, this.onCopy});

  final String label;
  final TextEditingController controller;
  final VoidCallback? onOpen;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
            if (onOpen != null)
              TextButton.icon(onPressed: onOpen, icon: const Icon(Icons.folder_open), label: const Text('打开文件')),
            if (onCopy != null)
              TextButton.icon(onPressed: onCopy, icon: const Icon(Icons.copy), label: const Text('复制')),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
      ],
    );
  }
}

Future<void> loadFileInto(BuildContext context, TextEditingController controller) async {
  final result = await FilePicker.platform.pickFiles();
  final path = result?.files.single.path;
  if (path == null) {
    return;
  }
  final file = File(path);
  if (await file.length() > maxTextBytes) {
    if (context.mounted) showToolError(context, '文件超过 20MB 上限');
    return;
  }
  controller.text = await file.readAsString();
}
