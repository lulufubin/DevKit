import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ToolScaffold extends StatelessWidget {
  const ToolScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
                ),
                ...actions,
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: Padding(padding: const EdgeInsets.all(20), child: child)),
      ],
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
