import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ToolScaffold extends StatelessWidget {
  const ToolScaffold({
    super.key,
    required this.child,
    this.actions = const [],
  });

  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (actions.isNotEmpty) ...[
            Wrap(spacing: 8, runSpacing: 8, children: actions),
            const SizedBox(height: 12),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制')));
  }
}

void showToolError(BuildContext context, Object error) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString()), backgroundColor: Theme.of(context).colorScheme.error),
  );
}

mixin ToolFeedback<T extends StatefulWidget> on State<T> {
  void reportError(Object error) {
    if (!mounted) {
      return;
    }
    showToolError(context, error);
  }

  void reportMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> reportCopied(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    reportMessage('已复制');
  }
}
