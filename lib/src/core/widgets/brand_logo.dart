import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 72,
    this.white = false,
  });

  final double size;
  final bool white;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      white
          ? 'assets/images/shilota_logo_white.png'
          : 'assets/images/shilota_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
