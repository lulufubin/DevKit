import 'dart:convert';
import 'dart:io';

import 'package:devkit/src/rust/api/json.dart';
import 'package:devkit/src/tools/json/json_text.dart';
import 'package:devkit/src/widgets/io_pane.dart';
import 'package:devkit/src/widgets/tool_scaffold.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JsonPage extends StatefulWidget {
  const JsonPage({super.key});

  @override
  State<JsonPage> createState() => _JsonPageState();
}

class _JsonPageState extends State<JsonPage> with ToolFeedback {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onText);
  }

  @override
  void dispose() {
    _text
      ..removeListener(_onText)
      ..dispose();
    super.dispose();
  }

  void _onText() => setState(() {});

  Future<void> _applyAsync(Future<String> Function(String text) run) async {
    setState(() => _busy = true);
    try {
      _text.text = await run(_text.text);
    } catch (error) {
      reportError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _apply(String Function(String text) run) {
    try {
      _text.text = run(_text.text);
    } catch (error) {
      reportError(error);
    }
  }

  Future<void> _save() async {
    try {
      final path = await FilePicker.platform.saveFile(fileName: 'data.json');
      if (path == null) {
        return;
      }
      await File(path).writeAsString(_text.text);
      reportMessage('已保存');
    } catch (error) {
      reportError(error);
    }
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _text.text));
    reportMessage('已复制');
  }

  @override
  Widget build(BuildContext context) {
    final text = _text.text;
    final cursor = cursorLineColumn(text, _text.selection.extentOffset);
    final bytes = utf8.encode(text).length;
    return ToolScaffold(
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _Action(label: '打开', onPressed: _busy ? null : () => loadFileInto(context, _text)),
                  _Action(label: '保存', onPressed: _busy ? null : _save),
                  _Action(label: '清空', onPressed: _busy ? null : () => _text.clear()),
                  _Action(label: '复制', onPressed: _busy ? null : _copy),
                  _Action(
                    label: '格式化',
                    onPressed: _busy ? null : () => _applyAsync((text) => jsonFormat(text: text)),
                  ),
                  _Action(
                    label: '压缩',
                    onPressed: _busy ? null : () => _applyAsync((text) => jsonMinify(text: text)),
                  ),
                  _Action(label: '转义', onPressed: _busy ? null : () => _apply(escapeJsonText)),
                  _Action(label: '去除转义', onPressed: _busy ? null : () => _apply(unescapeJsonText)),
                  _Action(label: 'Unicode转中文', onPressed: _busy ? null : () => _apply(unicodeToChinese)),
                  _Action(label: '中文转Unicode', onPressed: _busy ? null : () => _apply(chineseToUnicode)),
                  _Action(label: '中文符号转英文', onPressed: _busy ? null : () => _apply(chinesePunctToEnglish)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _text,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 14, height: 1.4),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '行数 ${_lineCount(text)}    大小 ${_sizeLabel(bytes)}    '
              '行 ${text.isEmpty ? 0 : cursor.line}    列 ${text.isEmpty ? 0 : cursor.column}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onPressed, child: Text(label));
  }
}

String _sizeLabel(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}

int _lineCount(String text) => text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;
