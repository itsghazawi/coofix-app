import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'admin.dart';
import 'data.dart';
import 'kiosk.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.load();
  await Future.wait([Db.load(), Stats.load()]);
  Sfx.init();
  HardwareKeyboard.instance.addHandler(HwScanner.handle);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, systemNavigationBarColor: ink));
  runApp(const PriceApp());
}

class PriceApp extends StatelessWidget {
  const PriceApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'كاشف الأسعار',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Plex',
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: amber, primary: amberDeep, surface: bg),
      ),
      navigatorKey: navKey,
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => AdminGuard.touch(),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        ),
      ),
      home: const StartScreen(),
    );
  }
}
