import 'package:flutter/material.dart';

import '../data/config.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/product_card.dart';
import '../widgets/ui.dart';
import 'shell.dart';
import '../data/texts.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final items = Store.i.items;
        return Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 20, 20, 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tx('cart.1', 'سلة الطلب'), style: T.h(28)),
                  const SizedBox(height: 4),
                  Text(items.isEmpty ? tx('cart.2', 'سلتك فارغة') : '${Store.i.count} قطعة جاهزة للطلب', style: T.b(13.5, c: C.muted)),
                ]),
              ),
              if (items.isNotEmpty)
                Pressable(
                  onTap: () => Store.i.clear(),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(tx('cart.3', 'إفراغ'), style: T.b(14, w: FontWeight.w600, c: C.muted)),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: items.isEmpty
                ? const _Empty(
                    icon: Icons.shopping_bag_outlined,
                    title: tx('cart.4', 'لم تضف أي منتج بعد'),
                    sub: tx('cart.5', 'تصفّح عدد كوفيكس وأضف ما تحتاجه، ثم أرسل طلبك عبر واتساب بضغطة واحدة.'),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (c, i) {
                      final e = items[i];
                      return Reveal(
                        index: i,
                        child: Dismissible(
                          key: ValueKey(e.key.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => Store.i.setQty(e.key, 0),
                          background: Container(
                            alignment: AlignmentDirectional.centerEnd,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(color: const Color(0xFFE5484D), borderRadius: BorderRadius.circular(24)),
                            child: const Icon(Icons.delete_rounded, color: Colors.white),
                          ),
                          child: Pressable(
                            scale: 0.98,
                            onTap: () => openProduct(context, e.key, tag: 'cart'),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.line)),
                              child: Row(children: [
                                SizedBox(width: 88, height: 88, child: Hero(tag: 'cart-${e.key.id}', child: ProductImage(e.key, radius: 18, iconSize: 28))),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(e.key.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.b(14, w: FontWeight.w600, height: 1.4)),
                                    const SizedBox(height: 8),
                                    PriceView(e.key.price, size: 14.5),
                                  ]),
                                ),
                                const SizedBox(width: 8),
                                _Stepper(
                                  qty: e.value,
                                  onPlus: () => Store.i.setQty(e.key, e.value + 1),
                                  onMinus: () => Store.i.setQty(e.key, e.value - 1),
                                  onSet: (n) => Store.i.setQty(e.key, n),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (items.isNotEmpty) _Checkout(key: ValueKey('${Store.i.count}-${Store.i.total}')),
        ]);
      },
    );
  }
}

class _Stepper extends StatelessWidget {
  final int qty;
  final VoidCallback onPlus, onMinus;
  final ValueChanged<int> onSet;
  const _Stepper({required this.qty, required this.onPlus, required this.onMinus, required this.onSet});
  @override
  Widget build(BuildContext context) {
    Widget b(IconData i, VoidCallback f, {bool dark = false}) => Pressable(
          scale: 0.85,
          onTap: f,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: dark ? C.ink : C.bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(i, size: 17, color: dark ? Colors.white : C.text),
          ),
        );
    return Column(children: [
      b(Icons.add_rounded, onPlus, dark: true),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          final n = await askQuantity(context, qty);
          if (n != null) onSet(n);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: Text('$qty', style: T.h(15).copyWith(decoration: TextDecoration.underline, decorationColor: C.line, decorationStyle: TextDecorationStyle.dotted)),
        ),
      ),
      b(qty == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded, onMinus),
    ]);
  }
}

