import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/product_card.dart';
import '../widgets/ui.dart';
import 'cart.dart';
import '../data/texts.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final items = Api.i.products.where(Store.i.isFav).toList();
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, top + 20, 20, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tx('favorites.1', 'المفضلة'), style: T.h(28)),
                  const SizedBox(height: 4),
                  Text(items.isEmpty ? tx('favorites.2', 'احفظ المنتجات التي تعجبك هنا') : '${items.length} منتج محفوظ', style: T.b(13.5, c: C.muted)),
                ]),
              ),
            ),
            if (items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: tx('favorites.3', 'لا توجد منتجات مفضلة'),
                  sub: tx('favorites.4', 'اضغط على القلب في أي منتج لحفظه والرجوع إليه لاحقاً.'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 304,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (c, i) => Reveal(index: i, child: ProductCard(items[i], heroTag: 'fav')),
                    childCount: items.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
