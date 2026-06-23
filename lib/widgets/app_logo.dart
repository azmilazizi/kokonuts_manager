import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      isDark
          ? 'assets/images/app_logo_dark.png'
          : 'assets/images/app_logo_light.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
