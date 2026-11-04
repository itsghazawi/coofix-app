import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'data.dart';
import 'kiosk.dart';
import 'theme.dart';

void snack(BuildContext c, String m, {bool error = false}) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(
    SnackBar(
      backgroundColor: error ? danger : ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Text(
        m,
        style: b(14, c: Colors.white, w: FontWeight.w500),
      ),
    ),
  );

String fmtDate(DateTime? d) {
  if (d == null) return '—';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}/${two(d.month)}/${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
}

// ================================================================ admin idle guard
/// Leaves the control panel automatically after 5 minutes without touches,
/// so a forgotten open panel goes back to the customer screen.
class AdminGuard {
  static Timer? _t;
  static bool active = false;
  static void touch() {
    if (!active) return;
    _t?.cancel();
    _t = Timer(const Duration(minutes: 5), () {
      if (active) enterKiosk();
    });
  }

  static void start() {
    active = true;
    touch();
  }

  static void stop() {
    active = false;
    _t?.cancel();
  }
}

// ================================================================ admin home
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  @override
  void initState() {
    super.initState();
    Device.keepAwake(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    AdminGuard.start();
  }

  @override
  void dispose() {
    AdminGuard.stop();
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  void _logout() => navKey.currentState?.pushAndRemoveUntil(fadeRoute(const StartScreen()), (_) => false);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final cols = w > 1000
        ? 4
        : w > 640
        ? 3
        : 2;
    final pad = MediaQuery.paddingOf(context);
    final tiles = [
      _Tile(Icons.inventory_2_rounded, 'المنتجات', 'عرض وبحث بالاسم أو الباركود', () => _open(const ProductsScreen())),
      _Tile(Icons.insights_rounded, 'الإحصائيات', 'الأكثر كشفاً والباركودات المفقودة', () => _open(const StatsScreen())),
      _Tile(Icons.tune_rounded, 'الإعدادات', 'النصوص، المدة، الصوت، الكاميرا', () => _open(const SettingsScreen())),
      _Tile(Icons.ios_share_rounded, 'نسخة احتياطية', 'تصدير المنتجات كملف CSV', () => exportProducts(context)),
      _Tile(Icons.lock_person_rounded, 'الحساب', 'تغيير اسم المستخدم وكلمة المرور', () => changeAccount(context)),
      _Tile(Icons.logout_rounded, 'خروج', 'العودة لشاشة البداية', _logout),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) {
        if (!did) _logout();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: bg,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, pad.top + 16, 20, 26),
                  decoration: const BoxDecoration(
                    gradient: darkBgGrad,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                  ),
                  child: Stack(
                    children: [
                      const Positioned.fill(child: CustomPaint(painter: HexPainter(opacity: 0.07))),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/img/app_icon.png', width: 52, height: 52)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('لوحة التحكم', style: h(22, c: Colors.white)),
                                        Text(
                                          'كاشف الأسعار · كوفيكس',
                                          style: b(13.5, c: amber.withValues(alpha: 0.9), w: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'خروج',
                                    onPressed: _logout,
                                    style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.08)),
                                    icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  Expanded(child: _Stat('المنتجات', '${Db.count}', Icons.inventory_2_rounded)),
                                  const SizedBox(width: 10),
                                  Expanded(child: _Stat('كشوفات اليوم', '${Stats.today}', Icons.qr_code_scanner_rounded)),
                                  const SizedBox(width: 10),
                                  Expanded(child: _Stat('غير موجود', '${Stats.misses}', Icons.search_off_rounded)),
                                ],
                              ),
                              const SizedBox(height: 18),
                              AmberButton(label: 'فتح كاشف الأسعار', icon: Icons.qr_code_scanner_rounded, height: 60, fontSize: 18, glow: 0.2, onTap: enterKiosk),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                      child: _ImportCard(onDone: () => setState(() {})),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, pad.bottom + 24),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: cols == 2 ? 1.12 : 1.45,
                        children: tiles,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _Stat(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: amber, size: 20),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: h(24, c: Colors.white, w: FontWeight.w800, height: 1.1),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: b(12, c: Colors.white.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  const _Tile(this.icon, this.title, this.sub, this.onTap);
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(gradient: inkGrad, borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: amber, size: 23),
              ),
              const Spacer(),
              Text(title, style: h(16.5)),
              const SizedBox(height: 2),
              Text(
                sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: b(12.5, c: muted, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================ import
class _ImportCard extends StatefulWidget {
  final VoidCallback onDone;
  const _ImportCard({required this.onDone});
  @override
  State<_ImportCard> createState() => _ImportCardState();
}

class _ImportCardState extends State<_ImportCard> {
  bool busy = false;

  Future<void> _pick() async {
    setState(() => busy = true);
    try {
      final f = await FilePicker.pickFile(type: FileType.any, dialogTitle: 'اختر ملف المنتجات');
      AdminGuard.touch();
      if (f == null) return;
      final lower = f.name.toLowerCase();
      if (!(lower.endsWith('.csv') || lower.endsWith('.txt') || lower.endsWith('.xlsx') || lower.endsWith('.xls') || lower.endsWith('.tsv'))) {
        if (mounted) snack(context, 'اختر ملف CSV أو Excel (xlsx)', error: true);
        return;
      }
      final bytes = await f.xFile.readAsBytes();
      final res = importFile(f.name, bytes);
      if (!mounted) return;
      if (res.products.isEmpty) {
        snack(context, 'ما لقيت منتجات بالملف. تأكد الترتيب: الاسم، السعر، الباركود', error: true);
        return;
      }
      final mode = await showModalBottomSheet<(bool, bool)>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ImportPreview(name: f.name, r: res),
      );
      if (mode == null || !mounted) return;
      final (replace, addNew) = mode;
      final (added, updated) = await Db.apply(res.products, replace: replace, addNew: addNew, fileName: f.name);
      if (!mounted) return;
      widget.onDone();
      snack(
        context,
        replace
            ? 'تم تحميل ${Db.count} منتج ✓'
            : addNew
            ? 'تم تحديث $updated سعر وإضافة $added منتج جديد ✓'
            : 'تم تحديث $updated سعر ✓ (بدون إضافة منتجات جديدة)',
      );
    } catch (e) {
      if (mounted) snack(context, e is String ? e : 'تعذّرت قراءة الملف', error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: amber.withValues(alpha: 0.45), width: 1.4),
        boxShadow: [BoxShadow(color: amber.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(gradient: amberGrad, borderRadius: BorderRadius.circular(17)),
                child: const Icon(Icons.upload_file_rounded, color: ink, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('رفع ملف المنتجات', style: h(18)),
                    Text('CSV أو Excel · لتحميل المنتجات أو تحديث الأسعار', style: b(13, c: muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                for (final (i, t) in [(1, 'الاسم'), (2, 'السعر \$'), (3, 'الباركود')]) ...[
                  if (i > 1) const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: line),
                      ),
                      child: Column(
                        children: [
                          Text('عمود $i', style: b(11, c: muted)),
                          Text(t, style: h(14)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 16, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  Db.updatedAt == null ? 'لم يتم رفع أي ملف بعد' : 'آخر تحديث: ${fmtDate(Db.updatedAt)}${Db.lastFile != null ? ' · ${Db.lastFile}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: b(12.5, c: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: busy ? null : _pick,
              style: FilledButton.styleFrom(
                backgroundColor: ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              icon: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: amber)) : const Icon(Icons.folder_open_rounded, color: amber),
              label: Text(busy ? 'جاري القراءة…' : 'اختيار الملف', style: h(16, c: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportPreview extends StatefulWidget {
  final String name;
  final ImportResult r;
  const _ImportPreview({required this.name, required this.r});
  @override
  State<_ImportPreview> createState() => _ImportPreviewState();
}

class _ImportPreviewState extends State<_ImportPreview> {
  late final int fresh = Db.countNew(widget.r.products);
  late final int existing = widget.r.products.length - fresh;
  bool addNew = true;

  @override
  Widget build(BuildContext context) {
    final r = widget.r, name = widget.name;
    final sample = r.products.take(3).toList();
    final first = Db.count == 0;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9, maxWidth: 640),
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              Text('معاينة الملف', style: h(20)),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                style: b(13, c: muted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _mini('${r.products.length}', 'منتج جاهز', ok)),
                  const SizedBox(width: 8),
                  Expanded(child: _mini('${r.skipped}', 'سطر متجاوَز', r.skipped > 0 ? danger : muted)),
                  const SizedBox(width: 8),
                  Expanded(child: _mini('${r.duplicates}', 'باركود مكرر', r.duplicates > 0 ? amberDeep : muted)),
                ],
              ),
              if (r.problems.isNotEmpty || r.scientific > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: danger.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: danger.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final p in r.problems) Text('• $p', style: b(12.5, c: textC)),
                      if (r.scientific > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'تنبيه: الإكسل حوّل ${r.scientific} باركود لصيغة 6.29E+12. حدد عمود الباركود ← تنسيق الخلايا ← "نص" أو "رقم بدون فواصل عشرية" ثم احفظ من جديد.',
                            style: b(12.5, c: danger, w: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (r.duplicates > 0) ...[const SizedBox(height: 8), Text('الباركود المكرر: يُعتمد آخر سطر بالملف.', style: b(12.5, c: muted))],
              const SizedBox(height: 14),
              Text('عيّنة', style: h(14, c: muted)),
              const SizedBox(height: 6),
              for (final p in sample)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: h(14)),
                            Text(
                              p.barcode,
                              textDirection: TextDirection.ltr,
                              style: b(12, c: muted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        fmtPrice(p.price),
                        textDirection: TextDirection.ltr,
                        style: h(16, c: amberDeep),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (first)
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, (true, true)),
                    style: FilledButton.styleFrom(
                      backgroundColor: ink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    icon: const Icon(Icons.download_done_rounded, color: amber),
                    label: Text('تحميل ${r.products.length} منتج', style: h(16, c: Colors.white)),
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _pill('$existing', 'منتج موجود رح يتحدّث سعره', ok)),
                          const SizedBox(width: 8),
                          Expanded(child: _pill('$fresh', 'منتج جديد مو موجود بالقائمة', amberDeep)),
                        ],
                      ),
                      if (fresh > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: addNew ? amber.withValues(alpha: 0.10) : bg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: addNew ? amber.withValues(alpha: 0.5) : line),
                          ),
                          child: SwitchListTile(
                            value: addNew,
                            activeThumbColor: Colors.white,
                            activeTrackColor: amber,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text('إضافة المنتجات الجديدة', style: h(15)),
                            subtitle: Text(addNew ? 'مفعّل: رح ينضاف $fresh منتج جديد للقائمة' : 'مقفول: بس الأسعار بتتحدّث، والجديد ما بينضاف', style: b(12.5, c: muted)),
                            onChanged: (v) => setState(() => addNew = v),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pop(context, (false, addNew)),
                          style: FilledButton.styleFrom(
                            backgroundColor: ink,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          icon: const Icon(Icons.sync_rounded, color: amber),
                          label: Text('تحديث الأسعار', style: h(16, c: Colors.white)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'ما بينحذف أي منتج موجود.',
                          textAlign: TextAlign.center,
                          style: b(12.5, c: muted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, (true, true)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: amberDeep, width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded, color: amberDeep),
                    label: Text('استبدال كل المنتجات بالملف', style: h(15, c: amberDeep)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
                  child: Text(
                    'يمسح القائمة الحالية (${Db.count} منتج) ويعتمد الملف بس.',
                    textAlign: TextAlign.center,
                    style: b(12.5, c: muted),
                  ),
                ),
              ],
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: b(14, c: muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String v, String l, Color c) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
    child: Column(
      children: [
        Text(
          v,
          style: h(20, c: c, w: FontWeight.w800),
        ),
        Text(
          l,
          textAlign: TextAlign.center,
          style: b(11.5, c: muted, height: 1.3),
        ),
      ],
    ),
  );

  Widget _mini(String v, String l, Color c) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: line),
    ),
    child: Column(
      children: [
        Text(
          v,
          style: h(22, c: c, w: FontWeight.w800),
        ),
        Text(l, style: b(12, c: muted)),
      ],
    ),
  );
}

Future<void> exportProducts(BuildContext context) async {
  if (Db.count == 0) {
    snack(context, 'لا يوجد منتجات للتصدير', error: true);
    return;
  }
  try {
    final f = await Db.exportCsv();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(f.path, mimeType: 'text/csv')],
        text: 'منتجات كاشف الأسعار — كوفيكس',
      ),
    );
  } catch (_) {
    if (context.mounted) snack(context, 'تعذّر التصدير', error: true);
  }
}

// ================================================================ products
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final q = TextEditingController();
  List<Product> list = [];

  @override
  void initState() {
    super.initState();
    _filter();
  }

  void _filter() {
    final t = q.text.trim().toLowerCase();
    final all = Db.all..sort((a, b) => a.name.compareTo(b.name));
    setState(() => list = t.isEmpty ? all : all.where((p) => p.name.toLowerCase().contains(t) || p.barcode.contains(t)).toList());
  }

  Future<void> _scanSearch() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScannerScreen(pickOnly: true)));
    if (code == null || !mounted) return;
    final p = Db.find(code);
    q.text = p?.barcode ?? code;
    _filter();
    if (p == null) snack(context, 'هالباركود مو موجود بالقائمة: $code', error: true);
  }

  Future<void> _clearAll() async {
    final yes = await confirm(context, 'حذف كل المنتجات؟', 'رح ينحذف ${Db.count} منتج من الجهاز. الأفضل تعمل نسخة احتياطية قبل.', 'حذف الكل');
    if (!yes) return;
    await Db.clear();
    _filter();
    if (mounted) snack(context, 'تم حذف كل المنتجات');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        title: Text('المنتجات (${Db.count})', style: h(19)),
        actions: [
          IconButton(tooltip: 'مسح باركود', onPressed: _scanSearch, icon: const Icon(Icons.qr_code_scanner_rounded)),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'export') exportProducts(context);
              if (v == 'clear') _clearAll();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'export',
                child: Text('تصدير CSV', style: b(14)),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Text('حذف كل المنتجات', style: b(14, c: danger)),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: TextField(
                  controller: q,
                  onChanged: (_) {
                    AdminGuard.touch();
                    _filter();
                  },
                  style: b(15),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو الباركود',
                    hintStyle: b(15, c: muted),
                    prefixIcon: const Icon(Icons.search_rounded, color: muted),
                    suffixIcon: q.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              q.clear();
                              _filter();
                            },
                            icon: const Icon(Icons.close_rounded, color: muted),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: amber, width: 1.4),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 54, color: muted),
                            const SizedBox(height: 10),
                            Text(
                              Db.count == 0 ? 'لا يوجد منتجات بعد\nارفع ملف CSV من لوحة التحكم' : 'لا نتائج',
                              textAlign: TextAlign.center,
                              style: b(15, c: muted),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final p = list[i];
                          return Material(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: line),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: h(14.5, height: 1.35)),
                                        const SizedBox(height: 2),
                                        Text(
                                          p.barcode,
                                          textDirection: TextDirection.ltr,
                                          style: b(12.5, c: muted).copyWith(letterSpacing: 0.6),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(color: amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                                    child: Text(
                                      fmtPrice(p.price),
                                      textDirection: TextDirection.ltr,
                                      style: h(15, c: amberDeep, w: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, String title, String body, String yes) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: h(18)),
      content: Text(body, style: b(14.5, c: muted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('إلغاء', style: b(14, c: muted)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: danger),
          child: Text(yes, style: h(14, c: Colors.white)),
        ),
      ],
    ),
  );
  return r == true;
}

InputDecoration fieldDec(String label, {IconData? icon, Widget? suffix, String? hint}) => InputDecoration(
  labelText: label,
  hintText: hint,
  labelStyle: b(14, c: muted),
  prefixIcon: icon == null ? null : Icon(icon, color: amberDeep, size: 20),
  suffixIcon: suffix,
  filled: true,
  fillColor: Colors.white,
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: line),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: amber, width: 1.4),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: danger),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: danger, width: 1.4),
  ),
);

