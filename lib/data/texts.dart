import 'config.dart';

/// Every visible text in the app can be overridden from the control panel
/// (تطبيق كوفيكس ← النصوص). Empty value = keep the default.
String tx(String key, String def) {
  final v = Cfg.i.raw('texts');
  if (v is Map) {
    final o = v[key];
    if (o is String && o.trim().isNotEmpty) return o;
  }
  return def;
}
