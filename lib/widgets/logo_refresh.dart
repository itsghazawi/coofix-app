import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pull-to-refresh with the COOFIX logo (instead of the browser-style circle):
/// pull down → the logo appears and turns with your finger; let go → it spins until done.
class LogoRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final String asset;
  final double top;
  const LogoRefresh({super.key, required this.child, required this.onRefresh, this.asset = 'assets/img/icon.png', this.top = 0});
  @override
  State<LogoRefresh> createState() => _LogoRefreshState();
}

class _LogoRefreshState extends State<LogoRefresh> with SingleTickerProviderStateMixin {
  static const _trigger = 90.0;
  double _pull = 0;
  bool _busy = false, _armed = false;
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    _spin.repeat();
    try {
      await widget.onRefresh();
    } catch (_) {}
    if (!mounted) return;
    _spin.stop();
    setState(() {
      _busy = false;
      _pull = 0;
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final d = math.max(0.0, -(n.metrics.pixels - n.metrics.minScrollExtent));
    if (n is ScrollUpdateNotification) {
      if (n.dragDetails != null) {
        if (!_armed && d >= _trigger) HapticFeedback.selectionClick();
        _armed = d >= _trigger;
      } else if (_armed && !_busy) {
        _armed = false;
        _run();
      }
    } else if (n is OverscrollNotification && n.dragDetails != null) {
      // Clamping scroll (no bounce): grow the pull from the overscroll amount.
      final v = (_pull + (-n.overscroll) * 0.5).clamp(0.0, 140.0).toDouble();
      setState(() => _pull = v);
      _armed = v >= _trigger;
      return false;
    } else if (n is ScrollEndNotification) {
      if (_armed && !_busy) {
        _armed = false;
        _run();
      }
      if (!_busy && _pull != 0) setState(() => _pull = 0);
      return false;
    }
    if (n is! OverscrollNotification && d != _pull && !_busy) setState(() => _pull = d);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = _busy ? 1.0 : (_pull / _trigger).clamp(0.0, 1.0);
    final top = MediaQuery.paddingOf(context).top + widget.top;
    return Stack(children: [
      NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child),
      Positioned(
        top: top + 10 + 18 * Curves.easeOut.transform(t),
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: t > 0.05 ? 1 : 0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                scale: t > 0.05 ? 1 : 0.7,
                child: AnimatedBuilder(
                  animation: _spin,
                  builder: (_, __) {
                    final v = _spin.value;
                    final pulse = _busy ? 1 + 0.06 * math.sin(v * 2 * math.pi) : 0.85 + 0.15 * t;
                    return SizedBox(
                      width: 58,
                      height: 58,
                      child: Stack(alignment: Alignment.center, children: [
                        // soft glass disc
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [BoxShadow(color: const Color(0xFFFAA21B).withValues(alpha: 0.18 + 0.2 * t), blurRadius: 22, offset: const Offset(0, 6))],
                          ),
                        ),
                        // golden ring: fills with the pull, then orbits while loading
                        CustomPaint(size: const Size(58, 58), painter: _Ring(progress: t, busy: _busy, phase: v)),
                        Transform.scale(
                          scale: pulse,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.asset(widget.asset, width: 34, height: 34, fit: BoxFit.cover),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Ring extends CustomPainter {
  final double progress, phase;
  final bool busy;
  _Ring({required this.progress, required this.busy, required this.phase});

  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(3, 3, s.width - 6, s.height - 6);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFFAA21B).withValues(alpha: 0.15);
    c.drawArc(r, 0, 2 * math.pi, false, track);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(colors: [Color(0xFFFFC14F), Color(0xFFFAA21B), Color(0xFFE08A00), Color(0xFFFFC14F)]).createShader(r);
    if (busy) {
      final start = phase * 2 * math.pi - math.pi / 2;
      final sweep = math.pi * (0.55 + 0.35 * math.sin(phase * 2 * math.pi).abs());
      c.drawArc(r, start, sweep, false, p);
    } else {
      c.drawArc(r, -math.pi / 2, 2 * math.pi * progress, false, p);
    }
  }

  @override
  bool shouldRepaint(_Ring o) => o.progress != progress || o.phase != phase || o.busy != busy;
}
