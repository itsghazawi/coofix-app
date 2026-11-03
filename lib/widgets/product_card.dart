import 'package:flutter/material.dart';

import '../data/config.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../screens/product.dart';
import '../theme.dart';
import 'ui.dart';
import '../data/texts.dart';

void openProduct(BuildContext context, Product p, {String tag = 'feat'}) {
  Navigator.of(context).push(PageRouteBuilder(
    settings: RouteSettings(arguments: tag),
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, a, _) => ProductScreen(p),
    transitionsBuilder: (_, a, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
      child: child,
    ),
  ));
}

class ProductCard extends StatelessWidget {
  final Product p;
  final double? width;
  final String heroTag;
  const ProductCard(this.p, {super.key, this.width, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => openProduct(context, p, tag: heroTag),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(C.radius),
          border: Border.all(color: C.line.withValues(alpha: 0.7)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: Hero(tag: '$heroTag-${p.id}', child: ProductImage(p, radius: 18, iconSize: 40))),
                  if (p.price.onSale && Cfg.i.b('products.show_discount', true) && !Cfg.i.b('products.hide_prices'))
                    PositionedDirectional(top: 8, start: 8, child: Badge2('-${p.price.discountPct}%')),
                  PositionedDirectional(top: 6, end: 6, child: _FavButton(p)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.categoryName, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.b(11.5, c: C.muted, w: FontWeight.w500)),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 42,
                    child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.b(14, w: FontWeight.w600, height: 1.45)),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 40,
                    child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: PriceView(p.price, size: 14.5, compact: true)),
                      if (Cfg.i.b('products.allow_cart', true)) _AddButton(p),
                    ],
                  ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavButton extends StatelessWidget {
  final Product p;
  const _FavButton(this.p);
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (_, _) {
        final on = Store.i.isFav(p);
        return Pressable(
          scale: 0.85,
          onTap: () => Store.i.toggleFav(p),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), shape: BoxShape.circle, boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
            ]),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  key: ValueKey(on), size: 18, color: on ? C.accent : C.text),
            ),
          ),
        );
      },
    );
  }
}

class _AddButton extends StatelessWidget {
  final Product p;
  const _AddButton(this.p);
  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.85,
      onTap: () {
        Store.i.add(p);
        toast(context, tx('product_card.1', 'أضيف إلى السلة'), icon: Icons.shopping_bag_rounded);
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}
