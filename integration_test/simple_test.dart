import 'package:devkit/src/app.dart';
import 'package:devkit/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  testWidgets('shows workbench after rust init', (tester) async {
    await tester.pumpWidget(const DevKitApp());
    expect(find.text('JSON'), findsOneWidget);
    expect(find.text('加解密'), findsOneWidget);
    expect(find.text('HAR'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
  });
}
