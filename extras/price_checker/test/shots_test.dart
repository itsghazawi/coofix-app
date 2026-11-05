// Renders the main screens to PNG for a visual check:
// flutter test --update-goldens test/shots_test.dart
import 'dart:io';

import 'package:coofix_price/admin.dart';
import 'package:coofix_price/data.dart';
import 'package:coofix_price/kiosk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadFonts() async {
  Future<void> fam(String name, List<String> files) async {
    final l = FontLoader(name);
    for (final f in files) {
      l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await l.load();
  }

  await fam('Plex', ['assets/fonts/IBMPlexSansArabic-Regular.ttf', 'assets/fonts/IBMPlexSansArabic-Medium.ttf', 'assets/fonts/IBMPlexSansArabic-SemiBold.ttf', 'assets/fonts/IBMPlexSansArabic-Bold.ttf']);
  await fam('Alexandria', ['assets/fonts/Alexandria.ttf']);
  await fam('MaterialIcons', ['/home/claude/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

Widget app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      theme: ThemeData(useMaterial3: true, fontFamily: 'Plex'),
      home: home,
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Settings.load();
    await loadFonts();
  });

  final sizes = {'phone': const Size(412, 892), 'tab_land': const Size(1280, 800), 'tab_port': const Size(800, 1280)};
  final screens = <String, Widget Function()>{
    'start': () => const StartScreen(),
    'kiosk': () => const KioskHome(),
    'result': () => const ResultScreen(code: '6291041500213', product: Product('6291041500213', 'مثقب كهربائي كوفيكس 850 واط مع حقيبة / CF-01-01', 1249.5)),
    'notfound': () => const ResultScreen(code: '4006381333931', product: null),
    'admin': () => const AdminHome(),
    'search': () => const CodeSearchScreen(),
  };
  for (final s in sizes.entries) {
    for (final e in screens.entries) {
      testWidgets('${e.key}_${s.key}', (t) async {
        t.view.physicalSize = s.value * 2;
        t.view.devicePixelRatio = 2;
        Db.debugSet([
          for (var i = 1; i <= 5; i++) Product('62910415002$i', 'شنيور بطارية كوفيكس 20 فولت / CFA-101-$i', 89.0 + i * 10),
          const Product('6291041500999', 'صاروخ جلخ 115 ملم / CF-02-07', 0.5),
        ]);
        await t.pumpWidget(app(e.value()));
        if (e.key == 'search') {
          await t.enterText(find.byType(TextField), 'cfa-101');
        }
        await t.runAsync(() async {
          for (final el in find.byType(Image).evaluate()) {
            await precacheImage((el.widget as Image).image, el);
          }
        });
        await t.pump(const Duration(milliseconds: 2500));
        await t.pump(const Duration(milliseconds: 100));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/${e.key}_${s.key}.png'));
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 30));
      });
    }
  }
}
