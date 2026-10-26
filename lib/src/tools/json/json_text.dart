import 'dart:convert';

String escapeJsonText(String text) => jsonEncode(text);

String unescapeJsonText(String text) {
  final trimmed = text.trim();
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is String) {
      return decoded;
    }
  } catch (_) {}
  return trimmed.replaceAllMapped(RegExp(r'\\([\\"/bfnrt])'), (match) {
    return switch (match[1]) {
      '\\' => '\\',
      '"' => '"',
      '/' => '/',
      'b' => '\b',
      'f' => '\f',
      'n' => '\n',
      'r' => '\r',
      't' => '\t',
      _ => match[0]!,
    };
  });
}

String unicodeToChinese(String text) {
  return text.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (match) {
    return String.fromCharCode(int.parse(match[1]!, radix: 16));
  });
}

String chineseToUnicode(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    if (rune > 0x7F && rune <= 0xFFFF) {
      out.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
    } else {
      out.write(String.fromCharCode(rune));
    }
  }
  return out.toString();
}

const _punct = {
  '，': ',',
  '。': '.',
  '；': ';',
  '：': ':',
  '？': '?',
  '！': '!',
  '（': '(',
  '）': ')',
  '【': '[',
  '】': ']',
  '「': '"',
  '」': '"',
  '『': '"',
  '』': '"',
  '、': ',',
  '《': '<',
  '》': '>',
};

String chinesePunctToEnglish(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    out.write(_punct[ch] ?? ch);
  }
  return out.toString();
}

({int line, int column}) cursorLineColumn(String text, int offset) {
  final safe = offset.clamp(0, text.length);
  final before = text.substring(0, safe);
  final lineBreak = before.lastIndexOf('\n');
  return (line: '\n'.allMatches(before).length + 1, column: safe - lineBreak);
}
