import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'key.dart';

// ---------------------------------------------------------------- theme
const ink = Color(0xFF061922);
const inkLight = Color(0xFF0F3041);
const amber = Color(0xFFFAA21B);
const amber2 = Color(0xFFFFC14F);
const amberDeep = Color(0xFFE08A00);
const bg = Color(0xFFF4F3F0);
const line = Color(0xFFE6E3DD);
const muted = Color(0xFF8A8F98);
const textC = Color(0xFF15181D);
const green = Color(0xFF25D366);
const amberGrad = LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [amber2, amber, amberDeep]);
const inkGrad = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [inkLight, ink]);

TextStyle h(double s, {Color c = textC, FontWeight w = FontWeight.w700}) =>
    TextStyle(fontFamily: 'Alexandria', fontSize: s, color: c, fontWeight: w, height: 1.3, fontVariations: [FontVariation('wght', w.value.toDouble())]);
TextStyle b(double s, {Color c = textC, FontWeight w = FontWeight.w400, double height = 1.5}) =>
    TextStyle(fontFamily: 'Plex', fontSize: s, color: c, fontWeight: w, height: height);

// ---------------------------------------------------------------- api
class Api {
  static String site = 'https://www.coofix.sy';
  static String key = kDefaultKey;
  static String staff = '';

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    site = p.getString('site') ?? site;
    key = p.getString('key') ?? key;
    staff = p.getString('staff') ?? '';
  }

  static Future<void> save({String? s, String? k, String? st}) async {
    final p = await SharedPreferences.getInstance();
    if (s != null) await p.setString('site', site = s.trim().replaceAll(RegExp(r'/+$'), ''));
    if (k != null) await p.setString('key', key = k.trim());
    if (st != null) await p.setString('staff', staff = st.trim());
  }

  static Uri u(String path, [Map<String, String>? q]) => Uri.parse('$site/wp-json/coofix-app/v1$path').replace(queryParameters: q);
  static Map<String, String> get headers => {'X-Coofix-Key': key};

  static Future<Map<String, dynamic>> info() async {
    final r = await http.get(u('/staff/info'), headers: headers).timeout(const Duration(seconds: 15));
    if (r.statusCode == 401) throw 'مفتاح البرنامج غير صالح — راجع الإعدادات';
    if (r.statusCode == 404) throw 'إضافة كوفيكس غير مثبتة أو غير محدّثة على الموقع';
    if (r.statusCode != 200) throw 'خطأ في الاتصال (${r.statusCode})';
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> list({String q = ''}) async {
    final r = await http.get(u('/staff/repairs', {if (q.isNotEmpty) 'q': q}), headers: headers).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw 'تعذّر تحميل الطلبات (${r.statusCode})';
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return (j['items'] as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<Map<String, dynamic>> create(Map<String, String> fields, List<File> photos, File? warrantyPhoto) async {
    final req = http.MultipartRequest('POST', u('/staff/repairs'))
      ..headers.addAll(headers)
      ..fields.addAll(fields);
    for (var i = 0; i < photos.length; i++) {
      req.files.add(await http.MultipartFile.fromPath('photo_$i', photos[i].path));
    }
    if (warrantyPhoto != null) req.files.add(await http.MultipartFile.fromPath('warranty_card', warrantyPhoto.path));
    final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 120)));
    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode != 201) {
      String msg = 'تعذّر الحفظ (${res.statusCode})';
      try {
        msg = (jsonDecode(body) as Map)['message']?.toString() ?? msg;
      } catch (_) {}
      throw msg;
    }
    return (jsonDecode(body) as Map).cast<String, dynamic>();
  }
}

String waNumber(String phone) {
  var n = phone.replaceAll(RegExp(r'\D'), '');
  if (n.startsWith('00')) n = n.substring(2);
  if (n.startsWith('0')) n = '963${n.substring(1)}';
  if (n.length == 9) n = '963$n';
  return n;
}

