import 'package:devkit/src/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('workbench shows tool navigation', (tester) async {
    await tester.pumpWidget(const DevKitApp());
    expect(find.text('JSON 格式化'), findsWidgets);
    expect(find.text('加解密'), findsOneWidget);
    expect(find.text('HAR'), findsOneWidget);
  });
}
