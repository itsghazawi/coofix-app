import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/config.dart';
import '../data/icons.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/actions.dart';
import '../widgets/brand.dart';
import '../widgets/extras.dart';
import '../widgets/notices.dart';
import '../widgets/product_card.dart';
import '../widgets/ui.dart';
import 'categories.dart';
import 'more.dart';
import 'search.dart';
import 'shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _refresh() async {
    await Api.i.load();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final api = Api.i;
    final cfg = Cfg.i;
    String t(Map<String, dynamic> s, String def) => (s['title'] ?? '').toString().trim().isEmpty ? def : '${s['title']}';
    String? sub(Map<String, dynamic> s) => (s['subtitle'] ?? '').toString().trim().isEmpty ? null : '${s['subtitle']}';
    Widget grid(List<Product> items, String tag) => SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, mainAxisExtent: 304),
            delegate: SliverChildBuilderDelegate((c, i) => Reveal(index: i, child: ProductCard(items[i], heroTag: tag)), childCount: items.length),
          ),
        );

    final slivers = <Widget>[const SliverToBoxAdapter(child: _Header())];
    var sections = cfg.homeSections;
    if (sections.isEmpty) {
      sections = [for (final k in ['hero', 'categories', 'deals', 'values', 'featured', 'maintenance']) {'key': k, 'enabled': true}];
    }
    for (final sec in sections) {
      if (sec['enabled'] == false) continue;
      switch (sec['key']) {
        case 'announcement':
          slivers.add(const SliverToBoxAdapter(child: AnnouncementBar()));
        case 'hero':
          if (_HeroCarouselState.slides.isNotEmpty) slivers.add(const SliverToBoxAdapter(child: _HeroCarousel()));
        case 'categories':
          if (api.categories.isEmpty) break;
          slivers.add(SliverToBoxAdapter(child: SectionHeader(t(sec, 'تسوّق حسب القسم'), subtitle: sub(sec), action: 'الكل', onAction: () => Shell.of(context)?.goKey('categories'))));
          slivers.add(SliverToBoxAdapter(child: _CategoryStrip(api.categories)));
        case 'deals':
          final deals = api.deals;
          if (deals.isEmpty) break;
          slivers.add(SliverToBoxAdapter(child: SectionHeader(t(sec, 'عروض حصرية'), subtitle: sub(sec))));
          slivers.add(SliverToBoxAdapter(child: _HorizontalProducts(deals, tag: 'deal')));
        case 'values':
          slivers.add(const SliverToBoxAdapter(child: _Values()));
        case 'latest':
          final l = api.latest;
          if (l.isEmpty) break;
          slivers.add(SliverToBoxAdapter(child: SectionHeader(t(sec, 'وصل حديثاً'), subtitle: sub(sec))));
          slivers.add(SliverToBoxAdapter(child: _HorizontalProducts(l, tag: 'new')));
        case 'featured':
          final f = api.featured;
          if (f.isEmpty) break;
          slivers.add(SliverToBoxAdapter(child: SectionHeader(t(sec, 'الأكثر طلباً'), subtitle: sub(sec))));
          slivers.add(grid(f, 'feat'));
        case 'maintenance':
          slivers.add(SliverToBoxAdapter(child: _MaintenanceBanner(title: t(sec, 'مركز الصيانة المعتمد'), sub: sub(sec) ?? 'تابع حالة عدّتك برقم الطلب أو الهاتف')));
      }
    }
    slivers.add(const SliverToBoxAdapter(child: AppFooter()));
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 120)));

    return RefreshIndicator(
      color: C.accent,
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: slivers,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, top + 14, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const BrandIcon(size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(Cfg.i.s('general.welcome_small', 'أهلاً بك في'), style: T.b(12.5, c: C.muted)),
                Text(Cfg.i.s('general.welcome_big', 'كوفيكس سوريا'), style: T.h(19)),
              ]),
            ),
            Pressable(
              onTap: () => openWhatsApp('مرحباً ${Config.brand} 👋', number: Config.whatsappSupport),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(15), border: Border.all(color: C.line)),
                child: Icon(Icons.support_agent_rounded, color: C.text),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          Pressable(
            scale: 0.98,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
            child: Hero(
              tag: 'search',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: C.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: C.line),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 14, offset: const Offset(0, 6))],
                  ),
                  child: Row(children: [
                    const Icon(Icons.search_rounded, color: C.muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(Cfg.i.s('general.search_hint', 'ابحث عن مثقب، جلاخة، كمبريسور...'), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.b(14, c: C.muted))),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.tune_rounded, size: 18, color: Colors.white),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  final String kicker, title, sub, cta, image, style, actionType, actionValue;
  final IconData icon;
  const _Slide(this.kicker, this.title, this.sub, this.cta, this.icon, this.image, this.style, this.actionType, this.actionValue);

  factory _Slide.fromJson(Map<String, dynamic> j) => _Slide(
        '${j['kicker'] ?? ''}', '${j['title'] ?? ''}', '${j['subtitle'] ?? ''}', '${j['cta'] ?? ''}',
        iconByKey('${j['icon']}', Icons.bolt_rounded), '${j['image'] ?? ''}', '${j['style'] ?? 'dark'}',
        '${j['action_type'] ?? 'none'}', '${j['action_value'] ?? ''}');

  List<Color> get colors => switch (style) {
        'accent' => [C.accent2, C.accentDeep],
        'light' => [Colors.white, const Color(0xFFEDEAE4)],
        'dark2' => [C.ink, C.inkLight],
        _ => [C.inkLight, C.ink],
      };
  bool get lightBg => style == 'accent' || style == 'light';
}