Future<void> openWa(String phone, String text) =>
    launchUrl(Uri.parse('https://wa.me/${waNumber(phone)}?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);

Color statusColor(String s) => switch (s) {
      'received' => const Color(0xFF2563EB),
      'diagnosing' => const Color(0xFF7C3AED),
      'waiting_parts' => const Color(0xFFD97706),
      'repairing' => const Color(0xFFEA580C),
      'ready' => const Color(0xFF16A34A),
      'delivered' => const Color(0xFF0F766E),
      'cancelled' => const Color(0xFFDC2626),
      _ => muted,
    };

// ---------------------------------------------------------------- app
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Api.load();
  runApp(const ServiceApp());
}

class ServiceApp extends StatelessWidget {
  const ServiceApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'صيانة كوفيكس',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Plex',
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: amber, primary: amberDeep, surface: bg),
        snackBarTheme: SnackBarThemeData(backgroundColor: ink, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ),
      home: const HomeScreen(),
    );
  }
}

void snack(BuildContext c, String m) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m, style: b(14, c: Colors.white, w: FontWeight.w500))));

// ---------------------------------------------------------------- home
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? info;
  List<Map<String, dynamic>> items = [];
  String? error;
  bool loading = true;
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    if (Api.staff.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _askName());
  }

  Future<void> _askName() async {
    final c = TextEditingController();
    final n = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('اسم الموظف', style: h(18)),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'يظهر في سجل كل طلب')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('حفظ'))],
      ),
    );
    if (n != null && n.trim().isNotEmpty) await Api.save(st: n);
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await Future.wait([Api.info(), Api.list(q: search.text.trim())]);
      info = r[0] as Map<String, dynamic>;
      items = r[1] as List<Map<String, dynamic>>;
    } catch (e) {
      error = e is String ? e : 'تعذّر الاتصال بالموقع، تحقق من الإنترنت';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: amber,
        foregroundColor: ink,
        onPressed: () async {
          final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => NewRepairScreen(info: info)));
          if (done == true) _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: Text('استلام جديد', style: h(15, c: ink)),
      ),
      body: RefreshIndicator(
        color: amberDeep,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(20, top + 16, 20, 22),
                decoration: const BoxDecoration(gradient: inkGrad, borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset('assets/img/icon.png', width: 48, height: 48)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('صيانة كوفيكس', style: h(20, c: Colors.white)),
                        Text(Api.staff.isEmpty ? 'برنامج الاستلام' : 'الموظف: ${Api.staff}', style: b(12.5, c: Colors.white.withValues(alpha: 0.6))),
                      ]),
                    ),
                    IconButton(
                      onPressed: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                        setState(() {});
                        _load();
                      },
                      icon: const Icon(Icons.settings_rounded, color: Colors.white70),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(18)),
                    child: Row(children: [
                      const Icon(Icons.event_rounded, color: amber),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('موعد الصيانة القادم', style: b(12, c: Colors.white.withValues(alpha: 0.6))),
                          Text(info?['next_label']?.toString() ?? '—', style: h(16, c: Colors.white)),
                          if ((info?['pickup_label'] ?? '').toString().isNotEmpty)
                            Text('التسليم: ${info!['pickup_label']}', style: b(12, c: amber2, w: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(),
                    style: b(15, w: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'بحث بالكود أو الاسم أو الهاتف',
                      hintStyle: b(14, c: muted),
                      prefixIcon: const Icon(Icons.search_rounded, color: muted),
                      suffixIcon: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _load),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ]),
              ),
            ),
            if (loading)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(color: amberDeep)))
            else if (error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.wifi_off_rounded, size: 46, color: muted),
                      const SizedBox(height: 12),
                      Text(error!, textAlign: TextAlign.center, style: b(14.5, c: muted)),
                      TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                    ]),
                  ),
                ),
              )
            else if (items.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('لا توجد طلبات بعد', style: b(15, c: muted))))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (c, i) => _RepairTile(items[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RepairTile extends StatelessWidget {
  final Map<String, dynamic> r;
  const _RepairTile(this.r);
  @override
  Widget build(BuildContext context) {
    final st = '${r['status']}';
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RepairDetail(r))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: statusColor(st).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.build_rounded, color: statusColor(st)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${r['code']}', textDirection: TextDirection.ltr, style: h(14.5)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(color: statusColor(st), borderRadius: BorderRadius.circular(20)),
                  child: Text('${r['status_label']}', style: b(11.5, c: Colors.white, w: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 2),
              Text('${r['name']} • ${r['phone']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: b(13.5, w: FontWeight.w600)),
              Text('${r['product_code']}${(r['serial'] ?? '').toString().isNotEmpty ? ' • S/N ${r['serial']}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: b(12, c: muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- detail
class RepairDetail extends StatelessWidget {
  final Map<String, dynamic> r;
  const RepairDetail(this.r, {super.key});
  @override
  Widget build(BuildContext context) {
    final photos = (r['photo_urls'] as List? ?? []).map((e) => '$e').toList();
    final tl = (r['timeline'] as List? ?? []).whereType<Map>().toList().reversed.toList();
    Widget row(String k, String v) => v.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 120, child: Text(k, style: b(13.5, c: muted))),
              Expanded(child: Text(v, style: b(14, w: FontWeight.w600))),
            ]),
          );
    return Scaffold(
      appBar: AppBar(title: Text('${r['code']}', style: h(18)), backgroundColor: bg),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: line)),
          child: Column(children: [
            row('الحالة', '${r['status_label']}'),
            row('الزبون', '${r['name']}'),
            row('الهاتف', '${r['phone']}'),
            row('كود المنتج', '${r['product_code'] ?? ''}'),
            row('الرقم التسلسلي', '${r['serial'] ?? ''}'),
            row('الملحقات', r['accessories'] == true ? 'نعم ${r['accessories_text'] ?? ''}' : 'لا'),
            row('الكفالة', r['warranty'] == true ? 'ضمن الكفالة' : 'خارج الكفالة'),
            row('تاريخ الشراء', '${r['purchase_date'] ?? ''}'),
            row('موعد الصيانة', '${r['scheduled_label'] ?? ''}'),
            row('التسليم', '${r['pickup_label'] ?? ''}'),
            row('التكلفة', '${r['cost'] ?? ''}'),
            row('ما تم', '${r['work_done'] ?? ''}'),
            row('الوصف', '${r['description'] ?? ''}'),
            row('الاستلام', '${r['created_label'] ?? ''} ${r['created_by'] ?? ''}'),
          ]),
        ),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(photos[i], width: 110, height: 110, fit: BoxFit.cover)),
            ),
          ),
        ],
        if (tl.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('سجل التتبع', style: h(16)),
          const SizedBox(height: 8),
          for (final t in tl)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 6, backgroundColor: statusColor('${t['status']}')),
              title: Text(statusLabel('${t['status']}'), style: b(14, w: FontWeight.w700)),
              subtitle: Text('${t['note'] ?? ''}', style: b(13, c: muted)),
            ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: green, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: () => openWa('${r['phone']}', 'مرحباً ${r['name']} 👋\nطلب الصيانة رقم ${r['code']}\nالحالة: ${r['status_label']}\nكوفيكس سوريا'),
          icon: const Icon(Icons.chat_rounded),
          label: Text('مراسلة الزبون', style: h(15, c: Colors.white)),
        ),
        const SizedBox(height: 8),
        Text('تعديل الحالة والتكلفة يتم من لوحة ووردبريس ← الصيانة.', textAlign: TextAlign.center, style: b(12, c: muted)),
      ]),
    );
  }
}

