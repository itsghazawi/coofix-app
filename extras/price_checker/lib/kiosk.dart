import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'admin.dart';
import 'data.dart';
import 'theme.dart';

final navKey = GlobalKey<NavigatorState>();

Route<T> fadeRoute<T>(Widget page, {int ms = 380}) => PageRouteBuilder<T>(
      transitionDuration: Duration(milliseconds: ms),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween(begin: 1.03, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
      ),
    );

// ================================================================ hardware (Bluetooth / USB) scanner
/// Bluetooth/USB barcode readers type the code like a keyboard and press Enter.
class HwScanner {
  static void Function(String code)? onCode;
  static final _buf = StringBuffer();
  static DateTime _last = DateTime.now();

  static bool handle(KeyEvent e) {
    if (onCode == null || !Settings.hwScanner) return false;
    if (e is! KeyDownEvent) return false;
    final now = DateTime.now();
    if (now.difference(_last).inMilliseconds > 400) _buf.clear();
    _last = now;
    if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter || e.logicalKey == LogicalKeyboardKey.tab) {
      final code = _buf.toString().trim();
      _buf.clear();
      if (code.length >= 3) onCode?.call(code);
      return true;
    }
    final ch = e.character;
    if (ch != null && ch.isNotEmpty && ch.codeUnitAt(0) >= 32) {
      _buf.write(ch);
      return true;
    }
    return false;
  }
}

/// Look the code up, play the beep, and show the price screen.
void showPrice(String code) {
  final p = Db.find(code);
  Sfx.play(p != null);
  Stats.hit(normBarcode(code), p);
  navKey.currentState?.pushAndRemoveUntil(fadeRoute(ResultScreen(code: normBarcode(code), product: p), ms: 320), (r) => r.isFirst);
}

void enterKiosk() {
  Device.applyKiosk();
  navKey.currentState?.pushAndRemoveUntil(fadeRoute(const KioskHome(), ms: 600), (_) => false);
}

