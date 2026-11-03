import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:math' as math;

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
class SessionExpired implements Exception {
  final String msg;
  SessionExpired([this.msg = 'انتهت الجلسة، سجّل الدخول من جديد']);
  @override
  String toString() => msg;
}

final navKey = GlobalKey<NavigatorState>();

class Api {
  static String site = 'https://www.coofix.sy';
  static String token = '';
  static String staff = '';
  static String username = '';

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    site = p.getString('site') ?? site;
    token = p.getString('token') ?? '';
    staff = p.getString('staff_name') ?? '';
    username = p.getString('username') ?? '';
  }

  static Future<void> saveSite(String s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('site', site = s.trim().replaceAll(RegExp(r'/+$'), ''));
  }

  static Uri u(String path, [Map<String, String>? q]) => Uri.parse('$site/wp-json/coofix-app/v1$path').replace(queryParameters: q);
  static Map<String, String> get headers => {'X-Coofix-Token': token};

  static String _msg(http.Response r, String def) {
    try {
      final m = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['message'];
      if (m is String && m.isNotEmpty) return m;
    } catch (_) {}
    return def;
  }

  static Future<void> login(String user, String pass) async {
    final r = await http
        .post(u('/staff/login'), headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': user.trim(), 'password': pass, 'device': Platform.operatingSystem}))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode == 404) throw 'إضافة كوفيكس على الموقع بحاجة لتحديث';
    if (r.statusCode != 200) throw _msg(r, 'تعذّر تسجيل الدخول (${r.statusCode})');
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
    final p = await SharedPreferences.getInstance();
    token = '${j['token']}';
    staff = '${(j['user'] as Map)['name']}';
    username = '${(j['user'] as Map)['username']}';
    await p.setString('token', token);
    await p.setString('staff_name', staff);
    await p.setString('username', username);
  }

  static Future<void> clearSession() async {
    token = '';
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
  }

  static Future<void> logout() async {
    try {
      await http.post(u('/staff/logout'), headers: headers).timeout(const Duration(seconds: 8));
    } catch (_) {}
    await clearSession();
  }

  static Future<void> _check(http.Response r) async {
    if (r.statusCode == 401 || r.statusCode == 403) {
      final had = token.isNotEmpty;
      await clearSession();
      throw SessionExpired(had ? _msg(r, 'انتهت الجلسة، سجّل الدخول من جديد') : '');
    }
  }

  static Future<Map<String, dynamic>> info() async {
    final r = await http.get(u('/staff/info', {'_': '${DateTime.now().millisecondsSinceEpoch}'}), headers: headers).timeout(const Duration(seconds: 15));
    await _check(r);
    if (r.statusCode == 404) throw 'إضافة كوفيكس غير مثبتة أو غير محدّثة على الموقع';
    if (r.statusCode != 200) throw 'خطأ في الاتصال (${r.statusCode})';
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  static Map<String, dynamic> counts = {};

  static Future<List<Map<String, dynamic>>> list({String q = '', String state = 'all'}) async {
    final r = await http
        .get(u('/staff/repairs', {if (q.isNotEmpty) 'q': q, 'state': state, '_': '${DateTime.now().millisecondsSinceEpoch}'}), headers: headers)
        .timeout(const Duration(seconds: 20));
    await _check(r);
    if (r.statusCode != 200) throw 'تعذّر تحميل الطلبات (${r.statusCode})';
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    counts = j['counts'] is Map ? (j['counts'] as Map).cast<String, dynamic>() : {};
    return (j['items'] as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<Map<String, dynamic>> update(int id, Map<String, String> fields) async {
    final r = await http.post(u('/staff/repairs/$id'), headers: headers, body: fields).timeout(const Duration(seconds: 20));
    await _check(r);
    if (r.statusCode != 200) throw _msg(r, 'تعذّر الحفظ (${r.statusCode})');
    return (jsonDecode(utf8.decode(r.bodyBytes)) as Map).cast<String, dynamic>();
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
    await _check(res);
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
      navigatorKey: navKey,
      home: Api.token.isEmpty ? const LoginScreen() : const HomeScreen(),
    );
  }
}

/// Back to the login screen (session expired / logged out).
void goLogin([String? msg]) {
  navKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LoginScreen(message: (msg ?? '').isEmpty ? null : msg)), (_) => false);
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
  String state = 'all';
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final my = ++_seq;
    try {
      final r = await Future.wait([Api.info(), Api.list(q: search.text.trim(), state: state)]);
      if (my != _seq) return; // a newer filter/search started meanwhile
      info = r[0] as Map<String, dynamic>;
      items = r[1] as List<Map<String, dynamic>>;
    } on SessionExpired catch (e) {
      goLogin(e.msg);
      return;
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
                        Text(Api.staff.isEmpty ? 'برنامج الاستلام' : 'أهلاً، ${Api.staff}', style: b(12.5, c: Colors.white.withValues(alpha: 0.6))),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  for (final f in const [('all', 'الكل', Icons.all_inbox_rounded), ('open', 'لم يتم التسليم', Icons.pending_actions_rounded), ('delivered', 'تم التسليم', Icons.task_alt_rounded)]) ...[
                    Expanded(child: _FilterChip(
                      label: f.$2,
                      icon: f.$3,
                      count: Api.counts[f.$1],
                      on: state == f.$1,
                      onTap: () {
                        if (state == f.$1) return;
                        setState(() => state = f.$1);
                        _load();
                      },
                    )),
                    if (f.$1 != 'delivered') const SizedBox(width: 8),
                  ],
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
              SliverFillRemaining(hasScrollBody: false, child: Center(child: Text(state == 'delivered' ? 'لا توجد طلبات مُسلَّمة' : state == 'open' ? 'لا توجد طلبات بانتظار التسليم' : 'لا توجد طلبات بعد', style: b(15, c: muted))))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (c, i) => _RepairTile(items[i], onChanged: _load),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final dynamic count;
  final bool on;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.icon, required this.count, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          gradient: on ? inkGrad : null,
          color: on ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? ink : line),
          boxShadow: on ? [BoxShadow(color: ink.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6))] : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 17, color: on ? amber : muted),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(color: on ? amber : bg, borderRadius: BorderRadius.circular(20)),
                child: Text('$count', style: h(11.5, c: on ? ink : textC)),
              ),
            ],
          ]),
          const SizedBox(height: 5),
          FittedBox(child: Text(label, maxLines: 1, style: h(12.5, c: on ? Colors.white : textC, w: FontWeight.w600))),
        ]),
      ),
    );
  }
}

