import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/config.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/product_card.dart';
import '../widgets/ui.dart';
import '../data/i18n.dart';

void openCategory(BuildContext context, Category c) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryProductsScreen(c)));
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cats = Api.i.topCategories;
    final top = MediaQuery.paddingOf(context).top;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, top + 20, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('الأقسام'), style: T.h(28)),
              const SizedBox(height: 4),
              Text(trf('{0} منتج في {1} أقسام', [Api.i.products.length, cats.length]), style: T.b(13.5, c: C.muted)),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
          sliver: SliverList.separated(
            itemCount: cats.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (c, i) => Reveal(index: i, child: _CategoryTile(cats[i], dark: Cfg.i.n('categories.dark_every', 3) > 0 && i % Cfg.i.n('categories.dark_every', 3) == 0)),
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category c;
  final bool dark;
  const _CategoryTile(this.c, {required this.dark});

  @override
  Widget build(BuildContext context) {
    final items = Api.i.byCategory(c.id);
    final fg = dark ? Colors.white : C.text;
    return Pressable(
      scale: 0.98,
      onTap: () => openCategory(context, c),
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          gradient: dark ? C.inkGrad : null,
          color: dark ? null : C.card,
          borderRadius: BorderRadius.circular(26),
          border: dark ? null : Border.all(color: C.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          PositionedDirectional(
            end: -18,
            bottom: -26,
            child: Icon(categoryIcon(c.slug, c.name, c.id), size: 150, color: (dark ? Colors.white : C.ink).withValues(alpha: 0.05)),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: dark ? Colors.white.withValues(alpha: 0.08) : C.bg,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (r) => C.accentGrad.createShader(r),
                    child: Icon(categoryIcon(c.slug, c.name, c.id), size: 34, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: T.h(18, c: fg)),
                    SizedBox(height: 4),
                    Text(trf('{0} منتج', [items.length]), style: T.b(13, c: dark ? Colors.white.withValues(alpha: 0.55) : C.muted)),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: dark ? C.accent : C.ink,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class CategoryProductsScreen extends StatefulWidget {
  final Category? c;
  /// Shown as a bottom-bar tab (no back button, room for the bar).
  final bool asTab;
  CategoryProductsScreen(Category this.c, {super.key}) : asTab = false;
  /// Every product in the store, as one browsable list.
  const CategoryProductsScreen.all({super.key, this.asTab = true}) : c = null;
  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

enum _Sort { def, low, high, deal }

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  _Sort sort = _Sort.def;
  Category? sub;

  List<Product> get items {
    final l = widget.c == null ? [...Api.i.products] : [...Api.i.byCategory((sub ?? widget.c!).id)];
    switch (sort) {
      case _Sort.low:
        l.sort((a, b) => a.price.price.compareTo(b.price.price));
      case _Sort.high:
        l.sort((a, b) => b.price.price.compareTo(a.price.price));
      case _Sort.deal:
        l.sort((a, b) => b.price.discountPct.compareTo(a.price.discountPct));
      case _Sort.def:
        break;
    }
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final list = items;
    final labels = {_Sort.def: tr('المقترح'), _Sort.low: tr('الأقل سعراً'), _Sort.high: tr('الأعلى سعراً'), _Sort.deal: tr('العروض')};
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 170,
            backgroundColor: C.ink,
            foregroundColor: Colors.white,
            leading: widget.asTab ? null : const _BackBtn(),
            automaticallyImplyLeading: !widget.asTab,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsetsDirectional.only(start: widget.asTab ? 20 : 60, bottom: 16, end: 20),
              title: Text(widget.c?.name ?? trf('كل المنتجات ({0})', [Api.i.products.length]), style: T.h(18, c: Colors.white)),
              background: Container(
                decoration: BoxDecoration(gradient: C.inkGrad),
                child: Stack(children: [
                  PositionedDirectional(
                    end: -20,
                    bottom: -30,
                    child: Icon(widget.c == null ? Icons.apps_rounded : categoryIcon(widget.c!.slug, widget.c!.name, widget.c!.id), size: 190, color: C.accent.withValues(alpha: 0.12)),
                  ),
                ]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 64,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final s in _Sort.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: Pressable(
                        onTap: () => setState(() => sort = s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sort == s ? C.ink : C.card,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: sort == s ? C.ink : C.line),
                          ),
                          child: Text(labels[s]!, style: T.b(13, w: FontWeight.w600, c: sort == s ? Colors.white : C.text)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.c != null && Api.i.childrenOf(widget.c!.id).isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 54,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final k in [null, ...Api.i.childrenOf(widget.c!.id)])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: Pressable(
                          onTap: () => setState(() => sub = k),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: sub?.id == k?.id ? C.accent : Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: sub?.id == k?.id ? C.accent : C.line),
                            ),
                            child: Text(k == null ? tr('الكل') : k.name, style: T.b(12.5, w: FontWeight.w700, c: sub?.id == k?.id ? C.on(C.accent) : C.text)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text(tr('لا توجد منتجات في هذا القسم حالياً'), style: T.b(14, c: C.muted))),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, widget.asTab ? 130 : 40),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 304,
                ),
                delegate: SliverChildBuilderDelegate(
                  (c, i) => Reveal(key: ValueKey('${sort.name}-${list[i].id}'), index: i, child: ProductCard(list[i], heroTag: 'cat')),
                  childCount: list.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BackBtn extends StatelessWidget {
  const _BackBtn();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Pressable(
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
    );
  }
}