// ================================================================ start screen (two buttons)
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});
  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();

  @override
  void initState() {
    super.initState();
    Device.keepAwake(false);
  }

  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  Future<void> _admin() async {
    final okd = await askAdmin(context);
    if (okd && mounted) navKey.currentState?.pushAndRemoveUntil(fadeRoute(const AdminHome()), (_) => false);
  }

  Widget _card({required int i, required String title, required String sub, required IconData icon, required bool primary, required VoidCallback onTap, required double s}) {
    final anim = CurvedAnimation(parent: a, curve: Interval(0.25 + i * 0.15, 0.85 + i * 0.15 > 1 ? 1 : 0.85 + i * 0.15, curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) => Opacity(opacity: anim.value, child: Transform.translate(offset: Offset(0, 40 * (1 - anim.value)), child: child)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(34 * s),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34 * s),
              gradient: primary ? amberGrad : LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.03)]),
              border: primary ? null : Border.all(color: Colors.white.withValues(alpha: 0.13)),
              boxShadow: primary ? [BoxShadow(color: amber.withValues(alpha: 0.35), blurRadius: 50, offset: const Offset(0, 18))] : null,
            ),
            child: Stack(children: [
              Positioned(
                left: -30 * s, bottom: -40 * s,
                child: Icon(icon, size: 190 * s, color: (primary ? ink : Colors.white).withValues(alpha: primary ? 0.07 : 0.04)),
              ),
              Padding(
                padding: EdgeInsets.all(28 * s),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    width: 74 * s, height: 74 * s,
                    decoration: BoxDecoration(
                      color: primary ? ink : amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24 * s),
                      border: primary ? null : Border.all(color: amber.withValues(alpha: 0.35)),
                    ),
                    child: Icon(icon, color: amber, size: 38 * s),
                  ),
                  SizedBox(height: 22 * s),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: h(27 * s, c: primary ? ink : Colors.white, w: FontWeight.w800)),
                    SizedBox(height: 6 * s),
                    Text(sub, style: b(14.5 * s, c: primary ? ink.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.55))),
                    SizedBox(height: 16 * s),
                    Row(children: [
                      Text(primary ? 'ابدأ الآن' : 'يتطلب تسجيل الدخول', style: h(14 * s, c: primary ? ink : amber, w: FontWeight.w600)),
                      SizedBox(width: 8 * s),
                      Icon(primary ? Icons.arrow_forward_rounded : Icons.lock_rounded, size: 18 * s, color: primary ? ink : amber),
                    ]),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final wide = size.width > 640 && size.width > size.height * 0.9;
    final s = wide ? (math.min(size.width / 1000, size.height / 640)).clamp(0.8, 1.6) : (math.min(size.width / 400, size.height / 820)).clamp(0.8, 1.6);
    final cards = [
      _card(i: 0, title: 'كاشف الأسعار', sub: 'شاشة الزبائن لمسح الباركود ومعرفة السعر فوراً', icon: Icons.qr_code_scanner_rounded, primary: true, onTap: enterKiosk, s: s),
      _card(i: 1, title: 'لوحة التحكم', sub: 'رفع ملف المنتجات، الأسعار، والإعدادات', icon: Icons.tune_rounded, primary: false, onTap: _admin, s: s),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: ink,
        body: DarkBackdrop(
          child: Padding(
            padding: EdgeInsets.fromLTRB(22 * s, pad.top + 22 * s, 22 * s, pad.bottom + 18 * s),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 1100 : 520),
                child: Column(children: [
                  FadeTransition(
                    opacity: CurvedAnimation(parent: a, curve: const Interval(0, 0.5)),
                    child: Column(children: [
                      SizedBox(height: 6 * s),
                      Image.asset('assets/img/logo_dark.png', height: 62 * s),
                      SizedBox(height: 22 * s),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 26 * s, height: 2, color: amber.withValues(alpha: 0.6)),
                        SizedBox(width: 12 * s),
                        Text('كاشف الأسعار', style: h(17 * s, c: amber, w: FontWeight.w600)),
                        SizedBox(width: 12 * s),
                        Container(width: 26 * s, height: 2, color: amber.withValues(alpha: 0.6)),
                      ]),
                    ]),
                  ),
                  SizedBox(height: 26 * s),
                  Expanded(
                    child: wide
                        ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: cards[0]), SizedBox(width: 22 * s), Expanded(child: cards[1])])
                        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: cards[0]), SizedBox(height: 18 * s), Expanded(child: cards[1])]),
                  ),
                  SizedBox(height: 16 * s),
                  Text('COOFIX SYRIA · TOOLS & EQUIPMENT', style: h(11 * s, c: Colors.white.withValues(alpha: 0.28), w: FontWeight.w500).copyWith(letterSpacing: 2.5)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================ admin login sheet
int _fails = 0;
DateTime? _lockedUntil;

Future<bool> askAdmin(BuildContext context) async {
  final r = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'login',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => const _LoginDialog(),
    transitionBuilder: (_, a, _, c) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: c),
    ),
  );
  return r == true;
}

class _LoginDialog extends StatefulWidget {
  const _LoginDialog();
  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  final user = TextEditingController(), pass = TextEditingController();
  final passFocus = FocusNode();
  bool hide = true;
  String? error;

