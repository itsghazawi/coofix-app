import 'package:flutter/material.dart';

import '../theme.dart';

/// Brand mark: the square icon from the Coofix logo (assets/img/icon.png).
class BrandIcon extends StatelessWidget {
  final double size;
  const BrandIcon({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.26),
      child: Image.asset(
        'assets/img/icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(gradient: C.accentGrad),
          alignment: Alignment.center,
          child: Text('C', style: T.h(size * 0.6, c: Colors.white, w: FontWeight.w800, height: 1)),
        ),
      ),
    );
  }
}

/// Full wide logo for light surfaces (assets/img/logo.png), falls back to a wordmark.
class BrandLogo extends StatelessWidget {
  final double height;
  final bool onDark;
  const BrandLogo({super.key, this.height = 34, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      onDark ? 'assets/img/logo_dark.png' : 'assets/img/logo.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Row(mainAxisSize: MainAxisSize.min, children: [
        BrandIcon(size: height),
        const SizedBox(width: 10),
        Text('COOFIX', style: T.h(height * 0.62, c: onDark ? Colors.white : C.ink, w: FontWeight.w800).copyWith(letterSpacing: 2)),
      ]),
    );
  }
}