class _RepairTile extends StatelessWidget {
  final Map<String, dynamic> r;
  final VoidCallback? onChanged;
  const _RepairTile(this.r, {this.onChanged});
  @override
  Widget build(BuildContext context) {
    final st = '${r['status']}';
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        final ch = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => RepairDetail(r)));
        if (ch == true) onChanged?.call();
      },
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
class RepairDetail extends StatefulWidget {
  final Map<String, dynamic> r;
  const RepairDetail(this.r, {super.key});
  @override
  State<RepairDetail> createState() => _RepairDetailState();
}

class _RepairDetailState extends State<RepairDetail> {
  late Map<String, dynamic> r = widget.r;
  bool changed = false;

  Future<void> _update() async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StatusSheet(r),
    );
    if (res == null || !mounted) return;
    setState(() {
      r = res;
      changed = true;
    });
    final txt = '${res['notify_text'] ?? ''}';
    if (res['_notify'] == true && txt.isNotEmpty) await openWa('${r['phone']}', txt);
    if (mounted) snack(context, 'تم تحديث الطلب ✓');
  }

  @override
  Widget build(BuildContext context) {
    final photos = (r['photo_urls'] as List? ?? []).map((e) => '$e').toList();
    final tl = (r['timeline'] as List? ?? []).whereType<Map>().toList().reversed.toList();
    final st = '${r['status']}';
    Widget row(String k, String v) => v.trim().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 120, child: Text(k, style: b(13.5, c: muted))),
              Expanded(child: Text(v, style: b(14, w: FontWeight.w600))),
            ]),
          );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('${r['code']}', style: h(18)), backgroundColor: bg),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: ink, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _update,
                icon: const Icon(Icons.edit_note_rounded, color: amber),
                label: Text('تحديث الحالة', style: h(15, c: Colors.white)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: green, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () => openWa('${r['phone']}', 'مرحباً ${r['name']} 👋\nطلب الصيانة رقم ${r['code']}\nالحالة: ${r['status_label']}\nكوفيكس سوريا'),
                icon: const Icon(Icons.chat_rounded),
                label: Text('واتساب', style: h(15, c: Colors.white)),
              ),
            ),
          ]),
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: inkGrad, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: statusColor(st).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                child: Icon(st == 'delivered' ? Icons.task_alt_rounded : st == 'ready' ? Icons.inventory_2_rounded : Icons.build_circle_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r['status_label']}', style: h(17, c: Colors.white)),
                Text('${r['name']} • ${r['phone']}', style: b(13, c: Colors.white.withValues(alpha: 0.6))),
              ])),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: line)),
            child: Column(children: [
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
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => showDialog(context: context, builder: (_) => Dialog(insetPadding: const EdgeInsets.all(12), child: InteractiveViewer(child: Image.network(photos[i])))),
                  child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(photos[i], width: 110, height: 110, fit: BoxFit.cover)),
                ),
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
                subtitle: Text([if ('${t['note'] ?? ''}'.isNotEmpty) '${t['note']}', if ('${t['by'] ?? ''}'.isNotEmpty) '— ${t['by']}'].join('\n'), style: b(13, c: muted)),
                trailing: t['public'] == false ? const Icon(Icons.lock_rounded, size: 16, color: muted) : null,
              ),
          ],
        ]),
      ),
    );
  }
}

