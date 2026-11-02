import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/icons.dart';
import '../data/models.dart';
import '../theme.dart';

/// Scales down slightly on press — gives every tappable surface a tactile feel.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.96});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

IconData categoryIcon(String slug, [String name = '']) => categoryIconFor(slug, name);

/// Network image with a branded placeholder (used when a product has no photo yet).
class ProductImage extends StatelessWidget {
  final Product p;
  final double radius;
  final double iconSize;
  final BoxFit fit;
  final String? url;
  const ProductImage(this.p, {super.key, this.radius = 20, this.iconSize = 54, this.fit = BoxFit.contain, this.url});

  @override
  Widget build(BuildContext context) {
    final src = url ?? p.cover;
    final ph = _Placeholder(icon: categoryIcon(p.categories.isEmpty ? '' : p.categories.first.slug, p.categoryName), size: iconSize);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        color: const Color(0xFFF7F6F3),
        child: src == null
            ? ph
            : CachedNetworkImage(
                imageUrl: src,
                fit: fit,
                fadeInDuration: const Duration(milliseconds: 300),
                placeholder: (_, _) => const Shimmer(),
                errorWidget: (_, _, _) => ph,
              ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final double size;
  const _Placeholder({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.9,
          colors: [Color(0xFFFFFFFF), Color(0xFFECE9E3)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Center(
            child: Container(
              padding: EdgeInsets.all(size * 0.32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.ink,
                boxShadow: [BoxShadow(color: C.ink.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: ShaderMask(
                shaderCallback: (r) => C.accentGrad.createShader(r),
                child: Icon(icon, size: size, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x0F000000)
      ..strokeWidth = 1;
    const step = 18.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Shimmer extends StatefulWidget {
  final double radius;
  const Shimmer({super.key, this.radius = 0});
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1 + _c.value * 2 - 0.6, 0),
            end: Alignment(-1 + _c.value * 2 + 0.6, 0),
            colors: const [Color(0xFFEDEBE6), Color(0xFFF8F7F4), Color(0xFFEDEBE6)],
          ),
        ),
      ),
    );
  }
}

class PriceView extends StatelessWidget {
  final Price price;
  final double size;
  final Color color;
  final bool compact;
  const PriceView(this.price, {super.key, this.size = 16, this.color = C.text, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (price.price <= 0) {
      return Text('اطلب السعر', style: T.h(size * 0.9, c: C.accent));
    }
    final main = Text(price.fmt(price.price), style: T.h(size, c: color, w: FontWeight.w700));
    if (!price.onSale) return main;
    final old = Text(
      price.fmt(price.regular),
      style: T.b(size * 0.72, c: C.muted).copyWith(decoration: TextDecoration.lineThrough, decorationColor: C.muted),
    );
    return compact
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [old, main])
        : Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, children: [main, old]);
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.subtitle, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: 4, height: 18, decoration: BoxDecoration(gradient: C.accentGrad, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 10),
                  Flexible(child: Text(title, style: T.h(19))),
                ]),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Padding(padding: const EdgeInsetsDirectional.only(start: 14), child: Text(subtitle!, style: T.b(13, c: C.muted))),
                ],
              ],
            ),
          ),
          if (action != null)
            Pressable(
              onTap: onAction,
              child: Row(children: [
                Text(action!, style: T.b(13.5, w: FontWeight.w600, c: C.accent)),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, color: C.accent, size: 20),
              ]),
            ),
        ],
      ),
    );
  }
}

class Badge2 extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const Badge2(this.text, {super.key, this.bg = C.accent, this.fg = C.ink});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
        child: Text(text, style: T.b(11.5, w: FontWeight.w700, c: fg, height: 1.3)),
      );
}

/// Fades + slides children in on first build, staggered by [index].
class Reveal extends StatelessWidget {
  final Widget child;
  final int index;
  const Reveal({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + (index.clamp(0, 8) * 70)),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

void toast(BuildContext context, String msg, {IconData icon = Icons.check_circle_rounded}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: const Duration(milliseconds: 1800),
      content: Row(children: [Icon(icon, color: C.accent2, size: 20), const SizedBox(width: 10), Expanded(child: Text(msg))]),
    ));
}