class _Checkout extends StatefulWidget {
  const _Checkout({super.key});
  @override
  State<_Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends State<_Checkout> {
  void _order() {
    final cfg = Cfg.i;
    final name = TextEditingController();
    final city = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();
    String? error;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.paddingOf(c).bottom),
            decoration: BoxDecoration(color: C.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(5)))),
                const SizedBox(height: 18),
                Text(cfg.s('order.sheet_title', 'إتمام الطلب'), style: T.h(21)),
                const SizedBox(height: 4),
                Text(cfg.s('order.sheet_note', 'سيتم إرسال طلبك إلى فريق كوفيكس على واتساب لتأكيده.'), style: T.b(13, c: C.muted)),
                const SizedBox(height: 18),
                if (cfg.b('order.ask_name', true)) ...[
                  Field(ctrl: name, label: cfg.b('order.require_name') ? tx('cart.6', 'الاسم الكامل *') : tx('cart.7', 'الاسم الكامل'), icon: Icons.person_rounded),
                  const SizedBox(height: 12),
                ],
                if (cfg.b('order.ask_city', true)) ...[
                  Field(ctrl: city, label: cfg.b('order.require_city') ? tx('cart.8', 'المدينة / المنطقة *') : tx('cart.9', 'المدينة / المنطقة'), icon: Icons.location_on_rounded),
                  const SizedBox(height: 12),
                ],
                if (cfg.b('order.ask_phone')) ...[
                  Field(ctrl: phone, label: cfg.b('order.require_phone') ? tx('cart.10', 'رقم الهاتف *') : tx('cart.11', 'رقم الهاتف'), icon: Icons.phone_rounded, type: TextInputType.phone),
                  const SizedBox(height: 12),
                ],
                if (cfg.b('order.ask_note', true)) ...[
                  Field(ctrl: note, label: tx('cart.12', 'ملاحظات (اختياري)'), icon: Icons.edit_note_rounded),
                  const SizedBox(height: 12),
                ],
                if (error != null) Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(error!, style: T.b(13, c: const Color(0xFFD64545), w: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                WhatsAppButton(
                  label: tx('cart.13', 'أرسل الطلب عبر واتساب'),
                  onTap: () {
                    String? miss;
                    if (cfg.b('order.ask_name', true) && cfg.b('order.require_name') && name.text.trim().isEmpty) miss = tx('cart.14', 'الاسم');
                    if (miss == null && cfg.b('order.ask_city', true) && cfg.b('order.require_city') && city.text.trim().isEmpty) miss = tx('cart.15', 'المدينة');
                    if (miss == null && cfg.b('order.ask_phone') && cfg.b('order.require_phone') && phone.text.trim().isEmpty) miss = tx('cart.11', 'رقم الهاتف');
                    if (miss != null) {
                      setSheet(() => error = 'الرجاء تعبئة $miss');
                      return;
                    }
                    final items = Store.i.items;
                    openWhatsApp(orderMessage(items, Store.i.total, items.first.key.price,
                        name: name.text.trim(), city: city.text.trim(), phone: phone.text.trim(), note: note.text.trim()));
                    Navigator.pop(c);
                  },
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = Cfg.i;
    final items = Store.i.items;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final showTotal = cfg.b('order.show_total', true) && !cfg.b('products.hide_prices') && Store.i.total > 0;
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, (bottom > 0 ? bottom : 14) + 82),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: C.inkGrad, borderRadius: BorderRadius.circular(28)),
      child: Column(children: [
        if (showTotal) ...[
          Row(children: [
            Text(cfg.s('order.total_label', 'الإجمالي التقريبي'), style: T.b(13.5, c: Colors.white.withValues(alpha: 0.6))),
            const Spacer(),
            Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(items.first.key.price.num_(Store.i.total), textDirection: TextDirection.ltr, style: T.h(20, c: Colors.white)),
              const SizedBox(width: 5),
              Text(items.first.key.price.unit, style: T.b(13, c: Colors.white.withValues(alpha: 0.7), w: FontWeight.w600)),
            ]),
          ]),
          const SizedBox(height: 14),
        ],
        WhatsAppButton(label: cfg.s('order.button', 'اطلب عبر واتساب'), onTap: _order),
      ]),
    );
  }
}

class WhatsAppButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const WhatsAppButton({super.key, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Pressable(
        scale: 0.97,
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: C.green,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: C.green.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.chat_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Text(label, style: T.h(15.5, c: Colors.white)),
          ]),
        ),
      );
}

class Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final int lines;
  final TextInputType? type;
  const Field({super.key, required this.ctrl, required this.label, required this.icon, this.lines = 1, this.type});
  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        maxLines: lines,
        keyboardType: type,
        style: T.b(15, w: FontWeight.w500),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: T.b(14.5, c: C.muted),
          prefixIcon: Icon(icon, color: C.muted),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: C.accent, width: 1.5)),
        ),
      );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const _Empty({required this.icon, required this.title, required this.sub});
  @override
  Widget build(BuildContext context) => EmptyState(icon: icon, title: title, sub: sub);
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const EmptyState({super.key, required this.icon, required this.title, required this.sub});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 100),
        child: Reveal(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(color: C.card, shape: BoxShape.circle, border: Border.all(color: C.line)),
              child: ShaderMask(shaderCallback: (r) => C.accentGrad.createShader(r), child: Icon(icon, size: 48, color: Colors.white)),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: T.h(18)),
            const SizedBox(height: 8),
            Text(sub, textAlign: TextAlign.center, style: T.b(13.5, c: C.muted, height: 1.7)),
            const SizedBox(height: 22),
            Pressable(
              onTap: () => Shell.of(context)?.go(0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(16)),
                child: Text(tx('cart.16', 'ابدأ التسوّق'), style: T.b(14, w: FontWeight.w700, c: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