  void _go() {
    final now = DateTime.now();
    if (_lockedUntil != null && now.isBefore(_lockedUntil!)) {
      setState(() => error = 'محاولات كثيرة، انتظر ${_lockedUntil!.difference(now).inSeconds + 1} ثانية');
      return;
    }
    if (user.text.trim() == Settings.adminUser && pass.text == Settings.adminPass) {
      _fails = 0;
      HapticFeedback.lightImpact();
      Navigator.of(context).pop(true);
      return;
    }
    _fails++;
    HapticFeedback.heavyImpact();
    if (_fails >= 5) {
      _fails = 0;
      _lockedUntil = now.add(const Duration(seconds: 60));
    }
    setState(() => error = 'اسم المستخدم أو كلمة المرور غير صحيحة');
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
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF123444), ink]),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: amber.withValues(alpha: 0.25)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 20))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Center(
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(color: amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: amber.withValues(alpha: 0.4))),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: amber, size: 32),
                  ),
                ),
                const SizedBox(height: 16),
                Text('دخول لوحة التحكم', textAlign: TextAlign.center, style: h(21, c: Colors.white)),
                const SizedBox(height: 4),
                Text('للإدارة فقط', textAlign: TextAlign.center, style: b(13.5, c: Colors.white.withValues(alpha: 0.5))),
                const SizedBox(height: 22),
                TextField(
                  controller: user,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  style: b(16, c: Colors.white, w: FontWeight.w500),
                  cursorColor: amber,
                  decoration: _dec('اسم المستخدم', Icons.person_rounded),
                  onSubmitted: (_) => passFocus.requestFocus(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pass,
                  focusNode: passFocus,
                  obscureText: hide,
                  textDirection: TextDirection.ltr,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: b(16, c: Colors.white, w: FontWeight.w500),
                  cursorColor: amber,
                  decoration: _dec('كلمة المرور', Icons.lock_rounded,
                      suffix: IconButton(
                        onPressed: () => setState(() => hide = !hide),
                        icon: Icon(hide ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: Colors.white.withValues(alpha: 0.5)),
                      )),
                  onSubmitted: (_) => _go(),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: error == null
                      ? const SizedBox(height: 0)
                      : Container(
                          margin: const EdgeInsets.only(top: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: danger.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14), border: Border.all(color: danger.withValues(alpha: 0.35))),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFFF8A8A), size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(error!, style: b(13.5, c: const Color(0xFFFFC2C2), w: FontWeight.w500))),
                          ]),
                        ),
                ),
                const SizedBox(height: 20),
                AmberButton(label: 'دخول', icon: Icons.login_rounded, height: 56, fontSize: 17, onTap: _go),
                const SizedBox(height: 8),
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('إلغاء', style: b(14, c: Colors.white.withValues(alpha: 0.6), w: FontWeight.w500))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================ kiosk home
class KioskHome extends StatefulWidget {
  const KioskHome({super.key});
  @override
  State<KioskHome> createState() => _KioskHomeState();
}