class _StatusSheet extends StatefulWidget {
  final Map<String, dynamic> r;
  const _StatusSheet(this.r);
  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  late String status = '${widget.r['status']}';
  final note = TextEditingController();
  late final cost = TextEditingController(text: '${widget.r['cost'] ?? ''}');
  late final work = TextEditingController(text: '${widget.r['work_done'] ?? ''}');
  bool public = true, notify = true, saving = false;

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final res = await Api.update((widget.r['id'] as num).toInt(), {
        'status': status,
        'note': note.text.trim(),
        'public': public ? '1' : '0',
        'cost': cost.text.trim(),
        'work_done': work.text.trim(),
      });
      res['_notify'] = notify;
      if (mounted) Navigator.pop(context, res);
      return;
    } on SessionExpired catch (e) {
      goLogin(e.msg);
      return;
    } catch (e) {
      if (mounted) snack(context, e is String ? e : 'تعذّر الحفظ، تحقق من الإنترنت');
    }
    if (mounted) setState(() => saving = false);
  }

  InputDecoration _dec(String l, IconData i) => InputDecoration(
        labelText: l,
        prefixIcon: Icon(i, size: 20),
        filled: true,
        fillColor: bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    const keys = ['received', 'diagnosing', 'waiting_parts', 'repairing', 'ready', 'delivered', 'cancelled'];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 14),
              Text('تحديث الطلب ${widget.r['code']}', style: h(18)),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in keys)
                  ChoiceChip(
                    label: Text(statusLabel(k)),
                    selected: status == k,
                    onSelected: (_) => setState(() => status = k),
                    selectedColor: statusColor(k),
                    labelStyle: b(13.5, w: FontWeight.w600, c: status == k ? Colors.white : textC),
                    side: BorderSide(color: status == k ? statusColor(k) : line),
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
              ]),
              const SizedBox(height: 14),
              TextField(controller: note, maxLines: 2, decoration: _dec('ملاحظة (مثلاً: تم تغيير قلب ساعة الراحة)', Icons.sticky_note_2_rounded)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: cost, keyboardType: TextInputType.number, decoration: _dec('التكلفة', Icons.payments_rounded))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: work, maxLines: 2, decoration: _dec('ما تم إنجازه', Icons.build_rounded)),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: public,
                onChanged: (v) => setState(() => public = v),
                title: Text('الملاحظة تظهر للزبون', style: b(14, w: FontWeight.w600)),
                activeThumbColor: amberDeep,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: notify,
                onChanged: (v) => setState(() => notify = v),
                title: Text('إرسال التحديث للزبون على واتساب', style: b(14, w: FontWeight.w600)),
                activeThumbColor: green,
              ),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: ink, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: saving ? null : _save,
                child: saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : Text('حفظ', style: h(16, c: Colors.white)),
              ),
            ]),
          ),
        ),
      ),
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
      }, photos, warranty ? warrantyPhoto : null);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => DoneScreen(r)));
    } on SessionExpired catch (e) {
      goLogin(e.msg);
      return;
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
  final site = TextEditingController(text: Api.site);
  bool advanced = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('الحساب والإعدادات', style: h(18)), backgroundColor: bg),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: inkGrad, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(gradient: amberGrad, borderRadius: BorderRadius.circular(16)),
              child: Text(Api.staff.isEmpty ? '؟' : Api.staff.characters.first, style: h(22, c: ink)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(Api.staff, style: h(17, c: Colors.white)),
              Text('@${Api.username}', textDirection: TextDirection.ltr, style: b(13, c: Colors.white.withValues(alpha: 0.6))),
            ])),
          ]),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB42318),
            side: const BorderSide(color: Color(0xFFF1B4AE)),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text('تسجيل الخروج؟', style: h(18)),
                content: const Text('بتحتاج اسم المستخدم وكلمة المرور لتدخل مرة ثانية.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('خروج')),
                ],
              ),
            );
            if (ok == true) {
              await Api.logout();
              goLogin();
            }
          },
          icon: const Icon(Icons.logout_rounded),
          label: Text('تسجيل الخروج', style: h(15, c: const Color(0xFFB42318))),
        ),
        const SizedBox(height: 24),
        TextButton(onPressed: () => setState(() => advanced = !advanced), child: Text(advanced ? 'إخفاء الإعدادات المتقدمة' : 'إعدادات متقدمة')),
        if (advanced) ...[
          TextField(controller: site, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'رابط الموقع', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ink, minimumSize: const Size.fromHeight(52)),
            onPressed: () async {
              await Api.saveSite(site.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------- login
class LoginScreen extends StatefulWidget {
  final String? message;
  const LoginScreen({super.key, this.message});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final user = TextEditingController(text: Api.username);
  final pass = TextEditingController();
  final passFocus = FocusNode();
  bool hide = true, busy = false;
  String? error;
  late final AnimationController glow = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    error = widget.message;
  }

  @override
  void dispose() {
    glow.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    FocusScope.of(context).unfocus();
    if (user.text.trim().isEmpty || pass.text.isEmpty) {
      setState(() => error = 'أدخل اسم المستخدم وكلمة المرور');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Api.login(user.text, pass.text);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        ),
        (_) => false,
      );
      return;
    } catch (e) {
      error = e is String ? e : 'تعذّر الاتصال بالموقع، تحقق من الإنترنت';
    }
    if (mounted) setState(() => busy = false);
  }

  InputDecoration _dec(String label, IconData icon, {Widget? suffix}) => InputDecoration(
        hintText: label,
        hintStyle: b(15, c: Colors.white.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon, color: amber.withValues(alpha: 0.9), size: 21),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.25),
        contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: amber, width: 1.4)),
      );

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: ink,
        body: Stack(children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF0D2F3E), ink, Color(0xFF020A0E)]),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _HexPainter())),
          Positioned(
            top: -120, right: -100,
            child: Container(width: 320, height: 320, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [amber.withValues(alpha: 0.22), amber.withValues(alpha: 0)]))),
          ),
          Positioned(
            bottom: -140, left: -120,
            child: Container(width: 340, height: 340, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [amber.withValues(alpha: 0.10), amber.withValues(alpha: 0)]))),
          ),
          LayoutBuilder(builder: (context, box) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, pad.top + 24, 24, pad.bottom + 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - pad.top - pad.bottom - 48),
              child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedBuilder(
                    animation: glow,
                    builder: (_, child) => Container(
                      width: 104, height: 104,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF14394B), ink]),
                        border: Border.all(color: amber.withValues(alpha: 0.35 + glow.value * 0.25)),
                        boxShadow: [BoxShadow(color: amber.withValues(alpha: 0.18 + glow.value * 0.22), blurRadius: 34 + glow.value * 16, offset: const Offset(0, 12))],
                      ),
                      padding: const EdgeInsets.all(18),
                      child: child,
                    ),
                    child: Image.asset('assets/img/icon.png'),
                  ),
                  const SizedBox(height: 22),
                  Text('صيانة كوفيكس', style: h(26, c: Colors.white)),
                  const SizedBox(height: 6),
                  Text('بوابة فريق الصيانة المعتمد', style: b(14, c: Colors.white.withValues(alpha: 0.55))),
                  const SizedBox(height: 34),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('تسجيل الدخول', style: h(19, c: Colors.white)),
                        const SizedBox(height: 4),
                        Text('ادخل بالحساب يلي عطتك ياه الإدارة', style: b(13, c: Colors.white.withValues(alpha: 0.5))),
                        const SizedBox(height: 20),
                        TextField(
                          controller: user,
                          textDirection: TextDirection.ltr,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          keyboardType: TextInputType.visiblePassword,
                          cursorColor: amber,
                          onSubmitted: (_) => passFocus.requestFocus(),
                          style: b(16, c: Colors.white, w: FontWeight.w500),
                          decoration: _dec('اسم المستخدم', Icons.person_rounded),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: pass,
                          focusNode: passFocus,
                          obscureText: hide,
                          textDirection: TextDirection.ltr,
                          textInputAction: TextInputAction.done,
                          cursorColor: amber,
                          onSubmitted: (_) => _go(),
                          style: b(16, c: Colors.white, w: FontWeight.w500),
                          decoration: _dec('كلمة المرور', Icons.lock_rounded,
                              suffix: IconButton(
                                onPressed: () => setState(() => hide = !hide),
                                icon: Icon(hide ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: Colors.white54),
                              )),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: error == null
                              ? const SizedBox(height: 18)
                              : Container(
                                  margin: const EdgeInsets.only(top: 14, bottom: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B5B).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFFF6B5B).withValues(alpha: 0.35)),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.error_outline_rounded, color: Color(0xFFFF8A7D), size: 19),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(error!, style: b(13.5, c: const Color(0xFFFFB4AA), w: FontWeight.w500))),
                                  ]),
                                ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: busy ? null : _go,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: busy ? 0.75 : 1,
                            child: Container(
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: amberGrad,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: amber.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 10))],
                              ),
                              child: busy
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6, color: ink))
                                  : Row(mainAxisSize: MainAxisSize.min, children: [
                                      Text('دخول', style: h(17, c: ink)),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_back_rounded, color: ink, size: 20),
                                    ]),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.verified_user_rounded, size: 15, color: Colors.white.withValues(alpha: 0.35)),
                    const SizedBox(width: 6),
                    Text('للاستخدام الداخلي — كوفيكس سوريا', style: b(12, c: Colors.white.withValues(alpha: 0.35))),
                  ]),
                ]),
              ),
            ),
            ),
          )),
        ]),
      ),
    );
  }
}

/// Subtle honeycomb pattern (Coofix hexagon).
class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = amber.withValues(alpha: 0.055);
    const r = 26.0;
    final w = math.sqrt(3) * r, hgt = 1.5 * r;
    for (var row = -1; row * hgt < size.height + r; row++) {
      for (var col = -1; col * w < size.width + w; col++) {
        final cx = col * w + (row.isOdd ? w / 2 : 0), cy = row * hgt;
        final path = Path();
        for (var i = 0; i < 6; i++) {
          final a = math.pi / 180 * (60 * i - 30);
          final x = cx + r * math.cos(a), y = cy + r * math.sin(a);
          i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
        }
        path.close();
        canvas.drawPath(path, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
