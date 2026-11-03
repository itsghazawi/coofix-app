import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/api.dart';

import '../data/config.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/product_card.dart';
import '../widgets/ui.dart';
import 'shell.dart';

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
                  Text('سلة الطلب', style: T.h(28)),
                  const SizedBox(height: 4),
                  Text(items.isEmpty ? 'سلتك فارغة' : '${Store.i.count} قطعة جاهزة للطلب', style: T.b(13.5, c: C.muted)),
                ]),
              ),
              if (items.isNotEmpty)
                Pressable(
                  onTap: () => Store.i.clear(),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('إفراغ', style: T.b(14, w: FontWeight.w600, c: C.muted)),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: items.isEmpty
                ? const _Empty(
                    icon: Icons.shopping_bag_outlined,
                    title: 'لم تضف أي منتج بعد',
                    sub: 'تصفّح عدد كوفيكس وأضف ما تحتاجه، ثم أرسل طلبك عبر واتساب بضغطة واحدة.',
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
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          constraints: const BoxConstraints(minWidth: 48),
          padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C.accent.withValues(alpha: 0.7), width: 1.4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$qty', style: T.h(15)),
            const SizedBox(width: 4),
            Icon(Icons.edit_rounded, size: 12, color: C.accentDeep),
          ]),
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

/// Result of a discount-code check (WooCommerce coupon on the site).
class CouponResult {
  final String code, label, message;
  final num discount;
  CouponResult(this.code, this.label, this.discount, this.message);
}

Future<Object> checkCoupon(String code, {bool use = false}) async {
  try {
    final r = await http
        .post(Uri.parse('${Config.site}/wp-json/coofix-app/v1/coupon'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'code': code.trim(),
              'use': use ? 1 : 0,
              'items': [for (final e in Store.i.items) {'id': e.key.id, 'qty': e.value}],
            }))
        .timeout(const Duration(seconds: 15));
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j is Map && j['ok'] == true) {
      return CouponResult('${j['code']}', '${j['label'] ?? ''}', (j['discount'] as num?) ?? 0, '${j['message'] ?? ''}');
    }
    return (j is Map ? j['message'] : null)?.toString() ?? 'الكود غير صحيح';
  } catch (_) {
    return 'تعذّر التحقق من الكود، تحقق من الإنترنت';
  }
}

