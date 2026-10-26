import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

String logoAssetFor(Brightness brightness) {
  return brightness == Brightness.dark
      ? 'logo/devkit-logo-dark.svg'
      : 'logo/devkit-logo-light.svg';
}

class DevKitLogo extends StatelessWidget {
  const DevKitLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = logoAssetFor(Theme.of(context).brightness);
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      key: ValueKey(asset),
    );
  }
}
