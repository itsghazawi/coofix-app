import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'data/config.dart';

/// Coofix brand palette — values come from the control panel (brand.*).
class C {
  static Color get ink => Cfg.i.color('brand.dark', const Color(0xFF061922));
  static Color get inkLight => Cfg.i.color('brand.dark_light', const Color(0xFF0F3041));
  static Color get bg => Cfg.i.color('brand.background', const Color(0xFFF4F3F0));
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE6E3DD);
  static const muted = Color(0xFF8A8F98);
  static Color get text => Cfg.i.color('brand.text', const Color(0xFF15181D));
  static Color get accent => Cfg.i.color('brand.primary', const Color(0xFFFAA21B));
  static Color get accent2 => Cfg.i.color('brand.primary_light', const Color(0xFFFFC14F));
  static Color get accentDeep => Cfg.i.color('brand.primary_deep', const Color(0xFFE08A00));
  static const green = Color(0xFF25D366); // WhatsApp

  /// Text colour that reads well on top of [c].
  static Color on(Color c) => c.computeLuminance() > 0.45 ? ink : Colors.white;

  static LinearGradient get accentGrad => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [accent2, accent, accentDeep],
      );
  static LinearGradient get inkGrad => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [inkLight, ink],
      );

  static double get radius => Cfg.i.d('brand.corner_radius', 24).clamp(0, 40).toDouble();
}

class T {
  static const display = 'Alexandria';
  static const body = 'Plex';

  static TextStyle h(double size, {FontWeight w = FontWeight.w700, Color? c, double height = 1.25}) =>
      TextStyle(
        fontFamily: display,
        fontSize: size,
        color: c ?? C.text,
        height: height,
        fontWeight: w,
        fontVariations: [FontVariation('wght', w.value.toDouble())],
      );

  static TextStyle b(double size, {FontWeight w = FontWeight.w400, Color? c, double height = 1.5}) =>
      TextStyle(fontFamily: body, fontSize: size, color: c ?? C.text, fontWeight: w, height: height);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: T.body,
    scaffoldBackgroundColor: C.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.accent,
      primary: C.accent,
      surface: C.bg,
      brightness: Brightness.light,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: C.text,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.ink,
      behavior: SnackBarBehavior.floating,
      contentTextStyle: T.b(14, c: Colors.white, w: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}
