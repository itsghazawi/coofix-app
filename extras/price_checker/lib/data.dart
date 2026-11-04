import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ================================================================ settings
class Settings {
  static late SharedPreferences _p;

  static Future<void> load() async => _p = await SharedPreferences.getInstance();

  static String _s(String k, String d) => _p.getString(k) ?? d;
  static int _i(String k, int d) => _p.getInt(k) ?? d;
  static bool _b(String k, bool d) => _p.getBool(k) ?? d;

  static String get adminUser => _s('admin_user', 'admin');
  static String get adminPass => _s('admin_pass', 'admin');
  static Future<void> setAdmin(String u, String p) async {
    await _p.setString('admin_user', u);
    await _p.setString('admin_pass', p);
  }

  static String get welcomeTitle => _s('welcome_title', 'أهلاً بك في كوفيكس');
  static String get welcomeSub => _s('welcome_sub', 'اكتشف سعر أي قطعة خلال ثانية');
  static String get buttonLabel => _s('button_label', 'اكشف السعر');
  static String get notFoundTitle => _s('nf_title', 'المنتج غير مسجّل');
  static String get notFoundSub => _s('nf_sub', 'يرجى مراجعة أحد موظفي كوفيكس لمعرفة السعر');

  /// Seconds the price stays on screen before returning home.
  static int get resultSeconds => _i('result_seconds', 20);

  /// Seconds the camera stays open without reading anything (battery saver).
  static int get scanTimeout => _i('scan_timeout', 30);
  static bool get beep => _b('beep', true);
  static bool get vibrate => _b('vibrate', true);
  static bool get frontCamera => _b('front_camera', false);
  static bool get keepAwake => _b('keep_awake', true);
  static bool get hwScanner => _b('hw_scanner', true);
  static bool get showBarcode => _b('show_barcode', true);
  static bool get alwaysCents => _b('always_cents', true);

  static Future<void> set(String k, Object v) async {
    if (v is String) await _p.setString(k, v);
    if (v is int) await _p.setInt(k, v);
    if (v is bool) await _p.setBool(k, v);
  }

  static Future<void> reset(List<String> keys) async {
    for (final k in keys) {
      await _p.remove(k);
    }
  }
}

// ================================================================ products
class Product {
  final String barcode;
  final String name;
  final double price;
  const Product(this.barcode, this.name, this.price);
  List<Object> toJson() => [barcode, name, price];
  static Product fromJson(List j) => Product('${j[0]}', '${j[1]}', (j[2] as num).toDouble());
}

String normBarcode(String s) {
  var v = s.replaceAll(RegExp('[\\s\u200E\u200F\u202A-\u202E]'), '');
  // Arabic-Indic / Persian digits → Latin
  v = v.replaceAllMapped(RegExp('[٠-٩۰-۹]'), (m) {
    final c = m[0]!.codeUnitAt(0);
    return '${c >= 0x06F0 ? c - 0x06F0 : c - 0x0660}';
  });
  if (RegExp(r'^\d+\.0+$').hasMatch(v)) v = v.substring(0, v.indexOf('.'));
  return v;
}

String _short(String b) => b.replaceFirst(RegExp(r'^0+(?=.)'), '');

class Db {
  static final Map<String, Product> _items = {};
  static final Map<String, String> _shortIdx = {};
  static DateTime? updatedAt;
  static String? lastFile;
  static late File _file;

  static int get count => _items.length;
  static List<Product> get all => _items.values.toList();

