import 'package:devkit/main.dart';
import 'package:devkit/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  testWidgets('shows encrypt page after rust init', (tester) async {
    await tester.pumpWidget(const DevKitApp());
    expect(find.text('DevKit'), findsOneWidget);
    expect(find.text('加密'), findsOneWidget);
  });
}
