import 'package:devkit/src/widgets/fast_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('short text stays in the regular editor', () {
    expect(isHeavyText('{"a":1}'), isFalse);
    expect(isHeavyText('A' * 100), isFalse);
  });

  test('long document or long line switches to preview', () {
    expect(isHeavyText('A' * fastTextCharThreshold), isTrue);
    expect(isHeavyText('A' * fastTextLongLineThreshold), isTrue);
  });

  test('FastTextIndex splits newlines and chunks long lines', () {
    final lines = FastTextIndex('one\ntwo\nthree');
    expect(lines.length, 3);
    expect(lines.lineAt(0), 'one');
    expect(lines.lineAt(1), 'two');
    expect(lines.lineAt(2), 'three');

    final chunks = FastTextIndex('ABCDEFGH', chunkSize: 3);
    expect(chunks.length, 3);
    expect(chunks.lineAt(0), 'ABC');
    expect(chunks.lineAt(1), 'DEF');
    expect(chunks.lineAt(2), 'GH');
  });

  testWidgets('small text still uses TextField', (tester) async {
    final controller = TextEditingController(text: '{"a":1}');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FastTextField(controller: controller)),
      ),
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('快速预览'), findsNothing);
  });

  testWidgets('heavy text uses preview and keeps the full string', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FastTextField(controller: controller)),
      ),
    );
    controller.text = 'A' * (256 * 1024);
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('快速预览'), findsOneWidget);
    expect(controller.text.length, 256 * 1024);
  });
}