  static Future<void> load() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/products.json');
    if (!await _file.exists()) return;
    try {
      final j = jsonDecode(await _file.readAsString()) as Map;
      updatedAt = DateTime.tryParse('${j['updated'] ?? ''}');
      lastFile = j['file'] as String?;
      for (final e in (j['items'] as List)) {
        final p = Product.fromJson(e as List);
        _items[p.barcode] = p;
      }
      _reindex();
    } catch (_) {}
  }

  static void _reindex() {
    _shortIdx
      ..clear()
      ..addEntries(_items.keys.map((k) => MapEntry(_short(k), k)));
  }

  static Future<void> _save() async {
    updatedAt = DateTime.now();
    _reindex();
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode({'updated': updatedAt!.toIso8601String(), 'file': lastFile, 'items': _items.values.map((p) => p.toJson()).toList()}));
    await tmp.rename(_file.path);
  }

  static Product? find(String raw) {
    final b = normBarcode(raw);
    if (b.isEmpty) return null;
    final p = _items[b];
    if (p != null) return p;
    // Excel often drops leading zeros (UPC codes) — match ignoring them.
    final k = _shortIdx[_short(b)];
    return k == null ? null : _items[k];
  }

  static Future<void> upsert(Product p, {String? oldBarcode}) async {
    if (oldBarcode != null && oldBarcode != p.barcode) _items.remove(oldBarcode);
    _items[p.barcode] = p;
    await _save();
  }

  static Future<void> remove(String barcode) async {
    _items.remove(barcode);
    await _save();
  }

  static Future<void> clear() async {
    _items.clear();
    lastFile = null;
    await _save();
  }

  /// Returns (added, updated).
  static Future<(int, int)> apply(List<Product> list, {required bool replace, bool addNew = true, String? fileName}) async {
    var added = 0, updated = 0;
    if (replace) _items.clear();
    for (final p in list) {
      final old = replace ? null : find(p.barcode);
      if (old == null) {
        if (!replace && !addNew) continue; // update-only: skip products not already in the list
        added++;
        _items[p.barcode] = p;
      } else {
        if (old.price != p.price || old.name != p.name) updated++;
        _items[old.barcode] = Product(old.barcode, p.name, p.price);
      }
    }
    lastFile = fileName ?? lastFile;
    await _save();
    return (added, updated);
  }

  /// How many of these products are not in the list yet.
  static int countNew(List<Product> list) => list.where((p) => find(p.barcode) == null).length;

  static Future<File> exportCsv() async {
    final dir = await getTemporaryDirectory();
    final d = DateTime.now();
    final f = File('${dir.path}/coofix-prices-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.csv');
    final sb = StringBuffer('﻿');
    String q(String s) => (s.contains(',') || s.contains('"') || s.contains('\n')) ? '"${s.replaceAll('"', '""')}"' : s;
    for (final p in _items.values) {
      // ="..." keeps Excel from turning long barcodes into 6.29E+12
      sb.write('${q(p.name)},${fmtPlain(p.price)},="${p.barcode}"\r\n');
    }
    await f.writeAsString(sb.toString(), encoding: utf8);
    return f;
  }
}