String statusLabel(String s) => const {
      'received': 'تم الاستلام',
      'diagnosing': 'قيد الفحص',
      'waiting_parts': 'بانتظار القطع',
      'repairing': 'قيد الإصلاح',
      'ready': 'جاهزة للاستلام',
      'delivered': 'تم التسليم',
      'cancelled': 'ملغاة',
    }[s] ??
    s;

// ---------------------------------------------------------------- new repair
class NewRepairScreen extends StatefulWidget {
  final Map<String, dynamic>? info;
  const NewRepairScreen({super.key, this.info});
  @override
  State<NewRepairScreen> createState() => _NewRepairScreenState();
}

class _NewRepairScreenState extends State<NewRepairScreen> {
  final phone = TextEditingController();
  final name = TextEditingController();
  final product = TextEditingController();
  final serial = TextEditingController();
  final desc = TextEditingController();
  final accText = TextEditingController();
  bool accessories = false;
  bool warranty = false;
  DateTime? purchase;
  final photos = <File>[];
  File? warrantyPhoto;
  bool saving = false;
  final picker = ImagePicker();

  Future<File?> _pick(ImageSource src) async {
    final x = await picker.pickImage(source: src, imageQuality: 72, maxWidth: 1800);
    return x == null ? null : File(x.path);
  }

