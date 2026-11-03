import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/config.dart';
import '../data/icons.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/product_card.dart';
import '../widgets/extras.dart';
import '../widgets/ui.dart';

class ProductScreen extends StatefulWidget {
  final Product p;
  const ProductScreen(this.p, {super.key});
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  int qty = 1;
  int img = 0;

  Product get p => widget.p;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final related = Api.i.products.where((x) => x.id != p.id && x.categoryName == p.categoryName).take(6).toList();
    final imgs = p.images;
    final cart = Cfg.i.b('products.allow_cart', true);
    final parse = Cfg.i.b('products.parse_specs_from_description', true);
    final specs = Cfg.i.b('products.show_specs', true) ? p.specsWith(parseDescription: parse) : const <MapEntry<String, String>>[];
    final about = parse && specs.isNotEmpty ? p.aboutWithoutSpecs(_about(p)) : _about(p);
    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(children: [
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                height: 420 + top,
                padding: EdgeInsets.only(top: top + 60, bottom: 30),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
                ),
                child: Column(children: [
                  Expanded(
                    child: imgs.length <= 1
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: Hero(tag: _heroTag(context), child: ProductImage(p, radius: 28, iconSize: 80)),
                          )
                        : PageView.builder(
                            itemCount: imgs.length,
                            onPageChanged: (i) => setState(() => img = i),
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 30),
                              child: i == 0
                                  ? Hero(tag: _heroTag(context), child: ProductImage(p, radius: 28, url: imgs[i]))
                                  : ProductImage(p, radius: 28, url: imgs[i]),
                            ),
                          ),
                  ),
                  if (imgs.length > 1) ...[
                    const SizedBox(height: 14),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var i = 0; i < imgs.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == img ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(color: i == img ? C.accent : C.line, borderRadius: BorderRadius.circular(6)),
                        ),
                    ]),
                  ],
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Reveal(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (p.categoryName.isNotEmpty) Badge2(p.categoryName, bg: C.ink, fg: Colors.white),
                        const SizedBox(width: 8),
                        if (p.price.onSale && Cfg.i.b('products.show_discount', true) && !Cfg.i.b('products.hide_prices')) Badge2('وفّر ${p.price.discountPct}%'),
                        const Spacer(),
                        Row(children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: p.inStock ? const Color(0xFF2BB673) : C.muted)),
                          const SizedBox(width: 6),
                          Text(p.inStock ? 'متوفر' : 'غير متوفر', style: T.b(12.5, w: FontWeight.w600, c: p.inStock ? const Color(0xFF2BB673) : C.muted)),
                        ]),
                      ]),
                      const SizedBox(height: 14),
                      if (p.sku.isNotEmpty && Cfg.i.b('products.show_sku', true)) ...[
                        Align(alignment: AlignmentDirectional.centerStart, child: SkuTag(p.sku)),
                        const SizedBox(height: 12),
                      ],
                      Text(p.name, style: T.h(23, height: 1.4)),
                      const SizedBox(height: 16),
                      PriceView(p.price, size: 24, color: C.ink),
                      const SizedBox(height: 22),
                      const _Perks(),
                      if (specs.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        Text('المواصفات الفنية', style: T.h(17)),
                        const SizedBox(height: 12),
                        _Specs(specs),
                      ],
                      if (about.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        Text('عن المنتج', style: T.h(17)),
                        const SizedBox(height: 10),
                        Text(about, style: T.b(14.5, c: const Color(0xFF4A4F57), height: 1.85)),
                      ],
                      const SizedBox(height: 18),
                      Pressable(
                        scale: 0.98,
                        onTap: () => openWhatsApp('مرحباً، لدي استفسار عن المنتج: ${p.name}${p.sku.isNotEmpty ? ' (${p.sku})' : ''}', number: Config.whatsappSupport),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: C.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: C.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.chat_rounded, color: Color(0xFF1DA851)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(Cfg.i.s('products.ask_text', 'عندك سؤال؟ اسأل خبير كوفيكس على واتساب'), style: T.b(14, w: FontWeight.w600, c: const Color(0xFF147A3B)))),
                            const Icon(Icons.arrow_forward_rounded, color: Color(0xFF1DA851), size: 20),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (related.isNotEmpty && Cfg.i.b('products.show_related', true)) ...[
              const SliverToBoxAdapter(child: SectionHeader('منتجات مشابهة')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 312,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: related.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (_, i) => ProductCard(related[i], width: 172, heroTag: 'rel${p.id}'),
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(child: SizedBox(height: 130 + bottom)),
          ],
        ),
        // Top bar
        Positioned(
          top: top + 8,
          left: 16,
          right: 16,
          child: Row(children: [
            _RoundBtn(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
            const Spacer(),
            ListenableBuilder(
              listenable: Store.i,
              builder: (_, _) {
                final on = Store.i.isFav(p);
                return _RoundBtn(
                  icon: on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: on ? C.accent : C.text,
                  onTap: () => Store.i.toggleFav(p),
                );
              },
            ),
          ]),
        ),
        // Bottom buy bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottom),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 30, offset: const Offset(0, -6))],
            ),
            child: Row(children: [
              if (cart) ...[
                _Qty(qty: qty, onChange: (v) => setState(() => qty = v)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Pressable(
                  scale: 0.97,
                  onTap: () {
                    if (!cart) {
                      openWhatsApp(orderMessage([MapEntry(p, 1)], p.price.price, p.price));
                      return;
                    }
                    Store.i.add(p, qty);
                    toast(context, 'تمت إضافة $qty إلى السلة', icon: Icons.shopping_bag_rounded);
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: C.accentGrad,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: C.accent.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(cart ? Icons.shopping_bag_rounded : Icons.chat_rounded, color: C.on(C.accent), size: 21),
                      const SizedBox(width: 10),
                      Text(cart ? 'أضف إلى السلة' : Cfg.i.s('order.button', 'اطلب عبر واتساب'), style: T.h(15.5, c: C.on(C.accent))),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  String _heroTag(BuildContext context) {
    // Matches the tag used by whichever ProductCard opened this screen.
    final route = ModalRoute.of(context);
    final tag = route?.settings.arguments as String?;
    return '${tag ?? 'feat'}-${p.id}';
  }
}

String _about(Product p) {
  final a = p.shortDesc.trim(), b = p.desc.trim();
  if (a.isEmpty) return b;
  if (b.isEmpty || b.contains(a) || a.contains(b)) return a.length >= b.length ? a : b;
  return '$a\n$b';
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? _color;
  Color get color => _color ?? C.text;
  const _RoundBtn({required this.icon, required this.onTap, Color? color}) : _color = color;
  @override
  Widget build(BuildContext context) => Pressable(
        scale: 0.88,
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      );
}

class _Qty extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChange;
  const _Qty({required this.qty, required this.onChange});
  @override
  Widget build(BuildContext context) {
    Widget b(IconData i, VoidCallback f) => Pressable(
          scale: 0.85,
          onTap: f,
          child: Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Icon(i, size: 18)),
        );
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        b(Icons.add_rounded, () => onChange(qty + 1)),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final n = await askQuantity(context, qty);
            if (n != null) onChange(n);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            constraints: const BoxConstraints(minWidth: 54),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.accent.withValues(alpha: 0.75), width: 1.4),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Text('$qty', key: ValueKey(qty), textAlign: TextAlign.center, style: T.h(17)),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_rounded, size: 13, color: C.accentDeep),
            ]),
          ),
        ),
        b(Icons.remove_rounded, () => onChange(qty > 1 ? qty - 1 : 1)),
      ]),
    );
  }
}

