import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Coofix brand palette — industrial luxury: graphite + warm signal accent.
class C {
  static const ink = Color(0xFF061922); // Coofix navy
  static const ink2 = Color(0xFF0C2633);
  static const ink3 = Color(0xFF15394A);
  static const bg = Color(0xFFF4F3F0); // warm paper
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE6E3DD);
  static const muted = Color(0xFF8A8F98);
  static const text = Color(0xFF15181D);
  static const accent = Color(0xFFFAA21B); // Coofix amber
  static const accent2 = Color(0xFFFFC14F);
  static const accentDeep = Color(0xFFE08A00);
  static const gold = Color(0xFFD9B26F);
  static const green = Color(0xFF25D366); // WhatsApp

  static const accentGrad = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [accent2, accent, accentDeep],
  );
  static const inkGrad = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0F3041), ink],
  );
}

class T {
  static const display = 'Alexandria';
  static const body = 'Plex';

  static TextStyle h(double size, {FontWeight w = FontWeight.w700, Color c = C.text, double height = 1.25}) =>
      TextStyle(
        fontFamily: display,
        fontSize: size,
        color: c,
        height: height,
        fontWeight: w,
        fontVariations: [FontVariation('wght', w.value.toDouble())],
      );

  static TextStyle b(double size, {FontWeight w = FontWeight.w400, Color c = C.text, double height = 1.5}) =>
      TextStyle(fontFamily: body, fontSize: size, color: c, fontWeight: w, height: height);
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
    appBarTheme: const AppBarTheme(
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
