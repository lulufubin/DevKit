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
  var line = 1;
  var lineStart = 0;
  for (var i = 0; i < safe; i++) {
    if (text.codeUnitAt(i) == 0x0A) {
      line++;
      lineStart = i + 1;
    }
  }
  return (line: line, column: safe - lineStart + 1);
}

/// 统计 UTF-8 字节数，避免 `utf8.encode` 再分配一份大文本。
int utf8ByteLength(String text) {
  var n = 0;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit < 0x80) {
      n += 1;
    } else if (unit < 0x800) {
      n += 2;
    } else if (unit >= 0xD800 && unit <= 0xDBFF) {
      n += 4;
      i++;
    } else {
      n += 3;
    }
  }
  return n;
}
