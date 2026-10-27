import 'dart:convert';

import 'package:devkit/src/rust/api/har.dart';

bool looksLikeJson(String text, [String mime = '']) {
  if (mime.toLowerCase().contains('json')) {
    return true;
  }
  final trimmed = text.trimLeft();
  return trimmed.startsWith('{') || trimmed.startsWith('[');
}

String prettyJsonOrRaw(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return text;
  }
  try {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(jsonDecode(trimmed));
  } catch (_) {
    return text;
  }
}

String emptyLabel(String text) => text.trim().isEmpty ? '（空）' : text;

String formatHeaders(List<HarHeader> headers) {
  if (headers.isEmpty) {
    return '（空）';
  }
  return headers.map((h) => '${h.name}: ${h.value}').join('\n');
}

String formatPairs(List<HarHeader> pairs) {
  if (pairs.isEmpty) {
    return '（空）';
  }
  return pairs.map((h) => '${h.name} = ${h.value}').join('\n');
}

String formatOverview(HarEntryDetail detail) {
  final lines = <String>[
    '${detail.method} ${detail.url}',
    '${detail.httpVersion.isEmpty ? 'HTTP/1.1' : detail.httpVersion} ${detail.status} ${detail.statusText}'.trim(),
    '耗时 ${detail.timeMs.toStringAsFixed(1)} ms',
    '大小 ${detail.size} B',
  ];
  if (detail.query.isNotEmpty) {
    lines.add('查询');
    lines.add(formatPairs(detail.query));
  }
  if (detail.requestMime.isNotEmpty) {
    lines.add('请求类型 ${detail.requestMime}');
  }
  if (detail.responseMime.isNotEmpty) {
    lines.add('响应类型 ${detail.responseMime}');
  }
  if (detail.cookies.isNotEmpty) {
    lines.add('Cookies ${detail.cookies.length}');
  }
  return lines.join('\n');
}

String prettyBody(String text, String mime) {
  if (text.trim().isEmpty) {
    return '（空）';
  }
  if (looksLikeJson(text, mime)) {
    return prettyJsonOrRaw(text);
  }
  return text;
}
