import 'package:devkit/src/rust/api/har.dart';
import 'package:devkit/src/tools/har/har_detail_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HAR 详情分请求和响应，并展示格式化 JSON', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HarDetailPane(
            detail: HarEntryDetail(
              id: '0',
              method: 'POST',
              url: 'https://example.com/api/users',
              status: 201,
              timeMs: 120,
              size: 11,
              httpVersion: 'HTTP/1.1',
              statusText: 'Created',
              requestHeaders: const [HarHeader(name: 'Content-Type', value: 'application/json')],
              responseHeaders: const [HarHeader(name: 'Content-Type', value: 'application/json')],
              cookies: const [HarHeader(name: 'session', value: 'abc')],
              query: const [],
              requestBody: '{"name":"ada"}',
              responseBody: '{"ok":true}',
              requestMime: 'application/json',
              responseMime: 'application/json',
              requestRaw: 'POST /api/users HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{"name":"ada"}',
              responseRaw: 'HTTP/1.1 201 Created\r\nContent-Type: application/json\r\n\r\n{"ok":true}',
            ),
            onCopyPython: () {},
          ),
        ),
      ),
    );

    expect(find.text('请求'), findsOneWidget);
    expect(find.text('响应'), findsOneWidget);
    expect(find.text('总览'), findsOneWidget);
    expect(find.text('原始'), findsWidgets);
    expect(find.text('请求头'), findsOneWidget);
    expect(find.text('请求体'), findsOneWidget);
    expect(find.text('Cookies'), findsOneWidget);

    await tester.tap(find.text('请求体'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"name": "ada"'), findsOneWidget);

    await tester.tap(find.text('响应'));
    await tester.pumpAndSettle();
    expect(find.text('响应头'), findsOneWidget);
    expect(find.text('响应体'), findsOneWidget);
    await tester.tap(find.text('响应体'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"ok": true'), findsOneWidget);
  });
}