class _Perks extends StatelessWidget {
  const _Perks();
  @override
  Widget build(BuildContext context) {
    final perks = Cfg.i.list('products.perks').map((v) => (iconByKey('${v['icon']}', Icons.verified_rounded), '${v['title'] ?? ''}', '${v['sub'] ?? ''}')).toList();
    if (perks.isEmpty) return const SizedBox.shrink();
    return Row(children: [
      for (var i = 0; i < perks.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line)),
            child: Column(children: [
              Icon(perks[i].$1, color: C.accent, size: 24),
              const SizedBox(height: 6),
              Text(perks[i].$2, style: T.b(12.5, w: FontWeight.w700)),
              Text(perks[i].$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.b(11, c: C.muted)),
            ]),
          ),
        ),
      ],
    ]);
  }
}

class _Specs extends StatelessWidget {
  final List<MapEntry<String, String>> specs;
  const _Specs(this.specs);
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.line)),
      child: Column(children: [
        for (var i = 0; i < specs.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(border: i == specs.length - 1 ? null : const Border(bottom: BorderSide(color: C.line))),
            child: Row(children: [
              Expanded(child: Text(specs[i].key, style: T.b(13.5, c: C.muted))),
              Text(specs[i].value, style: T.b(14, w: FontWeight.w700)),
            ]),
          ),
      ]),
    );
  }
}
