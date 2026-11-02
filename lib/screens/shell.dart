import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'cart.dart';
import 'categories.dart';
import 'favorites.dart';
import 'home.dart';
import 'more.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  static _ShellState? of(BuildContext c) => c.findAncestorStateOfType<_ShellState>();
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  void go(int i) {
    if (i == tab) return;
    HapticFeedback.lightImpact();
    setState(() => tab = i);
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent));
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [HomeScreen(), CategoriesScreen(), CartScreen(), FavoritesScreen(), MoreScreen()];
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (did, _) {
        if (!did) setState(() => tab = 0);
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(index: tab, children: pages),
        bottomNavigationBar: _NavBar(index: tab, onTap: go),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _NavBar({required this.index, required this.onTap});

  static const items = [
    (Icons.home_rounded, Icons.home_outlined, 'الرئيسية'),
    (Icons.grid_view_rounded, Icons.grid_view_outlined, 'الأقسام'),
    (Icons.shopping_bag_rounded, Icons.shopping_bag_outlined, 'السلة'),
    (Icons.favorite_rounded, Icons.favorite_border_rounded, 'المفضلة'),
    (Icons.menu_rounded, Icons.menu_rounded, 'المزيد'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom > 0 ? bottom : 14),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: C.ink,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: C.ink.withValues(alpha: 0.28), blurRadius: 30, offset: const Offset(0, 12))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Pressable(
                  scale: 0.9,
                  onTap: () => onTap(i),
                  child: _NavItem(item: items[i], active: i == index, badge: i == 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final (IconData, IconData, String) item;
  final bool active;
  final bool badge;
  const _NavItem({required this.item, required this.active, required this.badge});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      decoration: BoxDecoration(
        gradient: active ? C.accentGrad : null,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ListenableBuilder(
            listenable: Store.i,
            builder: (_, _) => Stack(clipBehavior: Clip.none, children: [
            Icon(active ? item.$1 : item.$2, size: 22, color: active ? C.ink : Colors.white.withValues(alpha: 0.55)),
            if (badge && Store.i.count > 0)
                    PositionedDirectional(
                        top: -6,
                        end: -9,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: active ? C.ink : C.accent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: C.ink, width: 1.5),
                          ),
                          child: Text('${Store.i.count}', style: T.b(10, c: Colors.white, w: FontWeight.w700, height: 1.3)),
                        ),
                      ),
          ])),
          const SizedBox(height: 2),
          Text(item.$3,
              style: T.b(10.5, w: active ? FontWeight.w700 : FontWeight.w500, c: active ? C.ink : Colors.white.withValues(alpha: 0.55), height: 1.3)),
        ],
      ),
    );
  }
}
