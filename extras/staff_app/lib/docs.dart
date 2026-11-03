import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';


export 'docs_core.dart';

const _ink = Color(0xFF061922);
const _amber = Color(0xFFFAA21B);
const _amber2 = Color(0xFFFFC14F);
const _soft = Color(0xFFF7F6F3);
const _muted = Color(0xFF6B7079);
const _line = Color(0xFFE6E3DD);

TextStyle _h(double s, {Color c = const Color(0xFF15181D), FontWeight w = FontWeight.w800}) =>
    TextStyle(fontFamily: 'Alexandria', fontSize: s, color: c, fontWeight: w, height: 1.3, decoration: TextDecoration.none);
TextStyle _b(double s, {Color c = const Color(0xFF15181D), FontWeight w = FontWeight.w500}) =>
    TextStyle(fontFamily: 'Plex', fontSize: s, color: c, fontWeight: w, height: 1.5, decoration: TextDecoration.none);

String _s(Map r, String k) => '${r[k] ?? ''}'.trim();

/// Tracking link printed as QR on the receipt.
String trackUrl(String site, String code) => '$site/repair/?repair=${Uri.encodeComponent(code)}';

/// Download a photo for the documents (kept in memory only).
Future<Uint8List?> fetchBytes(String url) async {
  if (url.isEmpty) return null;
  try {
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    return r.statusCode == 200 ? r.bodyBytes : null;
  } catch (_) {
    return null;
  }
}

/// A4 intake receipt (794×1123) — QR to tracking + intake photo + received-by.
class ReceiptDoc extends StatelessWidget {
  final Map<String, dynamic> r;
  final String site;
  final Uint8List? photo;
  const ReceiptDoc({super.key, required this.r, required this.site, this.photo});

