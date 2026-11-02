import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'models.dart';

/// Cart + favourites, persisted on device.
class Store extends ChangeNotifier {
  Store._();
  static final Store i = Store._();

  final Map<int, int> cart = {};
  final Set<int> favs = {};

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    for (final e in p.getStringList('cart') ?? <String>[]) {
      final parts = e.split(':');
      if (parts.length == 2) cart[int.parse(parts[0])] = int.parse(parts[1]);
    }
    favs.addAll((p.getStringList('favs') ?? []).map(int.parse));
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('cart', cart.entries.map((e) => '${e.key}:${e.value}').toList());
    await p.setStringList('favs', favs.map((e) => '$e').toList());
  }

  int get count => cart.values.fold(0, (a, b) => a + b);

  List<MapEntry<Product, int>> get items => cart.entries
      .map((e) => MapEntry(Api.i.byId(e.key), e.value))
      .where((e) => e.key != null)
      .map((e) => MapEntry(e.key!, e.value))
      .toList();

  num get total => items.fold<num>(0, (a, e) => a + e.key.price.price * e.value);

  void add(Product p, [int q = 1]) {
    cart[p.id] = (cart[p.id] ?? 0) + q;
    notifyListeners();
    _save();
  }

  void setQty(Product p, int q) {
    if (q <= 0) {
      cart.remove(p.id);
    } else {
      cart[p.id] = q;
    }
    notifyListeners();
    _save();
  }

  void clear() {
    cart.clear();
    notifyListeners();
    _save();
  }

  bool isFav(Product p) => favs.contains(p.id);

  void toggleFav(Product p) {
    favs.contains(p.id) ? favs.remove(p.id) : favs.add(p.id);
    notifyListeners();
    _save();
  }
}

Future<void> openWhatsApp(String text) async {
  final uri = Uri.parse('https://wa.me/${Config.whatsapp}?text=${Uri.encodeComponent(text)}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> openUrl(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

String orderMessage(List<MapEntry<Product, int>> items, num total, Price? fmt, {String? name, String? city, String? note}) {
  final b = StringBuffer('مرحباً كوفيكس سوريا 👋\nأرغب بطلب المنتجات التالية من التطبيق:\n\n');
  var i = 1;
  for (final e in items) {
    b.writeln('$i) ${e.key.name}');
    if (e.key.sku.isNotEmpty) b.writeln('   الرمز: ${e.key.sku}');
    b.writeln('   الكمية: ${e.value} × ${e.key.price.fmt(e.key.price.price)}');
    i++;
  }
  if (fmt != null) b.writeln('\nالإجمالي التقريبي: ${fmt.fmt(total)}');
  if (name != null && name.isNotEmpty) b.writeln('الاسم: $name');
  if (city != null && city.isNotEmpty) b.writeln('المدينة: $city');
  if (note != null && note.isNotEmpty) b.writeln('ملاحظات: $note');
  b.write('\nشكراً لكم.');
  return b.toString();
}
