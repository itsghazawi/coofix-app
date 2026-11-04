import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/config.dart';
import 'screens/splash.dart';
import 'theme.dart';
import 'data/i18n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Lang.load();
  await Cfg.i.boot();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const CoofixApp());
}

class CoofixApp extends StatelessWidget {
  const CoofixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: Lang.code,
      builder: (_, lang, _) => ValueListenableBuilder<int>(
      valueListenable: Cfg.i.changes,
      builder: (_, _, _) => MaterialApp(
      key: ValueKey(lang),
      title: Cfg.i.s('general.app_name', tr('كوفيكس سوريا')),
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),
    ),
    ),
    );
  }
}
