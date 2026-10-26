import 'dart:io';

import 'package:devkit/src/widgets/fast_text_field.dart';
import 'package:devkit/src/widgets/tool_scaffold.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

const maxTextBytes = 20 * 1024 * 1024;

/// 左右并排的输入 / 输出框，占满父级剩余高度。
class IoSplit extends StatelessWidget {
  const IoSplit({
    super.key,
    required this.input,
    required this.output,
    this.inputLabel = '输入',
    this.outputLabel = '输出',
    this.showOpen = true,
    this.showCopy = true,
  });

  final TextEditingController input;
  final TextEditingController output;
  final String inputLabel;
  final String outputLabel;
  final bool showOpen;
  final bool showCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: IoBox(
            label: inputLabel,
            controller: input,
            onOpen: showOpen ? () => loadFileInto(context, input) : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: IoBox(
            label: outputLabel,
            controller: output,
            onCopy: showCopy ? () => copyText(context, output.text) : null,
          ),
        ),
      ],
    );
  }
}

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
          child: IoSplit(
            input: input,
            output: output,
            inputLabel: inputLabel,
            outputLabel: outputLabel,
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

class IoBox extends StatelessWidget {
  const IoBox({
    super.key,
    required this.label,
    required this.controller,
    this.onOpen,
    this.onCopy,
    this.dense = false,
    this.status,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback? onOpen;
  final VoidCallback? onCopy;
  final bool dense;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                status == null || status!.isEmpty ? label : '$label · $status',
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onOpen != null)
              TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('打开'),
              ),
            if (onCopy != null)
              TextButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('复制'),
              ),
          ],
        ),
        SizedBox(height: dense ? 4 : 8),
        Expanded(
          child: FastTextField(controller: controller),
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