class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel();
  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _pc = PageController(viewportFraction: 0.9);
  int _i = 0;
  Timer? _t;

  static List<_Slide> get slides => Cfg.i.list('banners').where((b) => b['enabled'] != false).map(_Slide.fromJson).toList();

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(Duration(milliseconds: (Cfg.i.d('banner_seconds', 5).clamp(2, 30) * 1000).round()), (_) {
      if (!_pc.hasClients || slides.length < 2) return;
      _pc.animateToPage((_i + 1) % slides.length, duration: const Duration(milliseconds: 700), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pc.dispose();
    super.dispose();
  }

  void _cta(int i) {
    final l = slides;
    if (i >= l.length) return;
    runAction(context, l[i].actionType, l[i].actionValue);
  }

  @override
  Widget build(BuildContext context) {
    final slides = _HeroCarouselState.slides;
    if (slides.isEmpty) return const SizedBox.shrink();
    if (_i >= slides.length) _i = 0;
    return Column(children: [
      const SizedBox(height: 16),
      SizedBox(
        height: Cfg.i.d('banner_height', 196).clamp(120, 420).toDouble(),
        child: PageView.builder(
          controller: _pc,
          itemCount: slides.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (c, i) {
            final s = slides[i];
            final light = s.lightBg;
            final fg = light ? C.ink : Colors.white;
            return AnimatedBuilder(
              animation: _pc,
              builder: (_, child) {
                double v = 0;
                if (_pc.position.haveDimensions) v = (_pc.page! - i).abs().clamp(0, 1).toDouble();
                return Transform.scale(scale: 1 - v * 0.06, child: child);
              },
              child: Pressable(
                scale: 0.98,
                onTap: () => _cta(i),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: s.colors),
                    boxShadow: [BoxShadow(color: s.colors.last.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: s.style == 'image' && s.image.isNotEmpty
                      ? CachedNetworkImage(imageUrl: s.image, fit: BoxFit.cover, width: double.infinity, placeholder: (_, _) => const Shimmer())
                      : Stack(children: [
                    if (s.image.isNotEmpty)
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: s.image,
                          fit: BoxFit.cover,
                          color: Colors.black.withValues(alpha: light ? 0 : 0.35),
                          colorBlendMode: BlendMode.darken,
                          errorWidget: (_, _, _) => const SizedBox(),
                        ),
                      ),
                    PositionedDirectional(
                      end: -30,
                      bottom: -40,
                      child: Icon(s.icon, size: 210, color: fg.withValues(alpha: 0.07)),
                    ),
                    PositionedDirectional(
                      end: 22,
                      top: 22,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: fg.withValues(alpha: 0.1),
                          border: Border.all(color: fg.withValues(alpha: 0.15)),
                        ),
                        child: Icon(s.icon, color: light ? C.ink : C.accent, size: 30),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (s.kicker.isNotEmpty) Badge2(s.kicker, bg: fg.withValues(alpha: 0.12), fg: fg),
                          const SizedBox(height: 10),
                          Text(s.title, style: T.h(22, c: fg, height: 1.3)),
                          const Spacer(),
                          Row(children: [
                            Expanded(child: Text(s.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.b(12.5, c: fg.withValues(alpha: 0.75)))),
                            if (s.cta.isNotEmpty) Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(color: light ? C.ink : C.accent, borderRadius: BorderRadius.circular(30)),
                              child: Text(s.cta, style: T.b(12.5, w: FontWeight.w700, c: light ? Colors.white : C.ink, height: 1.3)),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < slides.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _i ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == _i ? C.accent : C.line,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
        ],
      ),
    ]);
  }
}

class _CategoryStrip extends StatelessWidget {
  final List<Category> cats;
  const _CategoryStrip(this.cats);
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (c, i) {
          final k = cats[i];
          return Reveal(
            index: i,
            child: Pressable(
              onTap: () => openCategory(context, k),
              child: SizedBox(
                width: 80,
                child: Column(children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: i == 0 ? C.ink : C.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: i == 0 ? C.ink : C.line),
                    ),
                    child: Center(
                      child: ShaderMask(
                        shaderCallback: (r) => C.accentGrad.createShader(r),
                        child: Icon(categoryIcon(k.slug, k.name, k.id), size: 32, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(k.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.b(12, w: FontWeight.w600)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HorizontalProducts extends StatelessWidget {
  final List<Product> items;
  final String tag;
  const _HorizontalProducts(this.items, {required this.tag});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 312,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (c, i) => Reveal(index: i, child: ProductCard(items[i], width: 172, heroTag: tag)),
      ),
    );
  }
}

class _Values extends StatelessWidget {
  const _Values();
  @override
  Widget build(BuildContext context) {
    final vals = Cfg.i.list('pages.values').map((v) => (iconByKey('${v['icon']}', Icons.verified_rounded), '${v['title'] ?? ''}', '${v['sub'] ?? ''}')).toList();
    if (vals.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(gradient: C.inkGrad, borderRadius: BorderRadius.circular(28)),
      child: Row(
        children: [
          for (final v in vals)
            Expanded(
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: C.accent.withValues(alpha: 0.14)),
                  child: Icon(v.$1, color: C.accent2, size: 24),
                ),
                const SizedBox(height: 10),
                Text(v.$2, style: T.h(13.5, c: Colors.white)),
                const SizedBox(height: 4),
                Text(v.$3, textAlign: TextAlign.center, style: T.b(11, c: Colors.white.withValues(alpha: 0.55), height: 1.4)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _MaintenanceBanner extends StatelessWidget {
  final String title, sub;
  const _MaintenanceBanner({required this.title, required this.sub});
  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.98,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MaintenanceScreen())),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 28, 16, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: C.line),
        ),
        child: Row(children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(gradient: C.accentGrad, borderRadius: BorderRadius.circular(18)),
            child: Icon(Icons.build_circle_rounded, color: C.ink, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.h(16)),
              const SizedBox(height: 3),
              Text(sub, style: T.b(12.5, c: C.muted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.arrow_forward_rounded, size: 20),
          ),
        ]),
      ),
    );
  }
}
