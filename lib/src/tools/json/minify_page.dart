import 'package:devkit/src/rust/api/json.dart';
import 'package:devkit/src/widgets/io_pane.dart';
import 'package:devkit/src/widgets/tool_scaffold.dart';
import 'package:flutter/material.dart';

class JsonMinifyPage extends StatefulWidget {
  const JsonMinifyPage({super.key});

  @override
  State<JsonMinifyPage> createState() => _JsonMinifyPageState();
}

class _JsonMinifyPageState extends State<JsonMinifyPage> with ToolFeedback {
  final _input = TextEditingController();
  final _output = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    _output.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      _output.text = await jsonMinify(text: _input.text);
    } catch (error) {
      reportError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      child: IoPane(
        input: _input,
        output: _output,
        inputLabel: '输入',
        outputLabel: '压缩结果',
        actionLabel: _busy ? '处理中…' : '压缩',
        onAction: _busy ? null : _run,
      ),
    );
  }
}
