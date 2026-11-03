import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/config.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/ui.dart';
import 'cart.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final cfg = Cfg.i;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    bool on(String k) => cfg.b('pages.more_items.$k', true);
    final email = cfg.s('contact.email');
    final address = cfg.s('contact.address');
    final maps = cfg.s('contact.maps_url');
    final hours = cfg.s('contact.hours');
    final site = cfg.s('contact.website', Config.site);
    final catalogue = cfg.s('contact.catalogue_url', Config.site);
    final services = <_Item>[
      if (on('maintenance')) _Item(Icons.build_circle_rounded, cfg.s('pages.maintenance_title', 'طلب صيانة'), 'مركز صيانة معتمد', () => push(const MaintenanceScreen())),
      if (on('warranty')) _Item(Icons.shield_rounded, 'الكفالة', cfg.s('pages.warranty_title', 'شروط الكفالة'), () => push(const WarrantyScreen())),
      if (on('catalogue') && catalogue.isNotEmpty) _Item(Icons.menu_book_rounded, 'تحميل الكتالوج', 'كتالوج منتجات ${Config.brand}', () => openUrl(catalogue)),
      if (on('traders')) _Item(Icons.storefront_rounded, 'للتجار', 'أسعار الجملة والشراكات',
          () => openWhatsApp(cfg.s('pages.trader_message', 'مرحباً، أنا تاجر وأرغب بالاستفسار عن أسعار الجملة.'), number: Config.whatsappSupport)),
    ];
    final contact = <_Item>[
      if (on('whatsapp')) _Item(Icons.chat_rounded, 'واتساب', Config.pretty(Config.whatsappSupport), () => openWhatsApp('مرحباً ${Config.brand} 👋', number: Config.whatsappSupport), color: C.green),
      if (on('call')) _Item(Icons.call_rounded, 'اتصال مباشر', Config.pretty(Config.phone), () => openUrl('tel:+${Config.phone}')),
      if (on('email') && email.isNotEmpty) _Item(Icons.alternate_email_rounded, 'البريد الإلكتروني', email, () => openUrl('mailto:$email')),
      if (on('website') && site.isNotEmpty) _Item(Icons.language_rounded, 'الموقع الإلكتروني', site.replaceAll(RegExp(r'^https?://(www\.)?'), '').replaceAll(RegExp(r'/$'), ''), () => openUrl(site)),
      if (on('location') && (address.isNotEmpty || maps.isNotEmpty))
        _Item(Icons.location_on_rounded, 'العنوان', address.isNotEmpty ? address : 'عرض على الخريطة', () => maps.isNotEmpty ? openUrl(maps) : null),
      if (hours.isNotEmpty) _Item(Icons.schedule_rounded, 'أوقات الدوام', hours, () {}),
    ];
    final socials = <(String, String)>[
      if (on('socials'))
        for (final k in ['facebook', 'instagram', 'tiktok', 'telegram', 'youtube'])
          if (cfg.s('contact.socials.$k').isNotEmpty) (k, cfg.s('contact.socials.$k')),
    ];
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, top + 16, 16, 130),
      children: [
        Reveal(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(gradient: C.inkGrad, borderRadius: BorderRadius.circular(30)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const BrandIcon(size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(Config.brand, style: T.h(20, c: Colors.white)),
                    const SizedBox(height: 2),
                    Text(cfg.s('general.tagline', 'الوكيل الحصري والرسمي'), style: T.b(13, c: Colors.white.withValues(alpha: 0.55))),
                  ]),
                ),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                _Stat('${Api.i.products.length}+', cfg.s('pages.stats_products_label', 'منتج')),
                _Stat('${Api.i.categories.length}', 'أقسام'),
                const _Stat('6', 'أشهر كفالة'),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 22),
        if (services.isNotEmpty) _Group(title: 'الخدمات', items: services),
        if (services.isNotEmpty) const SizedBox(height: 18),
        if (contact.isNotEmpty) _Group(title: 'تواصل معنا', items: contact),
        if (socials.isNotEmpty) ...[
          const SizedBox(height: 18),
          _Socials(socials),
        ],
        if (on('about')) ...[
          const SizedBox(height: 18),
          _Group(title: 'عن كوفيكس', items: [
            _Item(Icons.info_rounded, cfg.s('pages.about_title', 'من نحن'), 'قصة ${Config.brand}', () => push(const AboutScreen())),
          ]),
        ],
        const SizedBox(height: 26),
        Center(child: Text(cfg.s('pages.footer_note', 'الإصدار $kAppVersion'), style: T.b(12, c: C.muted))),
      ],
    );
  }
}