// ================================================================ price format
String _group(int n) {
  final s = n.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

/// ("1,250", "50") — whole part with thousands commas, and cents ("" if hidden).
(String, String) splitPrice(double v, {bool? alwaysCents}) {
  final cents = (v * 100).round();
  final whole = cents ~/ 100, c = cents % 100;
  final show = (alwaysCents ?? Settings.alwaysCents) || c != 0;
  return (_group(whole), show ? c.toString().padLeft(2, '0') : '');
}

String fmtPrice(double v) {
  final (w, c) = splitPrice(v);
  return '\$$w${c.isEmpty ? '' : '.$c'}';
}

String fmtPlain(double v) {
  final cents = (v * 100).round();
  return cents % 100 == 0 ? '${cents ~/ 100}' : (cents / 100).toStringAsFixed(2);
}

// ================================================================ import
class ImportResult {
  final List<Product> products;
  final int skipped;
  final int duplicates;
  final int scientific;
  final List<String> problems;
  final bool headerSkipped;
  ImportResult(this.products, this.skipped, this.duplicates, this.scientific, this.problems, this.headerSkipped);
}

const _cp1256 =
    '€پ‚ƒ„…†‡ˆ‰ٹ‹Œچژڈگ‘’“”•–—ک™ڑ›œ‌‍ں ،¢£¤¥¦§¨©ھ«¬­®¯°±²³´µ¶·¸¹؛»¼½¾؟ہءآأؤإئابةتثجحخدذرزسشصض×طظعغـفقكàلâمنهوçèéêëىيîïًٌٍَôُِ÷ّùْûü‎‏ے';

String decodeText(Uint8List bytes) {
  var data = bytes;
  if (data.length >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF) data = data.sublist(3);
  if (data.length >= 2 && data[0] == 0xFF && data[1] == 0xFE) {
    final u = <int>[];
    for (var i = 2; i + 1 < data.length; i += 2) {
      u.add(data[i] | (data[i + 1] << 8));
    }
    return String.fromCharCodes(u);
  }
  try {
    return utf8.decode(data);
  } catch (_) {
    // Excel "CSV" (not "CSV UTF-8") on Arabic Windows saves as Windows-1256.
    return String.fromCharCodes(data.map((c) => c < 128 ? c : _cp1256.codeUnitAt(c - 128)));
  }
}

List<List<String>> parseCsv(String text) {
  final firstLine = text.split('\n').first;
  String delim = ',';
  final counts = {',': ','.allMatches(firstLine).length, ';': ';'.allMatches(firstLine).length, '\t': '\t'.allMatches(firstLine).length};
  // Prefer ; or tab only when clearly used as the separator.
  if (counts[';']! >= 2 && counts[';']! >= counts[',']!) delim = ';';
  if (counts['\t']! >= 2 && counts['\t']! >= counts[',']!) delim = '\t';

  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQ = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQ) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQ = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      inQ = true;
    } else if (ch == delim) {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

List<List<String>> parseXlsx(Uint8List bytes) {
  final book = xl.Excel.decodeBytes(bytes);
  if (book.tables.isEmpty) return [];
  final sheet = book.tables[book.getDefaultSheet() ?? book.tables.keys.first] ?? book.tables.values.first;
  String cell(xl.Data? d) {
    final v = d?.value;
    if (v == null) return '';
    if (v is xl.IntCellValue) return '${v.value}';
    if (v is xl.DoubleCellValue) {
      final x = v.value;
      return x == x.truncateToDouble() && x.abs() < 1e18 ? x.toInt().toString() : '$x';
    }
    return v.toString();
  }

  return sheet.rows.map((r) => r.map(cell).toList()).toList();
}

double? parsePrice(String s) {
  var v = normBarcode(s).replaceAll(RegExp(r'[\$ ]|USD|usd|دولار'), '').replaceAll('٫', '.').replaceAll('٬', ',');
  v = v.replaceAll(',', '');
  if (v.isEmpty) return null;
  final d = double.tryParse(v);
  if (d == null || d.isNaN || d < 0) return null;
  return d;
}

ImportResult importRows(List<List<String>> rows) {
  final out = <String, Product>{};
  var skipped = 0, dups = 0, sci = 0;
  var header = false;
  final problems = <String>[];
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i].map((e) => e.trim()).toList();
    if (r.every((e) => e.isEmpty)) continue;
    String name = r.isNotEmpty ? r[0] : '';
    final priceS = r.length > 1 ? r[1] : '';
    var bc = r.length > 2 ? r[2] : '';
    if (bc.startsWith('="') && bc.endsWith('"')) bc = bc.substring(2, bc.length - 1);
    bc = normBarcode(bc);
    final price = parsePrice(priceS);
    if (price == null) {
      if (i == 0 || (out.isEmpty && !header)) {
        header = true; // title row: "الاسم, السعر, الباركود"
        continue;
      }
      skipped++;
      if (problems.length < 6) problems.add('السطر ${i + 1}: السعر غير مفهوم «$priceS»');
      continue;
    }
    if (bc.isEmpty) {
      skipped++;
      if (problems.length < 6) problems.add('السطر ${i + 1}: لا يوجد باركود («$name»)');
      continue;
    }
    if (RegExp(r'^\d+(\.\d+)?[eE]\+?\d+$').hasMatch(bc)) {
      sci++;
      skipped++;
      if (problems.length < 6) problems.add('السطر ${i + 1}: الباركود مخرّب من الإكسل «$bc»');
      continue;
    }
    if (name.isEmpty) name = 'منتج $bc';
    if (out.containsKey(bc)) dups++;
    out[bc] = Product(bc, name.replaceAll(RegExp(r'\s+'), ' '), price);
  }
  return ImportResult(out.values.toList(), skipped, dups, sci, problems, header);
}

