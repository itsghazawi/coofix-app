import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/models.dart';

/// Order invoice drawn at A4 (794×1123 logical px) — rendered to a PDF on the device.
class InvoiceDoc extends StatelessWidget {
  final String number;
  final DateTime date;
  final List<MapEntry<Product, int>> items;
  final Price fmt;
  final num subtotal;
  final num discount;
  final String couponCode;
  final String couponLabel;
  final String name, city, phone, note;
  final bool hidePrices;

  const InvoiceDoc({
    super.key,
    required this.number,
    required this.date,
    required this.items,
    required this.fmt,
    required this.subtotal,
    this.discount = 0,
    this.couponCode = '',
    this.couponLabel = '',
    this.name = '',
    this.city = '',
    this.phone = '',
    this.note = '',
    this.hidePrices = false,
  });

  static const ink = Color(0xFF061922);
  static const amber = Color(0xFFFAA21B);
  static const soft = Color(0xFFF4F3F0);
  static const muted = Color(0xFF6B7079);
  static const line = Color(0xFFE6E3DD);

  TextStyle h(double s, {Color c = const Color(0xFF15181D), FontWeight w = FontWeight.w800}) =>
      TextStyle(fontFamily: 'Alexandria', fontSize: s, color: c, fontWeight: w, height: 1.3, decoration: TextDecoration.none);
  TextStyle b(double s, {Color c = const Color(0xFF15181D), FontWeight w = FontWeight.w500}) =>
      TextStyle(fontFamily: 'Plex', fontSize: s, color: c, fontWeight: w, height: 1.5, decoration: TextDecoration.none);

  String money(num v) => fmt.fmt(v);

