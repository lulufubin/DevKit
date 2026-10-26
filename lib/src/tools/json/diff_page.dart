import 'package:devkit/src/rust/api/json.dart';
import 'package:devkit/src/widgets/fast_text_field.dart';
import 'package:devkit/src/widgets/io_pane.dart';
import 'package:devkit/src/widgets/tool_scaffold.dart';
import 'package:flutter/material.dart';

class JsonDiffPage extends StatefulWidget {
  const JsonDiffPage({super.key});

  @override
  State<JsonDiffPage> createState() => _JsonDiffPageState();
}

class _JsonDiffPageState extends State<JsonDiffPage> with ToolFeedback {
  final _left = TextEditingController();
  final _right = TextEditingController();
  List<JsonDiffOp> _ops = const [];
  JsonMode _mode = JsonMode.lenient;
  bool _busy = false;

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      final ops = await jsonDiff(left: _left.text, right: _right.text, mode: _mode);
      setState(() => _ops = ops);
    } catch (error) {
      reportError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(child: _Editor(label: '左侧', controller: _left)),
                const SizedBox(width: 16),
                Expanded(child: _Editor(label: '右侧', controller: _right)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<JsonMode>(
                  segments: const [
                    ButtonSegment(value: JsonMode.lenient, label: Text('宽容')),
                    ButtonSegment(value: JsonMode.strict, label: Text('严格')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: _busy ? null : (next) => setState(() => _mode = next.single),
                ),
                FilledButton(onPressed: _busy ? null : _run, child: Text(_busy ? '对比中…' : '对比')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 2,
            child: _ops.isEmpty
                ? const Center(child: Text('没有差异，或尚未对比'))
                : ListView.separated(
                    itemCount: _ops.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final op = _ops[index];
                      return ListTile(
                        dense: true,
                        title: Text('${_kindLabel(op.kind)}  ${op.path}'),
                        subtitle: Text([
                          if (op.left != null) '左: ${op.left}',
                          if (op.right != null) '右: ${op.right}',
                        ].join('\n')),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _kindLabel(JsonDiffKind kind) {
    return switch (kind) {
      JsonDiffKind.added => '新增',
      JsonDiffKind.removed => '删除',
      JsonDiffKind.changed => '变更',
    };
  }
}

class _Editor extends StatelessWidget {
  const _Editor({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
            TextButton.icon(
              onPressed: () => loadFileInto(context, controller),
              icon: const Icon(Icons.folder_open),
              label: const Text('打开文件'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FastTextField(controller: controller),
        ),
      ],
    );
  }
}