// ================================================================ stats
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  Widget build(BuildContext context) {
    final top = Stats.counts.entries.where((e) => Db.find(e.key) != null).toList()..sort((a, b) => b.value.compareTo(a.value));
    final missing = <String>{};
    for (final r in Stats.recent) {
      if (r['f'] != true && Db.find('${r['b']}') == null) missing.add('${r['b']}');
    }
    // last 7 days
    final now = DateTime.now();
    final week = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      final k = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return (d, Stats.days[k] ?? 0);
    });
    final maxDay = week.map((e) => e.$2).fold<int>(1, math.max);
    const dayNames = ['إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        title: Text('الإحصائيات', style: h(19)),
        actions: [
          TextButton(
            onPressed: () async {
              if (await confirm(context, 'تصفير الإحصائيات؟', 'رح ينمسح سجل الكشوفات كله.', 'تصفير')) {
                await Stats.reset();
                setState(() {});
              }
            },
            child: Text(
              'تصفير',
              style: b(14, c: danger, w: FontWeight.w500),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
            children: [
              Row(
                children: [
                  Expanded(child: _box('${Stats.total}', 'كل الكشوفات', Icons.all_inclusive_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _box('${Stats.today}', 'اليوم', Icons.today_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _box('${Stats.misses}', 'غير موجود', Icons.search_off_rounded)),
                ],
              ),
              const SizedBox(height: 16),
              _card(
                'آخر ٧ أيام',
                SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final (d, v) in week)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('$v', style: h(12, c: textC)),
                                const SizedBox(height: 4),
                                Container(
                                  height: 4 + 96 * v / maxDay,
                                  decoration: BoxDecoration(gradient: v == 0 ? null : amberGrad, color: v == 0 ? line : null, borderRadius: BorderRadius.circular(8)),
                                ),
                                const SizedBox(height: 6),
                                Text(dayNames[d.weekday - 1], style: b(11, c: muted)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _card(
                'الأكثر كشفاً',
                top.isEmpty
                    ? Text('لا يوجد بيانات بعد', style: b(14, c: muted))
                    : Column(
                        children: [
                          for (final (i, e) in top.take(10).indexed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(color: i < 3 ? amber : bg, borderRadius: BorderRadius.circular(9)),
                                    child: Text('${i + 1}', style: h(13, c: ink)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      Db.find(e.key)!.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: b(14, w: FontWeight.w500),
                                    ),
                                  ),
                                  Text('${e.value} مرة', style: h(13, c: amberDeep)),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              _card(
                'باركودات انكشفت وما إلها سعر',
                missing.isEmpty
                    ? Text('ممتاز، كل الكشوفات الأخيرة لقت سعر ✓', style: b(14, c: muted))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('هي القطع حاول الزبائن يكشفوا سعرها وما كانت بالقائمة، ضيفها لملف الإكسل بالتحديث الجاي.', style: b(12.5, c: muted)),
                          const SizedBox(height: 6),
                          for (final c in missing.take(30))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: const Icon(Icons.barcode_reader, color: muted),
                              title: Text(
                                c,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.right,
                                style: b(14.5, w: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box(String v, String l, IconData i) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(i, color: amberDeep, size: 20),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(v, style: h(24, w: FontWeight.w800)),
        ),
        Text(l, style: b(12, c: muted)),
      ],
    ),
  );

  Widget _card(String title, Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: h(16)),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

// ================================================================ settings
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _set(String k, Object v) async {
    AdminGuard.touch();
    await Settings.set(k, v);
    setState(() {});
  }

  Future<void> _text(String key, String title, String current) async {
    final c = TextEditingController(text: current);
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: h(18)),
        content: TextField(controller: c, autofocus: true, maxLines: 3, minLines: 1, style: b(15), decoration: fieldDec(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: b(14, c: muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: ink),
            child: Text('حفظ', style: h(14, c: Colors.white)),
          ),
        ],
      ),
    );
    if (r != null && r.isNotEmpty) await _set(key, r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        title: Text('الإعدادات', style: h(19)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              _section('نصوص شاشة الزبون', [
                _textRow('عنوان الترحيب', Settings.welcomeTitle, () => _text('welcome_title', 'عنوان الترحيب', Settings.welcomeTitle)),
                _textRow('النص تحت العنوان', Settings.welcomeSub, () => _text('welcome_sub', 'النص تحت العنوان', Settings.welcomeSub)),
                _textRow('نص الزر', Settings.buttonLabel, () => _text('button_label', 'نص الزر', Settings.buttonLabel)),
                _textRow('عنوان "غير موجود"', Settings.notFoundTitle, () => _text('nf_title', 'عنوان المنتج غير الموجود', Settings.notFoundTitle)),
                _textRow('رسالة "غير موجود"', Settings.notFoundSub, () => _text('nf_sub', 'رسالة المنتج غير الموجود', Settings.notFoundSub)),
              ]),
              _section('عرض السعر', [
                _slider('مدة عرض السعر', Settings.resultSeconds, 5, 60, 'result_seconds', 'ثانية'),
                _slider('إغلاق الكاميرا تلقائياً بعد', Settings.scanTimeout, 10, 90, 'scan_timeout', 'ثانية'),
                _switch('إظهار السنتات دائماً', '\$25.00 بدل \$25', Settings.alwaysCents, 'always_cents'),
                _switch('إظهار رقم الباركود', 'تحت السعر', Settings.showBarcode, 'show_barcode'),
              ]),
              _section('الصوت والكاميرا', [
                _switch('صوت القارئ (تيت)', 'عند قراءة الباركود', Settings.beep, 'beep'),
                _switch('اهتزاز', 'عند قراءة الباركود', Settings.vibrate, 'vibrate'),
                _switch('الكاميرا الأمامية', 'إذا التاب على ستاند ووجهه للزبون', Settings.frontCamera, 'front_camera'),
                _switch('قارئ باركود خارجي', 'بلوتوث أو USB — يقرأ مباشرة من الشاشة الرئيسية', Settings.hwScanner, 'hw_scanner'),
              ]),
              _section('الشاشة', [
                _switch('إبقاء الشاشة مضاءة', 'أثناء عمل كاشف الأسعار', Settings.keepAwake, 'keep_awake'),
              ]),
              _section('الحساب', [
                ListTile(
                  leading: const Icon(Icons.lock_person_rounded, color: amberDeep),
                  title: Text('تغيير اسم المستخدم وكلمة المرور', style: b(15, w: FontWeight.w500)),
                  subtitle: Text('الحالي: ${Settings.adminUser}', style: b(12.5, c: muted)),
                  trailing: const Icon(Icons.chevron_left_rounded, color: muted),
                  onTap: () => changeAccount(context),
                ),
              ]),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  if (!await confirm(context, 'استعادة الإعدادات الافتراضية؟', 'النصوص والمدد والصوت والكاميرا ترجع متل ما كانت. المنتجات والحساب ما بيتأثروا.', 'استعادة')) return;
                  await Settings.reset([
                    'welcome_title',
                    'welcome_sub',
                    'button_label',
                    'nf_title',
                    'nf_sub',
                    'result_seconds',
                    'scan_timeout',
                    'beep',
                    'vibrate',
                    'front_camera',
                    'keep_awake',
                    'hw_scanner',
                    'show_barcode',
                    'always_cents',
                  ]);
                  setState(() {});
                },
                icon: const Icon(Icons.restart_alt_rounded, color: muted),
                label: Text('استعادة الإعدادات الافتراضية', style: b(14, c: muted)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('كاشف الأسعار · كوفيكس سوريا · الإصدار 1.0.1', style: b(12, c: muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          child: Text(title, style: h(14, c: amberDeep)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(height: 1, color: line, indent: 16, endIndent: 16), children[i]],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _textRow(String label, String value, VoidCallback onTap) => ListTile(
    title: Text(label, style: b(13, c: muted)),
    subtitle: Text(
      value,
      style: b(15, c: textC, w: FontWeight.w500),
    ),
    trailing: const Icon(Icons.edit_rounded, color: muted, size: 20),
    onTap: onTap,
  );

  Widget _switch(String title, String sub, bool v, String key) => SwitchListTile(
    value: v,
    activeThumbColor: Colors.white,
    activeTrackColor: amber,
    title: Text(title, style: b(15, w: FontWeight.w500)),
    subtitle: Text(sub, style: b(12.5, c: muted)),
    onChanged: (x) => _set(key, x),
  );

  Widget _slider(String title, int v, int min, int max, String key, String unit) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: b(15, w: FontWeight.w500)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: amber.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
              child: Text('$v $unit', style: h(13, c: amberDeep)),
            ),
          ],
        ),
        Slider(
          value: v.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          activeColor: amber,
          inactiveColor: line,
          onChanged: (x) {
            Settings.set(key, x.round());
            setState(() {});
          },
          onChangeEnd: (_) => AdminGuard.touch(),
        ),
      ],
    ),
  );
}

Future<void> changeAccount(BuildContext context) async {
  final u = TextEditingController(text: Settings.adminUser);
  final p1 = TextEditingController(), p2 = TextEditingController(), old = TextEditingController();
  String? err;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('حساب لوحة التحكم', style: h(18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: old,
                obscureText: true,
                textDirection: TextDirection.ltr,
                style: b(15),
                decoration: fieldDec('كلمة المرور الحالية', icon: Icons.lock_clock_rounded),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: u,
                textDirection: TextDirection.ltr,
                style: b(15),
                decoration: fieldDec('اسم المستخدم الجديد', icon: Icons.person_rounded),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: p1,
                obscureText: true,
                textDirection: TextDirection.ltr,
                style: b(15),
                decoration: fieldDec('كلمة المرور الجديدة', icon: Icons.lock_rounded),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: p2,
                obscureText: true,
                textDirection: TextDirection.ltr,
                style: b(15),
                decoration: fieldDec('تأكيد كلمة المرور', icon: Icons.lock_rounded),
              ),
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    err!,
                    style: b(13, c: danger, w: FontWeight.w500),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: b(14, c: muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ink),
            onPressed: () async {
              if (old.text != Settings.adminPass) return set(() => err = 'كلمة المرور الحالية غير صحيحة');
              if (u.text.trim().length < 3) return set(() => err = 'اسم المستخدم قصير');
              if (p1.text.length < 4) return set(() => err = 'كلمة المرور لازم تكون 4 أحرف أو أكثر');
              if (p1.text != p2.text) return set(() => err = 'كلمتا المرور غير متطابقتين');
              await Settings.setAdmin(u.text.trim(), p1.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) snack(context, 'تم تغيير بيانات الدخول ✓');
            },
            child: Text('حفظ', style: h(14, c: Colors.white)),
          ),
        ],
      ),
    ),
  );
}