  @override
  Widget build(BuildContext context) {
    final code = _s(r, 'code');
    final rows = <(String, String)>[
      ('اسم الزبون', _s(r, 'name')),
      ('رقم الهاتف', _s(r, 'phone')),
      ('كود المنتج', _s(r, 'product_code')),
      ('الرقم التسلسلي', _s(r, 'serial')),
      ('الملحقات', r['accessories'] == true ? (_s(r, 'accessories_text').isEmpty ? 'نعم' : _s(r, 'accessories_text')) : 'بدون ملحقات'),
      ('الكفالة', r['warranty'] == true ? 'ضمن الكفالة${_s(r, 'purchase_date').isNotEmpty ? ' — تاريخ الشراء ${_s(r, 'purchase_date')}' : ''}' : 'خارج الكفالة'),
      ('الحالة', _s(r, 'status_label').isEmpty ? 'تم الاستلام' : _s(r, 'status_label')),
    ];
    return Container(
      width: 794,
      height: 1123,
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 40, 48, 0),
          child: Row(children: [
            Container(width: 58, height: 58, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(16)), child: Image.asset('assets/img/icon.png')),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('صيانة كوفيكس', style: _h(22)),
                Text('مركز الصيانة المعتمد — كوفيكس سوريا', style: _b(12.5, c: _muted)),
              ]),
            ),
            Text('إيصال استلام', style: _h(22)),
          ]),
        ),
        // Code + dates
        Container(
          margin: const EdgeInsets.fromLTRB(48, 24, 48, 0),
          padding: const EdgeInsets.fromLTRB(28, 22, 22, 22),
          decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('رقم الطلب — احتفظ فيه للمتابعة', style: _b(13, c: Colors.white.withValues(alpha: 0.6))),
                Text(code, textDirection: TextDirection.ltr, style: _h(42, c: _amber).copyWith(letterSpacing: 3)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Text('موعد الصيانة', style: _b(12, c: Colors.white.withValues(alpha: 0.6))),
                Text(_s(r, 'scheduled_label'), style: _b(15, c: Colors.white, w: FontWeight.w700)),
              ]),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(color: _amber, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Text('التسليم', style: _b(12, c: _ink, w: FontWeight.w600)),
                Text(_s(r, 'pickup_label'), style: _b(15, c: _ink, w: FontWeight.w800)),
              ]),
            ),
          ]),
        ),
        // Photo + details
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 24, 48, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('بيانات الزبون والعدّة', style: _h(15, w: FontWeight.w700)),
                const SizedBox(height: 10),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
                  child: Column(children: [
                    for (var i = 0; i < rows.length; i++)
                      Container(
                        decoration: BoxDecoration(border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: Color(0xFFEFEDE8)))),
                        child: IntrinsicHeight(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Container(width: 132, color: _soft, padding: const EdgeInsets.fromLTRB(16, 11, 16, 11), child: Text(rows[i].$1, style: _b(13, c: const Color(0xFF4A4F57), w: FontWeight.w600))),
                            Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(16, 11, 16, 11), child: Text(rows[i].$2.isEmpty ? '—' : rows[i].$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: _b(14, w: FontWeight.w600)))),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(width: 18),
            // Intake photo, framed
            SizedBox(
              width: 220,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('صورة العدّة عند الاستلام', style: _h(15, w: FontWeight.w700)),
                const SizedBox(height: 10),
                Container(
                  width: 220,
                  height: 262,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _line),
                    boxShadow: [BoxShadow(color: _ink.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: photo != null
                        ? Stack(fit: StackFit.expand, children: [
                            Image.memory(photo!, fit: BoxFit.cover),
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: _ink.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(8)),
                                child: Text(code, textDirection: TextDirection.ltr, style: _h(10.5, c: _amber, w: FontWeight.w700)),
                              ),
                            ),
                          ])
                        : Container(
                            color: _soft,
                            alignment: Alignment.center,
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.photo_camera_outlined, size: 34, color: _muted),
                              const SizedBox(height: 6),
                              Text('لا توجد صورة', style: _b(12, c: _muted)),
                            ]),
                          ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
        if (_s(r, 'description').isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 20, 48, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('وصف العطل', style: _h(15, w: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(16)),
                child: Text(_s(r, 'description'), maxLines: 4, overflow: TextOverflow.ellipsis, style: _b(14, c: const Color(0xFF2B2F36))),
              ),
            ]),
          ),
        const Spacer(),
        // QR + instructions
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 0, 48, 22),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
              child: QrImageView(
                data: trackUrl(site, code),
                size: 104,
                padding: EdgeInsets.zero,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _ink),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: _ink),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('امسح الرمز لتتبّع حالة عدّتك', style: _h(15, w: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('أو افتح تطبيق كوفيكس أو coofix.sy/repair وأدخل رقم الطلب أو رقم هاتفك.', style: _b(13, c: const Color(0xFF4A4F57))),
                Text('يرجى إحضار هذا الإيصال عند الاستلام.', style: _b(13, c: const Color(0xFF4A4F57))),
              ]),
            ),
          ]),
        ),
        Container(
          color: _ink,
          padding: const EdgeInsets.fromLTRB(48, 14, 48, 14),
          child: Row(children: [
            Text('استلمها الموظف: ${_s(r, 'created_by').isEmpty ? '—' : _s(r, 'created_by')}', style: _b(13, c: Colors.white, w: FontWeight.w600)),
            const SizedBox(width: 10),
            Text(_s(r, 'created_label'), textDirection: TextDirection.ltr, style: _b(12.5, c: Colors.white.withValues(alpha: 0.6))),
            const Spacer(),
            Text('coofix.sy', textDirection: TextDirection.ltr, style: _b(12.5, c: Colors.white.withValues(alpha: 0.7))),
          ]),
        ),
      ]),
    );
  }
}

/// WhatsApp status card (1080×1350).
class StatusDoc extends StatelessWidget {
  final Map<String, dynamic> r;
  final String note;
  const StatusDoc({super.key, required this.r, this.note = ''});

  static const stages = [
    ('received', 'تم الاستلام', Color(0xFF7FB2FF)),
    ('diagnosing', 'قيد الفحص', Color(0xFFC4A6FF)),
    ('repairing', 'قيد الإصلاح', Color(0xFFFFC14F)),
    ('ready', 'جاهزة للاستلام', Color(0xFF6FE3A1)),
    ('delivered', 'تم التسليم', Color(0xFF5FD3C4)),
  ];

