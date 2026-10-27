import 'dart:io';

import 'package:devkit/src/rust/api/har.dart';
import 'package:devkit/src/widgets/tool_scaffold.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class HarPage extends StatefulWidget {
  const HarPage({super.key});

  @override
  State<HarPage> createState() => _HarPageState();
}

class _HarPageState extends State<HarPage> with ToolFeedback {
  final url = TextEditingController();
  final method = TextEditingController();
  final status = TextEditingController();
  final maxTime = TextEditingController();
  List<HarEntrySummary> items = const [];
  HarEntryDetail? detail;
  bool busy = false;

  @override
  void dispose() {
    url.dispose();
    method.dispose();
    status.dispose();
    maxTime.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(allowedExtensions: const ['har', 'json'], type: FileType.custom);
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => busy = true);
    try {
      items = await harImportText(text: await File(path).readAsString());
      detail = null;
    } catch (error) {
      reportError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _filter() async {
    setState(() => busy = true);
    try {
      items = await harFilter(filter: HarFilter(urlContains: url.text, method: method.text, status: status.text, maxTimeMs: double.tryParse(maxTime.text)));
    } catch (error) {
      reportError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _export(HarExportFormat format) async {
    try {
      final text = await harExport(ids: items.map((e) => e.id).toList(), format: format);
      final path = await FilePicker.platform.saveFile(fileName: format == HarExportFormat.har ? 'filtered.har' : 'filtered.json');
      if (path == null) return;
      await File(path).writeAsString(text);
      reportMessage('已导出');
    } catch (error) {
      reportError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      actions: [
        TextButton.icon(onPressed: busy ? null : _import, icon: const Icon(Icons.folder_open), label: const Text('导入 HAR')),
        TextButton(onPressed: items.isEmpty ? null : () => _export(HarExportFormat.har), child: const Text('导出 HAR')),
        TextButton(onPressed: items.isEmpty ? null : () => _export(HarExportFormat.json), child: const Text('导出 JSON')),
      ],
      child: Column(
        children: [
          Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 220, child: TextField(controller: url, decoration: const InputDecoration(labelText: 'URL 包含', border: OutlineInputBorder()))),
            SizedBox(width: 120, child: TextField(controller: method, decoration: const InputDecoration(labelText: '方法', border: OutlineInputBorder()))),
            SizedBox(width: 120, child: TextField(controller: status, decoration: const InputDecoration(labelText: '状态/2xx', border: OutlineInputBorder()))),
            SizedBox(width: 140, child: TextField(controller: maxTime, decoration: const InputDecoration(labelText: '最大耗时 ms', border: OutlineInputBorder()))),
            FilledButton(onPressed: busy ? null : _filter, child: const Text('筛选')),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        selected: detail?.id == item.id,
                        dense: true,
                        title: Text('${item.method}  ${item.status}'),
                        subtitle: Text('${item.url}\n${item.timeMs.toStringAsFixed(1)} ms · ${item.size} B'),
                        isThreeLine: true,
                        onTap: () async {
                          try {
                            detail = await harEntry(id: item.id);
                            setState(() {});
                          } catch (error) {
                            reportError(error);
                          }
                        },
                      );
                    },
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 4,
                  child: detail == null
                      ? const Center(child: Text('选择一条请求查看详情'))
                      : ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            Text('${detail!.method} ${detail!.status}  ${detail!.url}', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton.tonal(
                                onPressed: () async {
                                  try {
                                    final code = await harToPython(id: detail!.id);
                                    await reportCopied(code);
                                  } catch (error) {
                                    reportError(error);
                                  }
                                },
                                child: const Text('复制为 Python'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('请求头', style: Theme.of(context).textTheme.titleSmall),
                            ...detail!.requestHeaders.map((h) => Text('${h.name}: ${h.value}')),
                            const SizedBox(height: 12),
                            Text('请求体', style: Theme.of(context).textTheme.titleSmall),
                            SelectableText(detail!.requestBody.isEmpty ? '（空）' : detail!.requestBody),
                            const SizedBox(height: 12),
                            Text('响应头', style: Theme.of(context).textTheme.titleSmall),
                            ...detail!.responseHeaders.map((h) => Text('${h.name}: ${h.value}')),
                            const SizedBox(height: 12),
                            Text('响应体 · ${detail!.mimeType}', style: Theme.of(context).textTheme.titleSmall),
                            SelectableText(detail!.responseBody.isEmpty ? '（空）' : detail!.responseBody),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