  Future<void> _addPhoto() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_rounded), title: const Text('التقاط صورة'), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('من المعرض'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
        ]),
      ),
    );
    if (src == null) return;
    final f = await _pick(src);
    if (f != null) setState(() => photos.add(f));
  }

  Future<void> _submit() async {
    if (name.text.trim().isEmpty || phone.text.replaceAll(RegExp(r'\D'), '').length < 7) {
      snack(context, 'اسم الزبون ورقم الهاتف مطلوبان');
      return;
    }
    setState(() => saving = true);
    try {
      final r = await Api.create({
        'phone': phone.text.trim(),
        'name': name.text.trim(),
        'product_code': product.text.trim(),
        'serial': serial.text.trim(),
        'description': desc.text.trim(),
        'accessories': accessories ? '1' : '0',
        'accessories_text': accessories ? accText.text.trim() : '',
        'warranty': warranty ? '1' : '0',
        'purchase_date': purchase == null ? '' : purchase!.toIso8601String().substring(0, 10),
        'staff': Api.staff,
      }, photos, warranty ? warrantyPhoto : null);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => DoneScreen(r)));
    } catch (e) {
      if (mounted) snack(context, e is String ? e : 'تعذّر الحفظ، تحقق من الإنترنت');
    }
    if (mounted) setState(() => saving = false);
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: b(14, c: muted),
        prefixIcon: Icon(icon, color: muted),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: amber, width: 1.5)),
      );

  Widget _section(String t, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t, style: h(15.5)),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(title: Text('استلام عدّة للصيانة', style: h(18)), backgroundColor: bg),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 120), children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(gradient: inkGrad, borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            const Icon(Icons.event_available_rounded, color: amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'الحالة: تم الاستلام • الصيانة ${widget.info?['next_label'] ?? 'يوم الأربعاء القادم'}${(widget.info?['pickup_label'] ?? '').toString().isNotEmpty ? '\nالتسليم ${widget.info!['pickup_label']}' : ''}',
                style: b(13, c: Colors.white, w: FontWeight.w600),
              ),
            ),
          ]),
        ),
        _section('الزبون', [
          TextField(controller: phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: _dec('رقم الزبون *', Icons.phone_rounded)),
          gap,
          TextField(controller: name, textInputAction: TextInputAction.next, decoration: _dec('اسم الزبون *', Icons.person_rounded)),
        ]),
        _section('العدّة', [
          TextField(controller: product, textDirection: TextDirection.ltr, decoration: _dec('كود المنتج', Icons.qr_code_rounded)),
          gap,
          TextField(controller: serial, textDirection: TextDirection.ltr, decoration: _dec('الرقم التسلسلي (Serial)', Icons.numbers_rounded)),
          gap,
          TextField(controller: desc, maxLines: 3, decoration: _dec('وصف المشكلة', Icons.notes_rounded)),
          gap,
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: amberDeep,
            title: Text('مع ملحقات', style: b(14.5, w: FontWeight.w600)),
            subtitle: Text('شاحن، بطارية، حقيبة…', style: b(12, c: muted)),
            value: accessories,
            onChanged: (v) => setState(() => accessories = v),
          ),
          if (accessories) TextField(controller: accText, decoration: _dec('ما هي الملحقات؟', Icons.inventory_2_rounded)),
        ]),
        _section('الكفالة', [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: amberDeep,
            title: Text(warranty ? 'ضمن الكفالة' : 'خارج الكفالة', style: b(14.5, w: FontWeight.w600)),
            subtitle: Text('حسب بطاقة الكفالة', style: b(12, c: muted)),
            value: warranty,
            onChanged: (v) => setState(() => warranty = v),
          ),
          if (warranty) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () async {
                final d = await showDatePicker(context: context, firstDate: DateTime(2018), lastDate: DateTime.now(), initialDate: purchase ?? DateTime.now());
                if (d != null) setState(() => purchase = d);
              },
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text(purchase == null ? 'تاريخ الشراء (اختياري)' : 'تاريخ الشراء: ${purchase!.year}/${purchase!.month}/${purchase!.day}'),
            ),
            gap,
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () async {
                final f = await _pick(ImageSource.camera);
                if (f != null) setState(() => warrantyPhoto = f);
              },
              icon: Icon(warrantyPhoto == null ? Icons.credit_card_rounded : Icons.check_circle_rounded, color: warrantyPhoto == null ? null : Colors.green),
              label: Text(warrantyPhoto == null ? 'تصوير بطاقة الكفالة' : 'تم تصوير البطاقة — إعادة'),
            ),
          ],
        ]),
        _section('الصور', [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < photos.length; i++)
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(photos[i], width: 92, height: 92, fit: BoxFit.cover)),
                PositionedDirectional(
                  top: 2,
                  end: 2,
                  child: InkWell(
                    onTap: () => setState(() => photos.removeAt(i)),
                    child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                  ),
                ),
              ]),
            if (photos.length < 8)
              InkWell(
                onTap: _addPhoto,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_rounded, color: amberDeep), SizedBox(height: 4), Text('إضافة')]),
                ),
              ),
          ]),
        ]),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: InkWell(
            onTap: saving ? null : _submit,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(gradient: amberGrad, borderRadius: BorderRadius.circular(18)),
              child: saving
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6, color: ink))
                  : Text('حفظ — تم الاستلام', style: h(16, c: ink)),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- done
