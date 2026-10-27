import 'package:devkit/src/rust/api/har.dart';
import 'package:devkit/src/tools/har/har_pretty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prettyJsonOrRaw formats compact json and keeps invalid text', () {
    expect(prettyJsonOrRaw('{"ok":true}'), '{\n  "ok": true\n}');
    expect(prettyJsonOrRaw('not-json'), 'not-json');
  });

  test('formatOverview lists method, status and cookies count', () {
    final text = formatOverview(
      HarEntryDetail(
        id: '0',
        method: 'POST',
        url: 'https://example.com/api/users',
        status: 201,
        timeMs: 120,
        size: 11,
        httpVersion: 'HTTP/1.1',
        statusText: 'Created',
        requestHeaders: const [],
        responseHeaders: const [],
        cookies: const [HarHeader(name: 'session', value: 'abc')],
        query: const [HarHeader(name: 'q', value: '1')],
        requestBody: '{"name":"ada"}',
        responseBody: '{"ok":true}',
        requestMime: 'application/json',
        responseMime: 'application/json',
        requestRaw: 'POST /api/users HTTP/1.1',
        responseRaw: 'HTTP/1.1 201 Created',
      ),
    );
    expect(text, contains('POST https://example.com/api/users'));
    expect(text, contains('HTTP/1.1 201 Created'));
    expect(text, contains('Cookies 1'));
    expect(text, contains('q = 1'));
  });

  test('prettyBody formats json bodies', () {
    expect(prettyBody('{"ok":true}', 'application/json'), contains('\n  "ok": true'));
    expect(prettyBody('', ''), '（空）');
  });
}
