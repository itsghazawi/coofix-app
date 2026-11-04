import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api.dart';
import '../data/config.dart';
import '../data/store.dart';
import '../theme.dart';
import 'actions.dart';
import 'brand.dart';
import 'ui.dart';
import '../data/i18n.dart';

/// Full-screen notice shown instead of the app while maintenance mode is on.
class MaintenanceModeScreen extends StatelessWidget {
  const MaintenanceModeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.ink,
      body: Container(
        decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -0.3), radius: 1.1, colors: [C.inkLight, C.ink])),
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const BrandIcon(size: 96),
            const SizedBox(height: 28),
            Icon(Icons.construction_rounded, color: C.accent, size: 34),
            const SizedBox(height: 14),
            Text(Cfg.i.s('general.maintenance.title', tr('التطبيق قيد التحديث')), textAlign: TextAlign.center, style: T.h(22, c: Colors.white)),
            const SizedBox(height: 10),
            Text(Cfg.i.s('general.maintenance.message'), textAlign: TextAlign.center, style: T.b(14.5, c: Colors.white.withValues(alpha: 0.65), height: 1.8)),
            const SizedBox(height: 28),
            Pressable(
              onTap: () => openWhatsApp(trf('مرحباً {0} 👋', [Config.brand]), number: Config.whatsappSupport),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(18)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.chat_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(tr('تواصل معنا'), style: T.h(15, c: Colors.white)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Shows the update dialog when the panel asks for it. Returns true if shown.
Future<bool> maybeShowUpdate(BuildContext context) async {
  final cfg = Cfg.i;
  final min = cfg.s('general.update.min_version', '0');
  final latest = cfg.s('general.update.latest_version', '0');
  final mustUpdate = compareVersions(kAppVersion, min) < 0;
  final hasNewer = compareVersions(kAppVersion, latest) < 0;
  if (!mustUpdate && !hasNewer) return false;
  final force = mustUpdate || cfg.b('general.update.force');
  final p = await SharedPreferences.getInstance();
  final skipKey = 'update_skip_$latest';
  if (!force && (p.getBool(skipKey) ?? false)) return false;
  final url = defaultTargetPlatform == TargetPlatform.iOS ? cfg.s('general.update.ios_url') : cfg.s('general.update.android_url');
  if (!context.mounted) return false;
  await showDialog(
    context: context,
    barrierDismissible: !force,
    builder: (c) => PopScope(
      canPop: !force,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: C.accentGrad, shape: BoxShape.circle),
              child: Icon(Icons.system_update_rounded, color: C.ink, size: 32),
            ),
            const SizedBox(height: 16),
            Text(cfg.s('general.update.title', tr('تحديث جديد متوفر')), textAlign: TextAlign.center, style: T.h(19)),
            const SizedBox(height: 8),
            Text(cfg.s('general.update.message'), textAlign: TextAlign.center, style: T.b(14, c: C.muted, height: 1.7)),
            const SizedBox(height: 20),
            if (url.isNotEmpty)
              _Btn(label: tr('تحديث الآن'), onTap: () => openUrl(url)),
            if (!force) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  p.setBool(skipKey, true);
                  Navigator.pop(c);
                },
                child: Text(tr('لاحقاً'), style: T.b(14, c: C.muted, w: FontWeight.w600)),
              ),
            ],
          ]),
        ),
      ),
    ),
  );
  return true;
}

/// One-off (or every launch) promotional popup.
Future<void> maybeShowPopup(BuildContext context) async {
  final cfg = Cfg.i;
  if (!cfg.b('popup.enabled')) return;
  final id = cfg.s('popup.id', 'popup');
  final p = await SharedPreferences.getInstance();
  final key = 'popup_seen_$id';
  if (!cfg.b('popup.every_launch') && (p.getBool(key) ?? false)) return;
  await p.setBool(key, true);
  if (!context.mounted) return;
  final image = cfg.s('popup.image');
  await showDialog(
    context: context,
    builder: (c) => Dialog(
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Stack(children: [
          if (image.isNotEmpty)
            AspectRatio(aspectRatio: 1.25, child: CachedNetworkImage(imageUrl: image, fit: BoxFit.cover, errorWidget: (_, _, _) => const SizedBox()))
          else
            Container(height: 90, decoration: BoxDecoration(gradient: C.inkGrad), child: Center(child: Icon(Icons.local_offer_rounded, color: C.accent, size: 40))),
          PositionedDirectional(
            top: 10,
            end: 10,
            child: Pressable(
              onTap: () => Navigator.pop(c),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(children: [
            Text(cfg.s('popup.title'), textAlign: TextAlign.center, style: T.h(19)),
            if (cfg.s('popup.body').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(cfg.s('popup.body'), textAlign: TextAlign.center, style: T.b(14, c: C.muted, height: 1.7)),
            ],
            if (cfg.s('popup.button').isNotEmpty) ...[
              const SizedBox(height: 18),
              _Btn(
                label: cfg.s('popup.button'),
                onTap: () {
                  Navigator.pop(c);
                  runAction(context, cfg.s('popup.action_type', 'none'), cfg.s('popup.action_value'));
                },
              ),
            ],
          ]),
        ),
      ]),
    ),
  );
}

class _Btn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Pressable(
        scale: 0.97,
        onTap: onTap,
        child: Container(
          height: 52,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(gradient: C.accentGrad, borderRadius: BorderRadius.circular(16)),
          child: Text(label, style: T.h(15, c: C.on(C.accent))),
        ),
      );
}

/// Coloured strip at the top of the home page.
class AnnouncementBar extends StatelessWidget {
  const AnnouncementBar({super.key});
  @override
  Widget build(BuildContext context) {
    final cfg = Cfg.i;
    if (!cfg.b('announcement.enabled') || cfg.s('announcement.text').isEmpty) return const SizedBox.shrink();
    final bg = cfg.color('announcement.bg', C.ink);
    final fg = cfg.color('announcement.fg', Colors.white);
    final type = cfg.s('announcement.action_type', 'none');
    return Pressable(
      scale: 0.98,
      onTap: type == 'none' ? null : () => runAction(context, type, cfg.s('announcement.action_value')),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(Icons.campaign_rounded, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(cfg.s('announcement.text'), style: T.b(13.5, c: fg, w: FontWeight.w600))),
          if (type != 'none') Icon(Icons.chevron_right_rounded, color: fg.withValues(alpha: 0.7)),
        ]),
      ),
    );
  }
}
