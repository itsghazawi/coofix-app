import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api.dart';
import '../data/config.dart';
import '../data/store.dart';
import '../theme.dart';
import 'brand.dart';
import 'ui.dart';

/// Premium "كود المنتج" tag — tap to copy.
class SkuTag extends StatefulWidget {
  final String code;
  const SkuTag(this.code, {super.key});
  @override
  State<SkuTag> createState() => _SkuTagState();
}

class _SkuTagState extends State<SkuTag> {
  bool copied = false;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.96,
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: widget.code));
        HapticFeedback.selectionClick();
        setState(() => copied = true);
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) setState(() => copied = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: copied ? null : const LinearGradient(colors: [Color(0xFF0F3041), Color(0xFF061922)]),
          color: copied ? const Color(0xFF16794A) : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.accent.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: const Color(0xFF061922).withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: IntrinsicHeight(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 34,
              decoration: BoxDecoration(gradient: copied ? null : C.accentGrad, color: copied ? Colors.white24 : null),
              child: Icon(copied ? Icons.check_rounded : Icons.hexagon_outlined, size: 17, color: copied ? Colors.white : const Color(0xFF061922)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(child: Text(copied ? 'تم النسخ' : 'كود المنتج', style: T.b(12, w: FontWeight.w600, c: Colors.white.withValues(alpha: copied ? 1 : 0.6)))),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                border: Border(right: BorderSide(color: C.accent.withValues(alpha: 0.3))),
              ),
              child: Text(widget.code,
                  textDirection: TextDirection.ltr,
                  style: T.h(14, c: copied ? Colors.white : const Color(0xFFFFC14F)).copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Small code chip for product cards.
class SkuChip extends StatelessWidget {
  final String code;
  const SkuChip(this.code, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: C.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(7)),
        child: Text(code, textDirection: TextDirection.ltr, style: T.h(10.5, c: const Color(0xFF9A6200)).copyWith(letterSpacing: 0.3)),
      );
}

/// App footer (bottom of Home and More).
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final cfg = Cfg.i;
    const nets = {
      'facebook': Icons.facebook_rounded,
      'instagram': Icons.camera_alt_rounded,
      'tiktok': Icons.music_note_rounded,
      'youtube': Icons.play_circle_fill_rounded,
      'telegram': Icons.send_rounded,
      'x': Icons.alternate_email_rounded,
      'linkedin': Icons.work_rounded,
    };
    final socials = [
      for (final k in nets.keys)
        if (cfg.s('contact.socials.$k').isNotEmpty) (nets[k]!, cfg.s('contact.socials.$k')),
    ];
    Widget btn(IconData i, String label, VoidCallback f, {bool wa = false}) => Expanded(
          child: Pressable(
            onTap: f,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: wa ? const Color(0xFF25D366) : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: wa ? const Color(0xFF25D366) : Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(i, size: 18, color: wa ? const Color(0xFF062B16) : C.accent),
                const SizedBox(width: 8),
                Text(label, textDirection: wa ? null : TextDirection.ltr, style: T.h(13.5, c: wa ? const Color(0xFF062B16) : Colors.white)),
              ]),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      decoration: BoxDecoration(gradient: C.inkGrad, borderRadius: BorderRadius.circular(28)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF0F3041),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: C.accent.withValues(alpha: 0.35)),
          ),
          child: const BrandIcon(size: 38),
        ),
        const SizedBox(height: 10),
        Text(Config.brand, style: T.h(17, c: Colors.white)),
        const SizedBox(height: 2),
        Text(cfg.s('general.tagline', 'الوكيل المعتمد لعدّة كوفيكس'), textAlign: TextAlign.center, style: T.b(12, c: Colors.white.withValues(alpha: 0.5))),
        const SizedBox(height: 18),
        Row(children: [
          btn(Icons.chat_rounded, 'واتساب', () => openWhatsApp('مرحباً ${Config.brand}', number: Config.whatsappSupport), wa: true),
          const SizedBox(width: 10),
          btn(Icons.call_rounded, Config.pretty(Config.phone), () => openUrl('tel:+${Config.phone}')),
        ]),
        if (socials.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final s in socials)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Pressable(
                  onTap: () => openUrl(s.$2),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                    child: Icon(s.$1, size: 19, color: Colors.white),
                  ),
                ),
              ),
          ]),
        ],
        const SizedBox(height: 16),
        Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        const SizedBox(height: 12),
        Text('© ${DateTime.now().year} ${Config.brand} — الوكالة الرسمية في سوريا', textAlign: TextAlign.center, style: T.b(11.5, c: Colors.white.withValues(alpha: 0.4))),
        Text('الإصدار $kAppVersion', style: T.b(10.5, c: Colors.white.withValues(alpha: 0.3))),
      ]),
    );
  }
}
