import 'package:devkit/src/rust/api/har.dart';
import 'package:devkit/src/tools/har/har_pretty.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HarDetailPane extends StatelessWidget {
  const HarDetailPane({super.key, required this.detail, required this.onCopyPython});

  final HarEntryDetail detail;
  final VoidCallback onCopyPython;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${detail.method} ${detail.status}  ${detail.url}',
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton.tonal(onPressed: onCopyPython, child: const Text('复制为 Python')),
              ],
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: '请求'),
              Tab(text: '响应'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SectionTabs(
                  tabs: const ['总览', '原始', '请求头', '请求体', 'Cookies'],
                  children: [
                    _CopyableText(formatOverview(detail)),
                    _CopyableText(detail.requestRaw),
                    _CopyableText(formatHeaders(detail.requestHeaders)),
                    _CopyableText(prettyBody(detail.requestBody, detail.requestMime)),
                    _CopyableText(formatPairs(detail.cookies)),
                  ],
                ),
                _SectionTabs(
                  tabs: const ['原始', '响应头', '响应体'],
                  children: [
                    _CopyableText(detail.responseRaw),
                    _CopyableText(formatHeaders(detail.responseHeaders)),
                    _CopyableText(prettyBody(detail.responseBody, detail.responseMime)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.tabs, required this.children});

  final List<String> tabs;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: [for (final tab in tabs) Tab(text: tab)],
          ),
          Expanded(child: TabBarView(children: children)),
        ],
      ),
    );
  }
}

class _CopyableText extends StatelessWidget {
  const _CopyableText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: text)),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('复制'),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SelectableText(text, style: const TextStyle(fontFamily: 'Consolas', fontSize: 13, height: 1.4)),
          ),
        ),
      ],
    );
  }
}