class _Socials extends StatelessWidget {
  final List<(String, String)> items;
  const _Socials(this.items);
  static const _meta = {
    'facebook': (Icons.facebook_rounded, 'فيسبوك', Color(0xFF1877F2)),
    'instagram': (Icons.camera_alt_rounded, 'إنستغرام', Color(0xFFE1306C)),
    'tiktok': (Icons.music_note_rounded, 'تيك توك', Color(0xFF111111)),
    'telegram': (Icons.send_rounded, 'تلغرام', Color(0xFF229ED9)),
    'youtube': (Icons.play_circle_fill_rounded, 'يوتيوب', Color(0xFFFF0000)),
  };
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 10), child: Text('تابعنا', style: T.b(13, w: FontWeight.w700, c: C.muted))),
      Row(children: [
        for (final it in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Pressable(
                onTap: () => openUrl(it.$2),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line)),
                  child: Column(children: [
                    Icon(_meta[it.$1]!.$1, color: _meta[it.$1]!.$3, size: 26),
                    const SizedBox(height: 6),
                    Text(_meta[it.$1]!.$2, style: T.b(11.5, w: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String v, l;
  const _Stat(this.v, this.l);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsetsDirectional.only(end: 8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text(v, style: T.h(18, c: C.accent2)),
            Text(l, style: T.b(11.5, c: Colors.white.withValues(alpha: 0.6))),
          ]),
        ),
      );
}

class _Item {
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  final Color? _color;
  Color get color => _color ?? C.accent;
  const _Item(this.icon, this.title, this.sub, this.onTap, {Color? color}) : _color = color;
}

class _Group extends StatelessWidget {
  final String title;
  final List<_Item> items;
  const _Group({required this.title, required this.items});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 10), child: Text(title, style: T.b(13, w: FontWeight.w700, c: C.muted))),
      Container(
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.line)),
        child: Column(children: [
          for (var i = 0; i < items.length; i++)
            Pressable(
              scale: 0.98,
              onTap: items[i].onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(border: i == items.length - 1 ? null : const Border(bottom: BorderSide(color: C.line))),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: items[i].color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                    child: Icon(items[i].icon, color: items[i].color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(items[i].title, style: T.b(15, w: FontWeight.w600)),
                      Text(items[i].sub, style: T.b(12.5, c: C.muted)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: C.muted),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _Page extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Page({required this.title, required this.icon, required this.children});
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, top + 10, 20, 28),
            decoration: BoxDecoration(gradient: C.inkGrad, borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Pressable(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(height: 22),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(gradient: C.accentGrad, borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, color: C.ink, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(title, style: T.h(24, c: Colors.white))),
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
            child: Reveal(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
          ),
        ],
      ),
    );
  }
}

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});
  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final tool = TextEditingController();
  final issue = TextEditingController();
  bool warranty = true;

  @override
  Widget build(BuildContext context) {
    return _Page(title: Cfg.i.s('pages.maintenance_title', 'طلب صيانة'), icon: Icons.build_circle_rounded, children: [
      Text(Cfg.i.s('pages.maintenance_intro', 'عبّئ البيانات وسيتواصل معك فريق الصيانة المعتمد لتحديد موعد الاستلام.'), style: T.b(14, c: C.muted, height: 1.7)),
      const SizedBox(height: 20),
      Field(ctrl: name, label: 'الاسم', icon: Icons.person_rounded),
      const SizedBox(height: 12),
      Field(ctrl: phone, label: 'رقم الهاتف', icon: Icons.phone_rounded, type: TextInputType.phone),
      const SizedBox(height: 12),
      Field(ctrl: tool, label: 'نوع العدة وموديلها', icon: Icons.handyman_rounded),
      const SizedBox(height: 12),
      Field(ctrl: issue, label: 'وصف المشكلة', icon: Icons.report_problem_rounded, lines: 3),
      const SizedBox(height: 14),
      Pressable(
        scale: 0.98,
        onTap: () => setState(() => warranty = !warranty),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: warranty ? C.accent : C.line)),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: warranty ? C.accent : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: warranty ? C.accent : C.muted)),
              child: warranty ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('العدة ضمن فترة الكفالة', style: T.b(14.5, w: FontWeight.w600))),
          ]),
        ),
      ),
      const SizedBox(height: 22),
      WhatsAppButton(
        label: 'أرسل طلب الصيانة',
        onTap: () => openWhatsApp('طلب صيانة 🔧\n'
            'الاسم: ${name.text}\n'
            'الهاتف: ${phone.text}\n'
            'العدة: ${tool.text}\n'
            'المشكلة: ${issue.text}\n'
            'ضمن الكفالة: ${warranty ? 'نعم' : 'لا'}', number: Config.whatsappMaintenance),
      ),
    ]);
  }
}

class WarrantyScreen extends StatelessWidget {
  const WarrantyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final points = Cfg.i.list('pages.warranty_points').map((p) => ('${p['title'] ?? ''}', '${p['body'] ?? ''}')).toList();
    return _Page(title: Cfg.i.s('pages.warranty_title', 'كفالة 6 أشهر'), icon: Icons.shield_rounded, children: [
      for (var i = 0; i < points.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.line)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(10)),
              child: Text('${i + 1}', style: T.h(14, c: C.accent2)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(points[i].$1, style: T.h(15.5)),
                const SizedBox(height: 4),
                Text(points[i].$2, style: T.b(13.5, c: C.muted, height: 1.7)),
              ]),
            ),
          ]),
        ),
    ]);
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _Page(title: Cfg.i.s('pages.about_title', 'من نحن'), icon: Icons.info_rounded, children: [
      const Center(child: BrandLogo(height: 54)),
      const SizedBox(height: 22),
      Text(Cfg.i.s('pages.about_body'), style: T.b(15, height: 1.9, c: const Color(0xFF4A4F57))),
    ]);
  }
}
