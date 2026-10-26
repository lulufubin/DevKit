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
}