class _CheckoutState extends State<_Checkout> {
  void _order() {
    final cfg = Cfg.i;
    final name = TextEditingController();
    final area = TextEditingController();
    final phone = TextEditingController();
    String? gov;
    final code = TextEditingController();
    String? error, codeMsg;
    CouponResult? coupon;
    bool checking = false, sending = false;
    final fmt = Store.i.items.first.key.price;
    final hide = cfg.b('products.hide_prices');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) {
          Future<void> apply() async {
            if (code.text.trim().isEmpty) return;
            FocusScope.of(c).unfocus();
            setSheet(() {
              checking = true;
              codeMsg = null;
            });
            final r = await checkCoupon(code.text);
            setSheet(() {
              checking = false;
              if (r is CouponResult) {
                coupon = r;
                codeMsg = null;
              } else {
                coupon = null;
                codeMsg = '$r';
              }
            });
          }

          Future<void> send() async {
            String? miss;
            if (gov == null) miss = 'المحافظة';
            if (miss == null && area.text.trim().isEmpty) miss = 'المنطقة';
            if (miss == null && name.text.trim().isEmpty) miss = 'الاسم الثلاثي';
            if (miss == null && phone.text.trim().isEmpty) miss = 'رقم الهاتف';
            if (miss != null) {
              setSheet(() => error = 'الرجاء تعبئة $miss');
              return;
            }
            setSheet(() {
              sending = true;
              error = null;
            });
            final items = Store.i.items;
            final now = DateTime.now();
            final number = 'ORD-${now.year % 100}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
            var text = orderMessage(items, Store.i.total, fmt, name: name.text.trim(), city: '$gov — ${area.text.trim()}', phone: phone.text.trim());
            if (coupon != null) {
              text += '\n\nكود الحسم: ${coupon!.code} (${coupon!.label})\nالحسم: ${fmt.fmt(coupon!.discount)}\nالإجمالي بعد الحسم: ${fmt.fmt(Store.i.total - coupon!.discount)}';
              unawaited(checkCoupon(coupon!.code, use: true));
            }
            text = 'رقم الطلب: $number\n$text';
            await openWhatsApp(text);
            if (c.mounted) Navigator.pop(c);
          }

          final sub = Store.i.total;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.paddingOf(c).bottom),
              decoration: BoxDecoration(color: C.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(5)))),
                  const SizedBox(height: 18),
                  Text(cfg.s('order.sheet_title', 'إتمام الطلب'), style: T.h(21)),
                  const SizedBox(height: 4),
                  Text(cfg.s('order.sheet_note', 'سيتم إرسال طلبك إلى فريق كوفيكس على واتساب لتأكيده.'), style: T.b(13, c: C.muted)),
                  const SizedBox(height: 18),
                  Text('معلومات الشحن', style: T.h(15)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: gov,
                    isExpanded: true,
                    hint: Text('المحافظة *', style: T.b(14.5, c: C.muted)),
                    items: [for (final g in const ['دمشق', 'ريف دمشق', 'حلب', 'حمص', 'حماة', 'اللاذقية', 'طرطوس', 'إدلب', 'درعا', 'السويداء', 'القنيطرة', 'دير الزور', 'الرقة', 'الحسكة']) DropdownMenuItem(value: g, child: Text(g, style: T.b(15, w: FontWeight.w500)))],
                    onChanged: (v) => setSheet(() => gov = v),
                    borderRadius: BorderRadius.circular(16),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.map_rounded, color: C.muted),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.line)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: C.accent, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Field(ctrl: area, label: 'المنطقة *', icon: Icons.location_on_rounded, action: TextInputAction.next),
                  const SizedBox(height: 12),
                  Field(ctrl: name, label: 'الاسم الثلاثي *', icon: Icons.person_rounded, action: TextInputAction.next),
                  const SizedBox(height: 12),
                  Field(ctrl: phone, label: 'رقم الهاتف *', icon: Icons.phone_rounded, type: TextInputType.phone, action: TextInputAction.done, ltr: true),
                  const SizedBox(height: 12),
                  if (cfg.b('order.coupons', true) && !hide) ...[
                    Row(children: [
                      Expanded(child: Field(ctrl: code, label: 'كود الحسم (إن وجد)', icon: Icons.local_offer_rounded)),
                      const SizedBox(width: 8),
                      Pressable(
                        onTap: checking ? null : apply,
                        child: Container(
                          height: 54,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(16)),
                          child: checking
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                              : Text('تطبيق', style: T.h(14, c: Colors.white)),
                        ),
                      ),
                    ]),
                    if (codeMsg != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(codeMsg!, style: T.b(12.5, c: const Color(0xFFD64545), w: FontWeight.w600))),
                    if (coupon != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                        decoration: BoxDecoration(color: const Color(0xFFE8F7EE), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFB6E5C8))),
                        child: Row(children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF16794A), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${coupon!.code} • حسم ${coupon!.label} = ${fmt.fmt(coupon!.discount)}', style: T.b(13, c: const Color(0xFF16794A), w: FontWeight.w700)),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setSheet(() {
                              coupon = null;
                              code.clear();
                            }),
                            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF16794A)),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 12),
                  ],
                  if (!hide && sub > 0)
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
                      child: Column(children: [
                        if (coupon != null) ...[
                          Row(children: [Text('المجموع', style: T.b(13.5, c: C.muted)), const Spacer(), Text(fmt.fmt(sub), textDirection: TextDirection.ltr, style: T.b(13.5, c: C.muted))]),
                          const SizedBox(height: 4),
                          Row(children: [
                            Text('الحسم', style: T.b(13.5, c: const Color(0xFF16794A), w: FontWeight.w600)),
                            const Spacer(),
                            Text('- ${fmt.fmt(coupon!.discount)}', textDirection: TextDirection.ltr, style: T.b(13.5, c: const Color(0xFF16794A), w: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 6),
                        ],
                        Row(children: [
                          Text('الإجمالي', style: T.h(15)),
                          const Spacer(),
                          Text(fmt.fmt(sub - (coupon?.discount ?? 0)), textDirection: TextDirection.ltr, style: T.h(18)),
                        ]),
                      ]),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(error!, style: T.b(13, c: const Color(0xFFD64545), w: FontWeight.w600)),
                    ),
                  WhatsAppButton(label: 'أرسل الطلب عبر واتساب', onTap: sending ? () {} : send),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = Cfg.i;
    final items = Store.i.items;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final showTotal = cfg.b('order.show_total', true) && !cfg.b('products.hide_prices') && Store.i.total > 0;
    // Docked right above the bottom navigation bar.
    return Container(
      margin: EdgeInsets.fromLTRB(16, 8, 16, (bottom > 0 ? bottom : 14) + 18),
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        gradient: C.inkGrad,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: C.ink.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        if (showTotal)
          Expanded(
            flex: 4,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cfg.s('order.total_label', 'الإجمالي التقريبي'), style: T.b(11.5, c: Colors.white.withValues(alpha: 0.6))),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text(items.first.key.price.num_(Store.i.total), textDirection: TextDirection.ltr, style: T.h(19, c: Colors.white)),
                  const SizedBox(width: 4),
                  Text(items.first.key.price.unit, style: T.b(12, c: Colors.white.withValues(alpha: 0.7), w: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
        if (showTotal) const SizedBox(width: 10),
        Expanded(flex: 6, child: WhatsAppButton(label: cfg.s('order.button', 'اطلب عبر واتساب'), onTap: _order, height: 50)),
      ]),
    );
  }
}

class WhatsAppButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double height;
  const WhatsAppButton({super.key, required this.label, required this.onTap, this.height = 56});
  @override
  Widget build(BuildContext context) => Pressable(
        scale: 0.97,
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: C.green,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: C.green.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.chat_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.h(15.5, c: Colors.white))),
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
  final TextInputAction? action;
  final bool ltr;
  const Field({super.key, required this.ctrl, required this.label, required this.icon, this.lines = 1, this.type, this.action, this.ltr = false});
  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        maxLines: lines,
        keyboardType: type,
        textInputAction: action ?? TextInputAction.done,
        textDirection: ltr ? TextDirection.ltr : null,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        onSubmitted: (_) => action == TextInputAction.next ? FocusScope.of(context).nextFocus() : FocusManager.instance.primaryFocus?.unfocus(),
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
                child: Text('ابدأ التسوّق', style: T.b(14, w: FontWeight.w700, c: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