  @override
  Widget build(BuildContext context) {
    final d = '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} — ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    Widget info(String k, String v, {int flex = 1, bool ltr = false}) => Expanded(
          flex: flex,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k, style: b(12, c: muted)),
              const SizedBox(height: 2),
              Text(v.isEmpty ? '—' : v, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: ltr ? TextDirection.ltr : null, style: b(15, w: FontWeight.w700)),
            ]),
          ),
        );
    Widget perk(IconData i, String t) => Expanded(
          child: Row(children: [Icon(i, size: 18, color: const Color(0xFFB56A00)), const SizedBox(width: 8), Text(t, style: b(12.5, c: const Color(0xFF4A4F57)))]),
        );
    final total = subtotal - discount;
    return Container(
      width: 794,
      height: 1123,
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        Container(
          color: ink,
          padding: const EdgeInsets.fromLTRB(48, 40, 48, 34),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF0F3041), borderRadius: BorderRadius.circular(18), border: Border.all(color: amber.withValues(alpha: 0.45))),
              child: Image.asset('assets/img/icon.png'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(Config.brand, style: h(24, c: Colors.white)),
                const SizedBox(height: 2),
                Text('الوكيل الحصري والرسمي في سوريا', style: b(13, c: Colors.white.withValues(alpha: 0.62))),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('ORDER', style: h(13, c: amber, w: FontWeight.w700).copyWith(letterSpacing: 3)),
              Text('طلب شراء', style: h(26, c: Colors.white)),
              const SizedBox(height: 4),
              Text(number, textDirection: TextDirection.ltr, style: b(13, c: Colors.white.withValues(alpha: 0.62))),
            ]),
          ]),
        ),
        Container(height: 5, color: amber),
        // Customer
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 28, 48, 0),
          child: Column(children: [
            Row(children: [info('الزبون', name), const SizedBox(width: 12), info('رقم الهاتف', phone, ltr: true), const SizedBox(width: 12), info('التاريخ', d)]),
            const SizedBox(height: 12),
            Row(children: [info('العنوان', city, flex: 2), const SizedBox(width: 12), info('طريقة الدفع', 'الدفع عند الاستلام')]),
          ]),
        ),
        // Items
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 24, 48, 0),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ink, width: 2))),
              child: Row(children: [
                Expanded(child: Text('المنتج', style: b(12, c: muted, w: FontWeight.w600))),
                if (!hidePrices) SizedBox(width: 110, child: Text('السعر', textAlign: TextAlign.center, style: b(12, c: muted, w: FontWeight.w600))),
                SizedBox(width: 70, child: Text('الكمية', textAlign: TextAlign.center, style: b(12, c: muted, w: FontWeight.w600))),
                if (!hidePrices) SizedBox(width: 120, child: Text('المجموع', textAlign: TextAlign.left, style: b(12, c: muted, w: FontWeight.w600))),
              ]),
            ),
            for (final e in items.take(9))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: line))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.key.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: b(15, w: FontWeight.w700)),
                      if (e.key.sku.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                          decoration: BoxDecoration(color: amber.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(7)),
                          child: Text(e.key.sku, textDirection: TextDirection.ltr, style: h(11, c: const Color(0xFF7A4700), w: FontWeight.w700)),
                        ),
                    ]),
                  ),
                  if (!hidePrices) SizedBox(width: 110, child: Text(money(e.key.price.price), textAlign: TextAlign.center, textDirection: TextDirection.ltr, style: b(14))),
                  SizedBox(width: 70, child: Text('${e.value}', textAlign: TextAlign.center, style: b(15, w: FontWeight.w700))),
                  if (!hidePrices) SizedBox(width: 120, child: Text(money(e.key.price.price * e.value), textAlign: TextAlign.left, textDirection: TextDirection.ltr, style: h(15, w: FontWeight.w700))),
                ]),
              ),
            if (items.length > 9)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text('+ ${items.length - 9} منتجات أخرى (مذكورة في الرسالة)', style: b(12.5, c: muted))),
          ]),
        ),
        // Totals
        if (!hidePrices)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 20, 48, 0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SizedBox(
                width: 330,
                child: Column(children: [
                  Row(children: [Text('المجموع الفرعي', style: b(14, c: const Color(0xFF4A4F57))), const Spacer(), Text(money(subtotal), textDirection: TextDirection.ltr, style: b(14, c: const Color(0xFF4A4F57)))]),
                  if (discount > 0) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Text('حسم', style: b(14, c: const Color(0xFF16794A), w: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFFE8F7EE), borderRadius: BorderRadius.circular(6)),
                        child: Text(couponLabel.isNotEmpty ? '$couponCode  $couponLabel' : couponCode, textDirection: TextDirection.ltr, style: h(11.5, c: const Color(0xFF16794A), w: FontWeight.w700)),
                      ),
                      const Spacer(),
                      Text('- ${money(discount)}', textDirection: TextDirection.ltr, style: b(14, c: const Color(0xFF16794A), w: FontWeight.w700)),
                    ]),
                  ],
                  const SizedBox(height: 6),
                  Row(children: [Text('التوصيل', style: b(14, c: const Color(0xFF4A4F57))), const Spacer(), Text('يُحدَّد عند التأكيد', style: b(14, c: const Color(0xFF4A4F57)))]),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      Text('الإجمالي', style: b(15, c: Colors.white, w: FontWeight.w700)),
                      const Spacer(),
                      Text(money(total), textDirection: TextDirection.ltr, style: h(22, c: amber)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        if (note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 20, 48, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD9D5CC))),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: 'ملاحظات الزبون: ', style: b(13, w: FontWeight.w700)),
                TextSpan(text: note, style: b(13, c: const Color(0xFF4A4F57))),
              ])),
            ),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 0, 48, 16),
          child: Row(children: [
            perk(Icons.shield_outlined, 'كفالة 6 أشهر'),
            perk(Icons.verified_outlined, 'منتجات أصلية 100%'),
            perk(Icons.local_shipping_outlined, 'توصيل لكل المحافظات'),
          ]),
        ),
        Container(
          color: soft,
          padding: const EdgeInsets.fromLTRB(48, 16, 48, 16),
          child: Row(children: [
            Text('شكراً لثقتك بكوفيكس — سنتواصل معك لتأكيد الطلب', style: b(12.5, c: const Color(0xFF4A4F57))),
            const Spacer(),
            Text('coofix.sy · ${Config.pretty(Config.whatsapp)}', textDirection: TextDirection.ltr, style: b(12.5, c: const Color(0xFF4A4F57), w: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}
