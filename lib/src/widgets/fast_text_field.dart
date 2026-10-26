import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 超过该字符数，或单行超过该长度，改用虚拟预览，避免 TextField 首次排版卡死。
const fastTextCharThreshold = 64 * 1024;
const fastTextLongLineThreshold = 8 * 1024;
const fastTextChunkSize = 120;

bool isHeavyText(String text) {
  if (text.length >= fastTextCharThreshold) {
    return true;
  }
  var lineLen = 0;
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x0A) {
      lineLen = 0;
    } else {
      lineLen++;
      if (lineLen >= fastTextLongLineThreshold) {
        return true;
      }
    }
  }
  return false;
}

/// 把大文本拆成可见行下标，长行按 [chunkSize] 切开，避免整份排版。
class FastTextIndex {
  FastTextIndex(this.text, {this.chunkSize = fastTextChunkSize}) {
    _starts.add(0);
    var col = 0;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x0A) {
        _starts.add(i + 1);
        col = 0;
      } else {
        col++;
        if (col == chunkSize) {
          _starts.add(i + 1);
          col = 0;
        }
      }
    }
  }

  final String text;
  final int chunkSize;
  final List<int> _starts = [];

  int get length => _starts.length;

  String lineAt(int index) {
    final start = _starts[index];
    var end = index + 1 < _starts.length ? _starts[index + 1] : text.length;
    if (end > start && text.codeUnitAt(end - 1) == 0x0A) {
      end--;
    }
    return text.substring(start, end);
  }
}

/// 小文本仍用 TextField；大文本只画可见行，格式化 / 复制仍读 [controller]。
class FastTextField extends StatefulWidget {
  const FastTextField({
    super.key,
    required this.controller,
    this.style,
    this.decoration = const InputDecoration(border: OutlineInputBorder()),
    this.expands = true,
  });

  final TextEditingController controller;
  final TextStyle? style;
  final InputDecoration decoration;
  final bool expands;

  @override
  State<FastTextField> createState() => _FastTextFieldState();
}

class _FastTextFieldState extends State<FastTextField> {
  FastTextIndex? _index;
  String? _indexedText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
    _syncIndex();
  }

  @override
  void didUpdateWidget(FastTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
      _indexedText = null;
      _syncIndex();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() {
    _syncIndex();
    if (mounted) {
      setState(() {});
    }
  }

  void _syncIndex() {
    final text = widget.controller.text;
    if (!isHeavyText(text)) {
      _index = null;
      _indexedText = text;
      return;
    }
    if (identical(_indexedText, text) && _index != null) {
      return;
    }
    _index = FastTextIndex(text);
    _indexedText = text;
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null) {
      return;
    }
    widget.controller.text = text;
  }

  @override
  Widget build(BuildContext context) {
    final index = _index;
    if (index == null) {
      return TextField(
        controller: widget.controller,
        maxLines: null,
        expands: widget.expands,
        textAlignVertical: TextAlignVertical.top,
        style: widget.style,
        decoration: widget.decoration,
      );
    }
    final style = widget.style ?? const TextStyle(fontSize: 14, height: 1.4);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _paste,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _paste,
      },
      child: Focus(
        child: InputDecorator(
          decoration: widget.decoration.copyWith(
            hintText: null,
            labelText: null,
            helperText: '快速预览 · 操作仍作用于全文',
            alignLabelWithHint: true,
            contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          ),
          child: ListView.builder(
            itemExtent: 20,
            itemCount: index.length,
            itemBuilder: (context, i) {
              return Text(
                index.lineAt(i),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              );
            },
          ),
        ),
      ),
    );
  }
}
