import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/config.dart';
import '../data/store.dart';
import '../widgets/notices.dart';
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
  static _ShellState? current;
  int tab = 0;

  static const keys = ['home', 'categories', 'cart', 'favorites', 'more'];
  bool navVisible = true;

  void go(int i) {
    if (i == tab) return;
    HapticFeedback.lightImpact();
    setState(() {
      tab = i;
      navVisible = true;
    });
  }

  void goKey(String key) {
    final i = keys.indexOf(key.trim());
    if (i >= 0) go(i);
  }

  @override
  void initState() {
    super.initState();
    current = this;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent));
    WidgetsBinding.instance.addPostFrameCallback((_) => _startupNotices());
  }

  Future<void> _startupNotices() async {
    if (!mounted) return;
    if (await maybeShowUpdate(context)) return;
    if (mounted) await maybeShowPopup(context);
  }

  @override
  Widget build(BuildContext context) {
    if (Cfg.i.b('general.maintenance.enabled')) return const MaintenanceModeScreen();
    final pages = const [HomeScreen(), CategoriesScreen(), CartScreen(), FavoritesScreen(), MoreScreen()];
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (did, _) {
        if (!did) setState(() => tab = 0);
      },
      child: Scaffold(
        extendBody: true,
        body: NotificationListener<ScrollUpdateNotification>(
          onNotification: (n) {
            if (n.metrics.axis != Axis.vertical) return false;
            final d = n.scrollDelta ?? 0;
            if (n.metrics.pixels < 60) {
              if (!navVisible) setState(() => navVisible = true);
            } else if (d > 4 && navVisible) {
              setState(() => navVisible = false);
            } else if (d < -4 && !navVisible) {
              setState(() => navVisible = true);
            }
            return false;
          },
          child: IndexedStack(index: tab, children: pages),
        ),
        bottomNavigationBar: AnimatedSlide(
          offset: navVisible ? Offset.zero : const Offset(0, 1.6),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: navVisible ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: _NavBar(index: tab, onTap: go),
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _NavBar({required this.index, required this.onTap});

  static List<(IconData, IconData, String)> get items => [
        (Icons.home_rounded, Icons.home_outlined, Cfg.i.s('nav.home', 'الرئيسية')),
        (Icons.grid_view_rounded, Icons.grid_view_outlined, Cfg.i.s('nav.categories', 'الأقسام')),
        (Icons.shopping_bag_rounded, Icons.shopping_bag_outlined, Cfg.i.s('nav.cart', 'السلة')),
        (Icons.favorite_rounded, Icons.favorite_border_rounded, Cfg.i.s('nav.favorites', 'المفضلة')),
        (Icons.menu_rounded, Icons.menu_rounded, Cfg.i.s('nav.more', 'المزيد')),
      ];

  static bool visible(int i) {
    if (i == 2) return Cfg.i.b('products.allow_cart', true);
    if (i == 3) return Cfg.i.b('nav.show_favorites', true);
    return true;
  }

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
              if (visible(i))
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

/// Jump to the cart tab from anywhere (closes pushed pages first).
void openCartTab(BuildContext context) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  _ShellState.current?.goKey('cart');
}
