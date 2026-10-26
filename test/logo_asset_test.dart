import 'package:devkit/src/widgets/devkit_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('picks logo asset from brightness', () {
    expect(logoAssetFor(Brightness.light), 'logo/devkit-logo-light.svg');
    expect(logoAssetFor(Brightness.dark), 'logo/devkit-logo-dark.svg');
  });
}