class _KioskHomeState extends State<KioskHome> with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
  late final AnimationController laser = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))..repeat(reverse: true);
  late final AnimationController intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
  Timer? _hold;
  DateTime? _lastBack;

  @override
  void initState() {
    super.initState();
    HwScanner.onCode = showPrice;
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from another app → hide status bar and buttons again.
    if (state == AppLifecycleState.resumed) SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Back pressed twice within 2 seconds → leave the app (no lock).
  void _back() {
    final now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: inkLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text('اضغط رجوع مرة ثانية للخروج', textAlign: TextAlign.center, style: b(15, c: Colors.white, w: FontWeight.w500)),
      ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (HwScanner.onCode == showPrice) HwScanner.onCode = null;
    _hold?.cancel();
    pulse.dispose();
    laser.dispose();
    intro.dispose();
    super.dispose();
  }

  void _scan() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(fadeRoute(const ScannerScreen(), ms: 300));
  }

  /// Admin access: top back button (or holding the logo 3 s) + username/password.
  Future<void> _secret() async {
    HapticFeedback.selectionClick();
    final ok = await askAdmin(context);
    if (!ok || !mounted) return;
    HwScanner.onCode = null;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    navKey.currentState?.pushAndRemoveUntil(fadeRoute(const AdminHome()), (_) => false);
  }

  Widget _stagger(double from, Widget child) {
    final an = CurvedAnimation(parent: intro, curve: Interval(from, math.min(1, from + 0.5), curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: an,
      builder: (_, c) => Opacity(opacity: an.value, child: Transform.translate(offset: Offset(0, 30 * (1 - an.value)), child: c)),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final land = size.width > size.height * 1.15;
    final s = land ? math.min(size.width / 1050, size.height / 600).clamp(0.8, 2.0) : math.min(size.width / 410, size.height / 820).clamp(0.8, 2.0);

    final logo = GestureDetector(
      onLongPressStart: (_) => _hold = Timer(const Duration(milliseconds: 2500), _secret),
      onLongPressEnd: (_) => _hold?.cancel(),
      onLongPressCancel: () => _hold?.cancel(),
      child: Image.asset('assets/img/logo_dark.png', height: 58 * s),
    );
    final emblem = ScanEmblem(size: (land ? 330 : 250) * s, pulse: pulse, laser: laser);
    final texts = Column(crossAxisAlignment: land ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
      Text(Settings.welcomeTitle, textAlign: land ? TextAlign.start : TextAlign.center, style: h(34 * s, c: Colors.white, w: FontWeight.w800, height: 1.25)),
      SizedBox(height: 10 * s),
      Text(Settings.welcomeSub, textAlign: land ? TextAlign.start : TextAlign.center, style: b(18 * s, c: Colors.white.withValues(alpha: 0.62))),
    ]);
    final button = AnimatedBuilder(
      animation: pulse,
      builder: (_, _) => AmberButton(label: Settings.buttonLabel, icon: Icons.qr_code_scanner_rounded, height: 86 * s, fontSize: 26 * s, glow: pulse.value, onTap: _scan),
    );
    final hint = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.touch_app_rounded, color: Colors.white.withValues(alpha: 0.38), size: 18 * s),
      SizedBox(width: 8 * s),
      Flexible(child: Text('اضغط الزر ثم وجّه باركود القطعة نحو الكاميرا', style: b(14 * s, c: Colors.white.withValues(alpha: 0.4)))),
    ]);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) {
        if (!did) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: ink,
          body: DarkBackdrop(
            child: Stack(children: [
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28 * s, vertical: 20 * s),
                child: land
                    ? Row(children: [
                        Expanded(flex: 5, child: Center(child: _stagger(0.1, emblem))),
                        SizedBox(width: 30 * s),
                        Expanded(
                          flex: 6,
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _stagger(0.0, logo),
                            SizedBox(height: 40 * s),
                            _stagger(0.25, texts),
                            SizedBox(height: 40 * s),
                            _stagger(0.4, button),
                            SizedBox(height: 18 * s),
                            _stagger(0.5, hint),
                          ]),
                        ),
                      ])
                    : Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 640 * s),
                          child: Column(children: [
                            SizedBox(height: 14 * s),
                            _stagger(0.0, logo),
                            const Spacer(flex: 3),
                            _stagger(0.1, emblem),
                            const Spacer(flex: 3),
                            _stagger(0.25, texts),
                            const Spacer(flex: 4),
                            _stagger(0.4, button),
                            SizedBox(height: 18 * s),
                            _stagger(0.5, hint),
                            SizedBox(height: 10 * s),
                          ]),
                        ),
                      ),
              ),
            ),
            // Back to the control panel (asks for the admin password).
            Positioned(
              top: 14 * s, right: 14 * s,
              child: SafeArea(
                child: Material(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _secret,
                    child: Padding(
                      padding: EdgeInsets.all(12 * s),
                      child: Icon(Icons.arrow_back_rounded, color: Colors.white.withValues(alpha: 0.55), size: 24 * s),
                    ),
                  ),
                ),
              ),
            ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Glowing hexagon with a barcode and a sweeping laser line.
class ScanEmblem extends StatelessWidget {
  final double size;
  final Animation<double> pulse, laser;
  const ScanEmblem({super.key, required this.size, required this.pulse, required this.laser});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, laser]),
      builder: (_, _) => SizedBox(
        width: size, height: size,
        child: CustomPaint(painter: _EmblemPainter(pulse.value, Curves.easeInOut.transform(laser.value))),
      ),
    );
  }
}