class DoneScreen extends StatelessWidget {
  final Map<String, dynamic> r;
  const DoneScreen(this.r, {super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8F7EE)),
              child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 54),
            ),
            const SizedBox(height: 18),
            Text('تم الاستلام', style: h(24)),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: inkGrad, borderRadius: BorderRadius.circular(24)),
              child: Column(children: [
                Text('الكود المرجعي', style: b(13, c: Colors.white.withValues(alpha: 0.6))),
                SelectableText('${r['code']}', style: h(32, c: amber).copyWith(letterSpacing: 2)),
                const SizedBox(height: 10),
                Text('${r['name']} • ${r['phone']}', style: b(14, c: Colors.white)),
                const SizedBox(height: 6),
                Text('الصيانة: ${r['scheduled_label']}', style: b(13.5, c: Colors.white.withValues(alpha: 0.8))),
                Text('التسليم: ${r['pickup_label']}', style: b(13.5, c: amber2, w: FontWeight.w600)),
              ]),
            ),
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: green, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              onPressed: () => openWa('${r['phone']}', '${r['receipt_message'] ?? 'رقم طلب الصيانة: ${r['code']}'}'),
              icon: const Icon(Icons.chat_rounded),
              label: Text('إرسال الإيصال للزبون على واتساب', style: h(15, c: Colors.white)),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('رجوع للقائمة', style: h(15)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- settings
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final staff = TextEditingController(text: Api.staff);
  final site = TextEditingController(text: Api.site);
  final key = TextEditingController(text: Api.key);
  bool advanced = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('الإعدادات', style: h(18)), backgroundColor: bg),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: staff, decoration: const InputDecoration(labelText: 'اسم الموظف', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        TextButton(onPressed: () => setState(() => advanced = !advanced), child: Text(advanced ? 'إخفاء الإعدادات المتقدمة' : 'إعدادات متقدمة')),
        if (advanced) ...[
          TextField(controller: site, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'رابط الموقع', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: key, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'مفتاح البرنامج', helperText: 'من ووردبريس ← تطبيق كوفيكس ← إعدادات الصيانة', border: OutlineInputBorder())),
        ],
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ink, minimumSize: const Size.fromHeight(52)),
          onPressed: () async {
            await Api.save(st: staff.text, s: site.text, k: key.text);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('حفظ'),
        ),
      ]),
    );
  }
}