ImportResult importFile(String name, Uint8List bytes) {
  final lower = name.toLowerCase();
  final isZip = bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;
  if (lower.endsWith('.xlsx') || isZip) return importRows(parseXlsx(bytes));
  if (lower.endsWith('.xls')) throw 'صيغة xls القديمة غير مدعومة، احفظ الملف بصيغة CSV أو xlsx';
  return importRows(parseCsv(decodeText(bytes)));
}

// ================================================================ stats
class Stats {
  static late File _file;
  static Map<String, int> counts = {};
  static Map<String, int> days = {};
  static List<Map<String, dynamic>> recent = [];
  static int total = 0, misses = 0;
  static Timer? _t;

  static String get todayKey {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static int get today => days[todayKey] ?? 0;

  static Future<void> load() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/stats.json');
    if (!await _file.exists()) return;
    try {
      final j = jsonDecode(await _file.readAsString()) as Map;
      counts = (j['counts'] as Map).map((k, v) => MapEntry('$k', (v as num).toInt()));
      days = (j['days'] as Map).map((k, v) => MapEntry('$k', (v as num).toInt()));
      recent = (j['recent'] as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
      total = (j['total'] as num?)?.toInt() ?? 0;
      misses = (j['misses'] as num?)?.toInt() ?? 0;
    } catch (_) {}
  }

  static void hit(String barcode, Product? p) {
    total++;
    days[todayKey] = today + 1;
    if (p == null) {
      misses++;
    } else {
      counts[p.barcode] = (counts[p.barcode] ?? 0) + 1;
    }
    recent.insert(0, {'b': barcode, 't': DateTime.now().millisecondsSinceEpoch, 'f': p != null});
    if (recent.length > 150) recent.removeRange(150, recent.length);
    if (days.length > 120) {
      final keys = days.keys.toList()..sort();
      for (final k in keys.take(days.length - 120)) {
        days.remove(k);
      }
    }
    _t?.cancel();
    _t = Timer(const Duration(seconds: 2), save);
  }

  static Future<void> save() async {
    try {
      await _file.writeAsString(jsonEncode({'counts': counts, 'days': days, 'recent': recent, 'total': total, 'misses': misses}));
    } catch (_) {}
  }

  static Future<void> reset() async {
    counts = {};
    days = {};
    recent = [];
    total = 0;
    misses = 0;
    await save();
  }
}

// ================================================================ sound + device
class Sfx {
  static final _beep = AudioPlayer(), _miss = AudioPlayer();

  static Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build());
      for (final (p, f) in [(_beep, 'sfx/beep.wav'), (_miss, 'sfx/miss.wav')]) {
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource(f));
      }
    } catch (_) {}
  }

  static Future<void> play(bool found) async {
    if (Settings.vibrate) HapticFeedback.mediumImpact();
    if (!Settings.beep) return;
    try {
      final p = found ? _beep : _miss;
      await p.stop();
      await p.resume();
    } catch (_) {}
  }
}

class Device {
  static const _ch = MethodChannel('coofix/kiosk');
  static Future<void> keepAwake(bool on) async {
    try {
      await _ch.invokeMethod('awake', on);
    } catch (_) {}
  }

  static Future<void> applyKiosk() async {
    await keepAwake(Settings.keepAwake);
  }
}
