import 'package:devkit/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows streaming encrypt UI', (tester) async {
    await tester.pumpWidget(const DevKitApp());
    expect(find.text('DevKit'), findsOneWidget);
    expect(find.text('加密'), findsOneWidget);
    expect(find.text('解密'), findsOneWidget);
    expect(find.text('输入文件'), findsOneWidget);
    expect(find.text('输出文件'), findsOneWidget);
  });
}
