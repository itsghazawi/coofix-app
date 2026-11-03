import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Version of this build — compared against the panel's update settings.
const kAppVersion = '1.4.0';

/// Remote app configuration managed from the WordPress "coofix-app" plugin
/// (GET /wp-json/coofix-app/v1/config). Bundled defaults are used until the
/// first successful fetch; the last fetched copy is cached on the device.
class Cfg {
  Cfg._();
  static final Cfg i = Cfg._();

  static const endpoint = 'https://www.coofix.sy/wp-json/coofix-app/v1/config';

  Map<String, dynamic> _defaults = {};
  Map<String, dynamic> _data = {};
  bool remote = false;

  /// Bumped whenever a new config is applied (the app rebuilds its theme).
  final changes = ValueNotifier<int>(0);

  /// Call before runApp: bundled defaults + cached remote copy.
  Future<void> boot() async {
    try {
      _defaults = jsonDecode(await rootBundle.loadString('assets/config_default.json')) as Map<String, dynamic>;
    } catch (_) {
      _defaults = {};
    }
    _data = _defaults;
    try {
      final p = await SharedPreferences.getInstance();
      final cached = p.getString('cfg_cache');
      if (cached != null) _data = _merge(_defaults, jsonDecode(cached));
    } catch (_) {}
  }

  /// Fetch the latest config from the site.
  Future<void> refresh() async {
    try {
      final r = await http.get(Uri.parse('$endpoint?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}')).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final body = utf8.decode(r.bodyBytes);
        final j = jsonDecode(body);
        if (j is Map<String, dynamic>) {
          _data = _merge(_defaults, j);
          remote = true;
          changes.value++;
          final p = await SharedPreferences.getInstance();
          await p.setString('cfg_cache', body);
        }
      }
    } catch (_) {}
  }

  static dynamic _merge(dynamic base, dynamic over) {
    if (base is Map && over is Map) {
      final out = <String, dynamic>{...base.cast<String, dynamic>()};
      over.forEach((k, v) {
        out['$k'] = out.containsKey('$k') ? _merge(out['$k'], v) : v;
      });
      return out;
    }
    return over ?? base;
  }

  // ---------- typed getters ----------
  dynamic raw(String path) {
    dynamic cur = _data;
    for (final p in path.split('.')) {
      if (cur is Map && cur.containsKey(p)) {
        cur = cur[p];
      } else {
        return null;
      }
    }
    return cur;
  }

  String s(String path, [String def = '']) {
    final v = raw(path);
    return v == null ? def : '$v';
  }

  bool b(String path, [bool def = false]) {
    final v = raw(path);
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == '1' || v == 'true';
    return def;
  }

  double d(String path, [double def = 0]) {
    final v = raw(path);
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? def;
  }

  int n(String path, [int def = 0]) => d(path, def.toDouble()).round();

  List<Map<String, dynamic>> list(String path) {
    final v = raw(path);
    if (v is! List) return [];
    return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  List<String> strings(String path) {
    final v = raw(path);
    if (v is! List) return [];
    return v.map((e) => '$e').where((e) => e.isNotEmpty).toList();
  }

  List<int> ints(String path) {
    final v = raw(path);
    if (v is! List) return [];
    return v.map((e) => int.tryParse('$e') ?? 0).where((e) => e > 0).toList();
  }

  Map<String, String> map(String path) {
    final v = raw(path);
    if (v is! Map) return {};
    return v.map((k, val) => MapEntry('$k', '$val'));
  }

  Color color(String path, Color def) {
    final v = s(path).replaceAll('#', '').trim();
    if (v.length == 6) {
      final n = int.tryParse(v, radix: 16);
      if (n != null) return Color(0xFF000000 | n);
    }
    if (v.length == 3) {
      final x = v.split('').map((c) => '$c$c').join();
      final n = int.tryParse(x, radix: 16);
      if (n != null) return Color(0xFF000000 | n);
    }
    return def;
  }

  /// Sections of the home page, in panel order.
  List<Map<String, dynamic>> get homeSections => list('home.sections');

  Map<String, dynamic>? section(String key) {
    for (final s in homeSections) {
      if (s['key'] == key) return s;
    }
    return null;
  }
}

/// Version comparison: returns <0 if a<b.
int compareVersions(String a, String b) {
  List<int> p(String v) => v.split(RegExp(r'[.+-]')).map((e) => int.tryParse(e) ?? 0).toList();
  final x = p(a), y = p(b);
  for (var i = 0; i < 3; i++) {
    final m = i < x.length ? x[i] : 0, n = i < y.length ? y[i] : 0;
    if (m != n) return m - n;
  }
  return 0;
}