  @override
  Widget build(BuildContext context) {
    var st = _s(r, 'status');
    if (st == 'waiting_parts') st = 'repairing';
    final idx = stages.indexWhere((s) => s.$1 == st);
    final color = idx >= 0 ? stages[idx].$3 : const Color(0xFFFF8A7D);
    Widget cell(String k, String v, [String sub = '']) => Expanded(
          child: Container(
            height: 172,
            padding: const EdgeInsets.fromLTRB(30, 22, 30, 18),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k, style: _b(22, c: Colors.white.withValues(alpha: 0.55))),
              const SizedBox(height: 4),
              Text(v.isEmpty ? '—' : v, maxLines: 1, overflow: TextOverflow.ellipsis, style: _b(30, c: Colors.white, w: FontWeight.w700)),
              if (sub.isNotEmpty) Text(sub, textDirection: TextDirection.ltr, style: _h(22, c: _amber2, w: FontWeight.w700)),
            ]),
          ),
        );
    return Container(
      width: 1080,
      height: 1350,
      color: _ink,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _Hex())),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 72, 72, 56),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFF0F3041), borderRadius: BorderRadius.circular(28), border: Border.all(color: _amber.withValues(alpha: 0.5), width: 2)),
                child: Image.asset('assets/img/icon.png'),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('صيانة كوفيكس', style: _h(40, c: Colors.white)),
                  Text('مركز الصيانة المعتمد', style: _b(24, c: Colors.white.withValues(alpha: 0.6))),
                ]),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(26, 12, 26, 12),
                decoration: BoxDecoration(color: _amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(22), border: Border.all(color: _amber.withValues(alpha: 0.4), width: 2)),
                child: Text(_s(r, 'code'), textDirection: TextDirection.ltr, style: _h(30, c: _amber).copyWith(letterSpacing: 2)),
              ),
            ]),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.fromLTRB(56, 44, 56, 44),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(44)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('حالة عدّتك الآن', style: _b(28, c: _ink.withValues(alpha: 0.75), w: FontWeight.w600)),
                Text(_s(r, 'status_label'), style: _h(80, c: _ink)),
                const SizedBox(height: 10),
                if (note.isNotEmpty) Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: _b(28, c: _ink.withValues(alpha: 0.85))),
              ]),
            ),
            const SizedBox(height: 44),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (var i = 0; i < stages.length; i++)
                SizedBox(
                  width: 170,
                  child: Column(children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: idx >= 0 && i <= idx ? _amber : Colors.transparent,
                        border: Border.all(color: idx >= 0 && i <= idx ? _amber : Colors.white.withValues(alpha: 0.25), width: 3),
                      ),
                      child: idx >= 0 && i <= idx ? const Icon(Icons.check_rounded, color: _ink, size: 32) : Text('${i + 1}', style: _h(26, c: Colors.white.withValues(alpha: 0.5))),
                    ),
                    const SizedBox(height: 14),
                    Text(stages[i].$2, textAlign: TextAlign.center, style: _b(22, c: idx >= 0 && i <= idx ? Colors.white : Colors.white.withValues(alpha: 0.45), w: FontWeight.w700)),
                  ]),
                ),
            ]),
            const SizedBox(height: 44),
            Row(children: [cell('كود العدّة', _s(r, 'product_code'), _s(r, 'serial')), const SizedBox(width: 18), cell('التسليم المتوقع', _s(r, 'pickup_label'))]),
            const SizedBox(height: 18),
            Row(children: [
              cell('الكفالة', r['warranty'] == true ? 'ضمن الكفالة' : 'خارج الكفالة'),
              const SizedBox(width: 18),
              cell('التكلفة', _s(r, 'cost')),
            ]),
            const Spacer(),
            if (_s(r, 'created_by').isNotEmpty) Text('استلمها الموظف: ${_s(r, 'created_by')}', style: _b(24, c: Colors.white.withValues(alpha: 0.6))),
            const SizedBox(height: 24),
            Container(height: 1.5, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 26),
            Row(children: [
              Text('تابع حالة عدّتك من تطبيق كوفيكس أو الموقع', style: _b(24, c: Colors.white.withValues(alpha: 0.6))),
              const Spacer(),
              Text('coofix.sy', textDirection: TextDirection.ltr, style: _b(24, c: Colors.white, w: FontWeight.w600)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Hex extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _amber.withValues(alpha: 0.06);
    const r = 48.0;
    const w = 84.0, hh = 73.0;
    for (var row = -1; row * hh < size.height + r; row++) {
      for (var col = -1; col * w < size.width + w; col++) {
        final cx = col * w + (row.isOdd ? w / 2 : 0), cy = row * hh;
        final path = Path();
        for (var i = 0; i < 6; i++) {
          final a = 3.1415926 / 180 * (60 * i - 30);
          final x = cx + r * _cos(a), y = cy + r * _sin(a);
          i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
        }
        path.close();
        canvas.drawPath(path, p);
      }
    }
  }

  double _cos(double a) => math.cos(a);
  double _sin(double a) => math.sin(a);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
