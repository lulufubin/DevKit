import 'dart:convert';

import 'package:devkit/src/tools/json/json_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('escapes and unescapes editor text', () {
    expect(escapeJsonText('a"b'), '"a\\"b"');
    expect(unescapeJsonText('"a\\"b"'), 'a"b');
  });

  test('converts unicode escapes and chinese', () {
    expect(unicodeToChinese(r'\u4e2d\u6587'), '中文');
    expect(chineseToUnicode('中文'), r'\u4e2d\u6587');
  });

  test('converts chinese punctuation to english', () {
    expect(chinesePunctToEnglish('你好，世界。'), '你好,世界.');
  });

  test('cursorLineColumn does not copy the prefix string', () {
    expect(cursorLineColumn('a\nbc', 0), (line: 1, column: 1));
    expect(cursorLineColumn('a\nbc', 3), (line: 2, column: 2));
  });

  test('utf8ByteLength matches utf8.encode without allocating a copy for ASCII', () {
    expect(utf8ByteLength('abc'), utf8.encode('abc').length);
    expect(utf8ByteLength('中文'), utf8.encode('中文').length);
    expect(utf8ByteLength('🙂'), utf8.encode('🙂').length);
  });
}
