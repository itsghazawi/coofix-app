import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api.dart';
import '../data/config.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import 'shell.dart';
import '../data/i18n.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _go();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/img/icon.png'), context);
  }

  Future<void> _go() async {
    await Future.wait([
      Api.i.load(),
      Store.i.init(),
      Future.delayed(Duration(milliseconds: (Cfg.i.d('brand.splash_seconds', 2.6).clamp(0.8, 8) * 1000).round())),
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 700),
      pageBuilder: (_, _, _) => const Shell(),
      transitionsBuilder: (_, a, _, c) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: c),
      ),
    ));
  }

  @override
  void dispose() {
    _intro.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.55, curve: Curves.easeOutBack));
    final text = CurvedAnimation(parent: _intro, curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic));
    final bar = CurvedAnimation(parent: _intro, curve: const Interval(0.55, 1, curve: Curves.easeInOut));
    return Scaffold(
      backgroundColor: C.ink,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.25), radius: 1.1, colors: [Color(0xFF123747), C.ink]),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _LinesPainter())),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 190,
                    height: 190,
                    child: Stack(alignment: Alignment.center, children: [
                      AnimatedBuilder(
                        animation: _spin,
                        builder: (_, _) => Transform.rotate(
                          angle: _spin.value * 2 * math.pi,
                          child: FadeTransition(opacity: text, child: CustomPaint(size: const Size(190, 190), painter: _RingPainter())),
                        ),
                      ),
                      ScaleTransition(
                        scale: icon,
                        child: Container(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), boxShadow: [
                            BoxShadow(color: C.accent.withValues(alpha: 0.45), blurRadius: 60, spreadRadius: 4),
                          ]),
                          child: const BrandIcon(size: 108),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 26),
                  FadeTransition(
                    opacity: text,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(text),
                      child: Column(children: [
                        Text(Cfg.i.s('brand.splash_title', 'COOFIX'), style: T.h(30, c: Colors.white, w: FontWeight.w800).copyWith(letterSpacing: 8)),
                        const SizedBox(height: 6),
                        Text(Cfg.i.s('brand.splash_sub', tr('كوفيكس سوريا')), style: T.h(17, c: Colors.white.withValues(alpha: 0.9), w: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(Cfg.i.s('brand.splash_note', tr('الوكيل الحصري والرسمي في سوريا')), textAlign: TextAlign.center, style: T.b(13, c: Colors.white.withValues(alpha: 0.5))),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 64,
              child: Center(
                child: SizedBox(
                  width: 120,
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(children: [
                      Container(color: Colors.white.withValues(alpha: 0.08)),
                      AnimatedBuilder(
                        animation: bar,
                        builder: (_, _) => FractionallySizedBox(
                          widthFactor: bar.value,
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(decoration: BoxDecoration(gradient: C.accentGrad)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: Offset(r, r), radius: r - 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(colors: [Colors.transparent, C.accent2, C.accent, Colors.transparent], stops: [0, 0.35, 0.6, 1]).createShader(rect);
    canvas.drawArc(rect, 0, math.pi * 1.6, false, p);
    final dots = Paint()..color = Colors.white.withValues(alpha: 0.12);
    for (var i = 0; i < 48; i++) {
      final a = i / 48 * 2 * math.pi;
      canvas.drawCircle(Offset(r + (r - 14) * math.cos(a), r + (r - 14) * math.sin(a)), 1, dots);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 26) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
