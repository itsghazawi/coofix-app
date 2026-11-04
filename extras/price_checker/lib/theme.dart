import 'dart:math' as math;

import 'package:flutter/material.dart';

// Coofix palette — same as the maintenance app.
const ink = Color(0xFF061922);
const inkLight = Color(0xFF0F3041);
const inkMid = Color(0xFF0D2F3E);
const amber = Color(0xFFFAA21B);
const amber2 = Color(0xFFFFC14F);
const amberDeep = Color(0xFFE08A00);
const bg = Color(0xFFF4F3F0);
const line = Color(0xFFE6E3DD);
const muted = Color(0xFF8A8F98);
const textC = Color(0xFF15181D);
const danger = Color(0xFFDC2626);
const ok = Color(0xFF16A34A);

const amberGrad = LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [amber2, amber, amberDeep]);
const inkGrad = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [inkLight, ink]);
const darkBgGrad = LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [inkMid, ink, Color(0xFF020A0E)]);

TextStyle h(double s, {Color c = textC, FontWeight w = FontWeight.w700, double height = 1.3}) =>
    TextStyle(fontFamily: 'Alexandria', fontSize: s, color: c, fontWeight: w, height: height, fontVariations: [FontVariation('wght', w.value.toDouble())]);
TextStyle b(double s, {Color c = textC, FontWeight w = FontWeight.w400, double height = 1.5}) =>
    TextStyle(fontFamily: 'Plex', fontSize: s, color: c, fontWeight: w, height: height);

/// Faint hexagon grid used on every dark Coofix screen.
class HexPainter extends CustomPainter {
  final double opacity;
  final double radius;
  const HexPainter({this.opacity = 0.055, this.radius = 26});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = amber.withValues(alpha: opacity);
    final r = radius;
    final w = math.sqrt(3) * r, hgt = 1.5 * r;
    for (var row = -1; row * hgt < size.height + r; row++) {
      for (var col = -1; col * w < size.width + w; col++) {
        final cx = col * w + (row.isOdd ? w / 2 : 0), cy = row * hgt;
        final path = Path();
        for (var i = 0; i < 6; i++) {
          final a = math.pi / 180 * (60 * i - 30);
          final x = cx + r * math.cos(a), y = cy + r * math.sin(a);
          i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
        }
        path.close();
        canvas.drawPath(path, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant HexPainter o) => o.opacity != opacity || o.radius != radius;
}

/// Dark branded background: gradient + hex grid + amber glows.
class DarkBackdrop extends StatelessWidget {
  final Widget child;
  final double glow;
  const DarkBackdrop({super.key, required this.child, this.glow = 1});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final g = size.shortestSide * 0.95;
    return Stack(children: [
      const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: darkBgGrad))),
      const Positioned.fill(child: CustomPaint(painter: HexPainter())),
      Positioned(
        top: -g * 0.38, right: -g * 0.3,
        child: IgnorePointer(child: Container(width: g, height: g, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [amber.withValues(alpha: 0.20 * glow), amber.withValues(alpha: 0)])))),
      ),
      Positioned(
        bottom: -g * 0.42, left: -g * 0.36,
        child: IgnorePointer(child: Container(width: g * 1.05, height: g * 1.05, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [amber.withValues(alpha: 0.11 * glow), amber.withValues(alpha: 0)])))),
      ),
      Positioned.fill(child: child),
    ]);
  }
}

/// Big amber gradient button with soft glow.
class AmberButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final double glow;
  const AmberButton({super.key, required this.label, this.icon, this.onTap, this.height = 64, this.fontSize = 20, this.glow = 0.5});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: amberGrad,
        borderRadius: BorderRadius.circular(height * 0.34),
        boxShadow: [BoxShadow(color: amber.withValues(alpha: 0.25 + glow * 0.3), blurRadius: 24 + glow * 26, offset: const Offset(0, 10))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(height * 0.34),
          onTap: onTap,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, color: ink, size: fontSize * 1.35), SizedBox(width: fontSize * 0.55)],
            Text(label, style: h(fontSize, c: ink, w: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

/// Glassy outlined button for dark surfaces.
class GlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  const GlassButton({super.key, required this.label, this.icon, this.onTap, this.height = 56, this.fontSize = 16});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height * 0.34), side: BorderSide(color: Colors.white.withValues(alpha: 0.14))),
      child: InkWell(
        borderRadius: BorderRadius.circular(height * 0.34),
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: fontSize * 1.3), SizedBox(width: fontSize * 0.5)],
            Padding(
              padding: EdgeInsets.symmetric(horizontal: icon == null ? fontSize : 0),
              child: Text(label, style: h(fontSize, c: Colors.white.withValues(alpha: 0.92), w: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Scale factor so phone, tablet portrait and tablet landscape all look right.
double uiScale(Size s, {double w = 430, double hgt = 860}) {
  final land = s.width > s.height * 1.15;
  final v = land ? math.min(s.width / (w * 2.2), s.height / (hgt * 0.62)) : math.min(s.width / w, s.height / hgt);
  return v.clamp(0.78, 2.1);
}