Path hexPath(Offset c, double r, {double rot = -90}) {
  final p = Path();
  for (var i = 0; i < 6; i++) {
    final a = (rot + 60 * i) * math.pi / 180;
    final pt = c + Offset(math.cos(a), math.sin(a)) * r;
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

class _EmblemPainter extends CustomPainter {
  final double pulse, laser;
  _EmblemPainter(this.pulse, this.laser);

  static const _bars = [3, 1, 2, 1, 1, 3, 1, 2, 2, 1, 1, 1, 3, 1, 2, 1, 3, 1, 1, 2, 1, 1, 2, 3, 1, 1, 2, 1, 1, 3];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final R = size.width / 2;

    // outer rings
    for (var i = 0; i < 3; i++) {
      final rr = R * (0.98 - i * 0.07) * (1 + pulse * 0.015);
      canvas.drawPath(
        hexPath(c, rr),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 0 ? 1.4 : 1
          ..color = amber.withValues(alpha: (0.10 + pulse * 0.12) / (i + 1)),
      );
    }
    // glow
    canvas.drawCircle(c, R * 0.72, Paint()..shader = RadialGradient(colors: [amber.withValues(alpha: 0.16 + 0.10 * pulse), amber.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: R * 0.85)));

    // main hex
    final r = R * 0.74;
    final hp = hexPath(c, r);
    canvas.drawShadow(hp, amber.withValues(alpha: 0.6), 18 + pulse * 10, false);
    canvas.drawPath(hp, Paint()..shader = const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF14394B), ink]).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawPath(
      hp,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.035
        ..shader = const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [amber2, amber, amberDeep]).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // barcode
    final total = _bars.fold<int>(0, (a, v) => a + v) + _bars.length;
    final bw = r * 1.02, bh = r * 0.78;
    final unit = bw / total;
    var x = c.dx - bw / 2;
    final top = c.dy - bh / 2;
    final bp = Paint()..color = Colors.white.withValues(alpha: 0.92);
    for (var i = 0; i < _bars.length; i++) {
      final w = _bars[i] * unit;
      final tall = i == 0 || i == 1 || i == _bars.length - 1 || i == _bars.length - 2 || i == 15;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, top, w, bh * (tall ? 1.0 : 0.86)), Radius.circular(unit * 0.3)), bp);
      x += w + unit;
    }

    // laser
    final ly = top - bh * 0.08 + laser * bh * 1.16;
    final lr = Rect.fromLTWH(c.dx - bw * 0.62, ly - r * 0.12, bw * 1.24, r * 0.24);
    canvas.drawRect(lr, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [amber.withValues(alpha: 0), amber.withValues(alpha: 0.22), amber.withValues(alpha: 0)]).createShader(lr));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - bw * 0.62, ly - 1.6, bw * 1.24, 3.2), const Radius.circular(2)),
      Paint()
        ..shader = LinearGradient(colors: [amber.withValues(alpha: 0), amber2, amber, amber2, amber.withValues(alpha: 0)]).createShader(Rect.fromLTWH(c.dx - bw * 0.62, ly, bw * 1.24, 1))
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
    );

    // dollar badge
    final bc = c + Offset(r * 0.62, r * 0.62);
    final br = r * 0.24;
    canvas.drawCircle(bc, br + 4, Paint()..color = ink);
    canvas.drawCircle(bc, br, Paint()..shader = amberGrad.createShader(Rect.fromCircle(center: bc, radius: br)));
    final tp = TextPainter(
      text: TextSpan(text: '\$', style: h(br * 1.25, c: ink, w: FontWeight.w800, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, bc - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter o) => o.pulse != pulse || o.laser != laser;
}

// ================================================================ camera scanner
class ScannerScreen extends StatefulWidget {
  /// When set, the scanner just returns the code (admin "scan barcode" field).
  final bool pickOnly;
  const ScannerScreen({super.key, this.pickOnly = false});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  late final MobileScannerController cam = MobileScannerController(
    facing: Settings.frontCamera && !widget.pickOnly ? CameraFacing.front : CameraFacing.back,
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 150,
    formats: const [
      BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE, BarcodeFormat.code128,
      BarcodeFormat.code39, BarcodeFormat.code93, BarcodeFormat.itf2of5, BarcodeFormat.codabar, // 1D barcodes only — QR codes are ignored
    ],
  );
  late final AnimationController laser = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  Timer? _timeout;
  bool _done = false;
  bool torch = false;
  int left = Settings.scanTimeout;

  @override
  void initState() {
    super.initState();
    if (!widget.pickOnly) HwScanner.onCode = _hit;
    _timeout = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) _close();
    });
  }

  @override
  void dispose() {
    if (HwScanner.onCode == _hit) HwScanner.onCode = showPrice;
    _timeout?.cancel();
    laser.dispose();
    cam.dispose();
    super.dispose();
  }

  void _close() {
    if (_done) return;
    _done = true;
    _timeout?.cancel();
    cam.stop();
    if (mounted) Navigator.of(context).pop();
  }

  void _hit(String code) {
    if (_done || code.trim().isEmpty) return;
    _done = true;
    _timeout?.cancel();
    cam.stop(); // camera off right away — saves battery
    if (widget.pickOnly) {
      Sfx.play(true);
      Navigator.of(context).pop(normBarcode(code));
    } else {
      showPrice(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final s = uiScale(size);
    final ww = math.min(size.width * 0.82, 560.0 * s);
    final wh = ww * 0.6;
    final win = Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.46), width: ww, height: wh);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) {
        if (!did) _close();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(children: [
            Positioned.fill(
              child: MobileScanner(
                controller: cam,
                onDetect: (cap) {
                  final v = cap.barcodes.map((e) => e.rawValue ?? '').firstWhere((e) => e.trim().isNotEmpty, orElse: () => '');
                  if (v.isNotEmpty) _hit(v);
                },
                errorBuilder: (_, e) => _CamError(error: e, onClose: _close),
                placeholderBuilder: (_) => const ColoredBox(color: ink, child: Center(child: CircularProgressIndicator(color: amber))),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(animation: laser, builder: (_, _) => CustomPaint(painter: _OverlayPainter(win, Curves.easeInOut.transform(laser.value)))),
              ),
            ),
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20 * s, 18 * s, 20 * s, 0),
                  child: Column(children: [
                    Image.asset('assets/img/logo_dark.png', height: 40 * s),
                    SizedBox(height: 18 * s),
                    Text(widget.pickOnly ? 'امسح باركود المنتج' : 'وجّه الباركود نحو المربّع', style: h(24 * s, c: Colors.white, w: FontWeight.w800)),
                    SizedBox(height: 6 * s),
                    Text('ثبّت القطعة قليلاً حتى تسمع الصوت', style: b(15 * s, c: Colors.white.withValues(alpha: 0.7))),
                  ]),
                ),
              ),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24 * s, 0, 24 * s, 24 * s),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('تُغلق الكاميرا تلقائياً بعد $left ثانية', style: b(13 * s, c: Colors.white.withValues(alpha: 0.5))),
                    SizedBox(height: 14 * s),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _RoundBtn(icon: torch ? Icons.flashlight_off_rounded : Icons.flashlight_on_rounded, label: torch ? 'إطفاء الضوء' : 'الضوء', s: s, onTap: () {
                        cam.toggleTorch();
                        setState(() => torch = !torch);
                      }),
                      SizedBox(width: 18 * s),
                      _RoundBtn(icon: Icons.close_rounded, label: 'إلغاء', s: s, onTap: _close, primary: true),
                    ]),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final double s;
  final VoidCallback onTap;
  final bool primary;
  const _RoundBtn({required this.icon, required this.label, required this.s, required this.onTap, this.primary = false});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? amber : Colors.white.withValues(alpha: 0.14),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 15 * s),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: primary ? ink : Colors.white, size: 22 * s),
            SizedBox(width: 8 * s),
            Text(label, style: h(16 * s, c: primary ? ink : Colors.white, w: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _CamError extends StatelessWidget {
  final MobileScannerException error;
  final VoidCallback onClose;
  const _CamError({required this.error, required this.onClose});
  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: ink,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.no_photography_rounded, color: amber, size: 56),
            const SizedBox(height: 16),
            Text(denied ? 'لا يوجد إذن للكاميرا' : 'تعذّر تشغيل الكاميرا', style: h(22, c: Colors.white)),
            const SizedBox(height: 8),
            Text(denied ? 'اسمح للتطبيق باستخدام الكاميرا من إعدادات الجهاز' : 'أعد المحاولة بعد قليل', textAlign: TextAlign.center, style: b(15, c: Colors.white.withValues(alpha: 0.6))),
            const SizedBox(height: 24),
            GlassButton(label: 'رجوع', icon: Icons.arrow_back_rounded, onTap: onClose),
          ]),
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect win;
  final double t;
  _OverlayPainter(this.win, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(win, const Radius.circular(26));
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(rr)),
      Paint()..color = const Color(0xC8061922),
    );
    // corner brackets
    final p = Paint()
      ..color = amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final l = win.width * 0.12;
    const r = 26.0;
    void corner(Offset o, double sx, double sy) {
      final path = Path()
        ..moveTo(o.dx, o.dy + sy * (r + l))
        ..lineTo(o.dx, o.dy + sy * r)
        ..arcToPoint(Offset(o.dx + sx * r, o.dy), radius: const Radius.circular(r), clockwise: sx * sy > 0)
        ..lineTo(o.dx + sx * (r + l), o.dy);
      canvas.drawPath(path, p);
    }

    corner(win.topLeft, 1, 1);
    corner(win.topRight, -1, 1);
    corner(win.bottomLeft, 1, -1);
    corner(win.bottomRight, -1, -1);

    // laser
    final y = win.top + 14 + t * (win.height - 28);
    final lr = Rect.fromLTWH(win.left + 16, y - 1.5, win.width - 32, 3);
    canvas.drawRect(lr.inflate(10), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [amber.withValues(alpha: 0), amber.withValues(alpha: 0.25), amber.withValues(alpha: 0)]).createShader(lr.inflate(10)));
    canvas.drawRRect(
      RRect.fromRectAndRadius(lr, const Radius.circular(2)),
      Paint()
        ..shader = LinearGradient(colors: [amber.withValues(alpha: 0), amber2, amber2, amber.withValues(alpha: 0)]).createShader(lr)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
    );
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter o) => o.t != t || o.win != win;
}

