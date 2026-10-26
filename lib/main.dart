import 'package:devkit/src/app.dart';
import 'package:devkit/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const DevKitApp());
}
