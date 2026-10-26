import 'package:flutter/material.dart';

/// 只布局当前页；离开的页用 [AutomaticKeepAlive] 保住 State，大文本不会在后台参与排版。
class KeepAlivePager extends StatefulWidget {
  const KeepAlivePager({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<KeepAlivePager> createState() => _KeepAlivePagerState();
}

class _KeepAlivePagerState extends State<KeepAlivePager> {
  late final PageController _controller = PageController(initialPage: widget.index);

  @override
  void didUpdateWidget(KeepAlivePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && _controller.hasClients) {
      _controller.jumpToPage(widget.index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _controller,
      physics: const NeverScrollableScrollPhysics(),
      children: [for (final child in widget.children) _KeepAlivePage(child: child)],
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