// ================================================================ price result
class ResultScreen extends StatefulWidget {
  final String code;
  final Product? product;
  const ResultScreen({super.key, required this.code, required this.product});
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with TickerProviderStateMixin {
  late final int seconds = widget.product == null ? math.min(Settings.resultSeconds, 10) : Settings.resultSeconds;
  late final AnimationController count = AnimationController(vsync: this, duration: Duration(seconds: seconds))..forward();
  late final AnimationController intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  late final AnimationController shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();

  @override
  void initState() {
    super.initState();
    HwScanner.onCode = showPrice;
    count.addStatusListener((s) {
      if (s == AnimationStatus.completed) _home();
    });
  }

  @override
  void dispose() {
    count.dispose();
    intro.dispose();
    shine.dispose();
    super.dispose();
  }

  void _home() {
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _again() {
    count.stop();
    Navigator.of(context).pushReplacement(fadeRoute(const ScannerScreen(), ms: 300));
  }

  Widget _in(double from, Widget child, {double dy = 30, double scale = 1}) {
    final an = CurvedAnimation(parent: intro, curve: Interval(from, math.min(1, from + 0.55), curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: an,
      builder: (_, c) => Opacity(
        opacity: an.value,
        child: Transform.translate(offset: Offset(0, dy * (1 - an.value)), child: Transform.scale(scale: scale + (1 - scale) * an.value, child: c)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final land = size.width > size.height * 1.15;
    final s = land ? math.min(size.width / 900, size.height / 640).clamp(0.8, 2.2) : math.min(size.width / 400, size.height / 800).clamp(0.8, 2.2);
    final p = widget.product;

    final top = Center(child: Image.asset('assets/img/logo_dark.png', height: 44 * s));

    final buttons = Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: count,
        builder: (_, _) {
          final left = (seconds * (1 - count.value)).ceil();
          return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
              width: 40 * s, height: 40 * s,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(value: 1 - count.value, strokeWidth: 3 * s, color: amber, backgroundColor: Colors.white.withValues(alpha: 0.1)),
                Text('$left', style: h(14 * s, c: Colors.white, w: FontWeight.w700, height: 1)),
              ]),
            ),
            SizedBox(width: 10 * s),
            Text('العودة لكشف السعر خلال $left ثانية', style: b(15 * s, c: Colors.white.withValues(alpha: 0.6))),
          ]);
        },
      ),
      SizedBox(height: 16 * s),
      SizedBox(width: double.infinity, child: AmberButton(label: 'اكشف سعر آخر', icon: Icons.qr_code_scanner_rounded, height: 78 * s, fontSize: 23 * s, onTap: _again)),
    ]);

    final Widget body;
    if (p == null) {
      body = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _in(0, Container(
          width: 130 * s, height: 130 * s,
          decoration: BoxDecoration(shape: BoxShape.circle, color: amber.withValues(alpha: 0.1), border: Border.all(color: amber.withValues(alpha: 0.4), width: 2)),
          child: Icon(Icons.search_off_rounded, color: amber, size: 64 * s),
        ), scale: 0.6),
        SizedBox(height: 28 * s),
        _in(0.15, Text(Settings.notFoundTitle, textAlign: TextAlign.center, style: h(38 * s, c: Colors.white, w: FontWeight.w800))),
        SizedBox(height: 12 * s),
        _in(0.25, Text(Settings.notFoundSub, textAlign: TextAlign.center, style: b(20 * s, c: Colors.white.withValues(alpha: 0.65)))),
        SizedBox(height: 22 * s),
        _in(0.35, _BarcodeChip(code: widget.code, s: s)),
      ]);
    } else {
      final (whole, cents) = splitPrice(p.price);
      body = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _in(0.0, Container(
          padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 7 * s),
          decoration: BoxDecoration(color: amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(40), border: Border.all(color: amber.withValues(alpha: 0.35))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_rounded, color: amber, size: 18 * s),
            SizedBox(width: 7 * s),
            Text('اسم المنتج', style: h(14 * s, c: amber, w: FontWeight.w600)),
          ]),
        )),
        SizedBox(height: 16 * s),
        _in(0.08, Text(
          p.name,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: h((p.name.length > 60 ? 30 : p.name.length > 32 ? 36 : 44) * s, c: Colors.white, w: FontWeight.w800, height: 1.35),
        )),
        SizedBox(height: 30 * s),
        _in(0.2, _PriceCard(whole: whole, cents: cents, price: p.price, s: s, intro: intro, shine: shine), dy: 40, scale: 0.85),
        if (Settings.showBarcode) ...[SizedBox(height: 22 * s), _in(0.45, _BarcodeChip(code: p.barcode, s: s))],
      ]);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) {
        if (!did) _home();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: ink,
          body: DarkBackdrop(
            glow: 1.4,
            child: Stack(children: [
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(26 * s, 16 * s, 26 * s, 22 * s),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: (land ? 900 : 640) * s),
                      child: Column(children: [
                        top,
                        Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: math.min(size.width - 52 * s, (land ? 900 : 640) * s), child: body))),
                        _in(0.55, buttons),
                      ]),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: AnimatedBuilder(
                  animation: count,
                  builder: (_, _) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: 1 - count.value,
                      child: Container(height: 5, decoration: const BoxDecoration(gradient: amberGrad)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final String whole, cents;
  final double price, s;
  final Animation<double> intro, shine;
  const _PriceCard({required this.whole, required this.cents, required this.price, required this.s, required this.intro, required this.shine});

  @override
  Widget build(BuildContext context) {
    final countUp = CurvedAnimation(parent: intro, curve: const Interval(0.2, 0.85, curve: Curves.easeOutExpo));
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24 * s, 22 * s, 24 * s, 26 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(38 * s),
        border: Border.all(color: amber, width: 4 * s),
        boxShadow: [BoxShadow(color: amber.withValues(alpha: 0.30), blurRadius: 60, spreadRadius: 2)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30 * s),
        child: Stack(alignment: Alignment.center, children: [
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('السعر', style: h(18 * s, c: muted, w: FontWeight.w600)),
            SizedBox(height: 4 * s),
            AnimatedBuilder(
              animation: countUp,
              builder: (_, _) {
                final (w, c) = countUp.value >= 1 ? (whole, cents) : splitPrice(price * countUp.value);
                final cc = cents.isEmpty ? '' : c.padRight(2, '0');
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Padding(
                        padding: EdgeInsets.only(top: 22 * s, right: 6 * s),
                        child: ShaderMask(
                          shaderCallback: (r) => amberGrad.createShader(r),
                          child: Text('\$', style: h(64 * s, c: Colors.white, w: FontWeight.w800, height: 1)),
                        ),
                      ),
                      Text(cc.isEmpty ? w : '$w.$cc', style: h(132 * s, c: ink, w: FontWeight.w800, height: 1.12).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      )),
                    ]),
                  ),
                );
              },
            ),
            SizedBox(height: 4 * s),
            Text('دولار أمريكي', style: b(15 * s, c: amberDeep, w: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

class _BarcodeChip extends StatelessWidget {
  final String code;
  final double s;
  const _BarcodeChip({required this.code, required this.s});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 8 * s),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(40), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.barcode_reader, color: Colors.white.withValues(alpha: 0.5), size: 18 * s),
        SizedBox(width: 8 * s),
        Text(code, textDirection: TextDirection.ltr, style: b(15 * s, c: Colors.white.withValues(alpha: 0.6), w: FontWeight.w500).copyWith(letterSpacing: 1.5)),
      ]),
    );
  }
}
