import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/brand.dart';
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
    final deals = api.deals;
    return RefreshIndicator(
      color: C.accent,
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          const SliverToBoxAdapter(child: _Header()),
          const SliverToBoxAdapter(child: _HeroCarousel()),
          SliverToBoxAdapter(
            child: SectionHeader('تسوّق حسب القسم', action: 'الكل', onAction: () => Shell.of(context)?.go(1)),
          ),
          SliverToBoxAdapter(child: _CategoryStrip(api.categories)),
          if (deals.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader('عروض حصرية', subtitle: 'خصومات لفترة محدودة')),
            SliverToBoxAdapter(child: _HorizontalProducts(deals, tag: 'deal')),
          ],
          const SliverToBoxAdapter(child: _Values()),
          const SliverToBoxAdapter(child: SectionHeader('الأكثر طلباً', subtitle: 'اختيارات المحترفين في الورش')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: 292,
              ),
              delegate: SliverChildBuilderDelegate(
                (c, i) => Reveal(index: i, child: ProductCard(api.featured[i], heroTag: 'feat')),
                childCount: api.featured.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: _MaintenanceBanner()),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
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
                Text('أهلاً بك في', style: T.b(12.5, c: C.muted)),
                Text('كوفيكس سوريا', style: T.h(19)),
              ]),
            ),
            Pressable(
              onTap: () => openUrl('https://wa.me/${Config.whatsapp}'),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(15), border: Border.all(color: C.line)),
                child: const Icon(Icons.support_agent_rounded, color: C.text),
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
                    Expanded(child: Text('ابحث عن مثقب، جلاخة، كمبريسور...', style: T.b(14, c: C.muted))),
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
  final String kicker, title, sub, cta;
  final IconData icon;
  final List<Color> colors;
  const _Slide(this.kicker, this.title, this.sub, this.cta, this.icon, this.colors);
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

  static const slides = [
    _Slide('الوكيل الحصري', 'قوة احترافية\nبين يديك', 'عدد كوفيكس الأصلية بكفالة 6 أشهر', 'تسوّق الآن', Icons.bolt_rounded,
        [Color(0xFF0F3041), Color(0xFF061922)]),
    _Slide('حرية بلا أسلاك', 'عدد البطارية\nبتقنية الليثيوم', 'منصة 20V واحدة لكل عدتك', 'اكتشف التشكيلة', Icons.battery_charging_full_rounded,
        [Color(0xFFFFB83D), Color(0xFFE08A00)]),
    _Slide('للتجار والورش', 'أسعار خاصة\nلطلبات الجملة', 'تواصل مع فريق المبيعات مباشرة', 'راسلنا واتساب', Icons.storefront_rounded,
        [Color(0xFF15394A), Color(0xFF0A202B)]),
  ];

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pc.hasClients) return;
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
    if (i == 2) {
      openUrl('https://wa.me/${Config.whatsapp}?text=${Uri.encodeComponent('مرحباً، أرغب بالاستفسار عن أسعار الجملة للتجار.')}');
    } else if (i == 1) {
      final cat = Api.i.categories.where((c) => categoryIcon(c.slug, c.name) == Icons.battery_charging_full_rounded).firstOrNull;
      if (cat != null) {
        openCategory(context, cat);
        return;
      }
      Shell.of(context)?.go(1);
    } else {
      Shell.of(context)?.go(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 16),
      SizedBox(
        height: 196,
        child: PageView.builder(
          controller: _pc,
          itemCount: slides.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (c, i) {
            final s = slides[i];
            final light = i == 1;
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
                  child: Stack(children: [
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
                          Badge2(s.kicker, bg: fg.withValues(alpha: 0.12), fg: fg),
                          const SizedBox(height: 10),
                          Text(s.title, style: T.h(22, c: fg, height: 1.3)),
                          const Spacer(),
                          Row(children: [
                            Expanded(child: Text(s.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.b(12.5, c: fg.withValues(alpha: 0.75)))),
                            Container(
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
                        child: Icon(categoryIcon(k.slug, k.name), size: 32, color: Colors.white),
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
      height: 300,
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
    const vals = [
      (Icons.verified_rounded, 'جودة أصلية', 'منتجات معتمدة من الشركة الأم'),
      (Icons.shield_rounded, 'كفالة 6 أشهر', 'صيانة وقطع غيار مضمونة'),
      (Icons.handshake_rounded, 'نرحّب بالتجار', 'أسعار جملة وشراكات'),
    ];
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
  const _MaintenanceBanner();
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
            child: const Icon(Icons.build_circle_rounded, color: C.ink, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مركز الصيانة المعتمد', style: T.h(16)),
              const SizedBox(height: 3),
              Text('اطلب صيانة لعدّتك خلال دقيقة واحدة', style: T.b(12.5, c: C.muted)),
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
