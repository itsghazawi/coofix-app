import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'models.dart';
import 'icons.dart';

/// Contact & site settings (from the control panel, with safe fallbacks).
class Config {
  static const site = 'https://www.coofix.sy';
  static String _num(String key) {
    final v = Cfg.i.s('contact.$key').replaceAll(RegExp(r'\D'), '');
    return v.isEmpty ? '963955791888' : v;
  }

  static String get whatsapp => _num('whatsapp_orders');
  static String get whatsappSupport => _num('whatsapp_support');
  static String get whatsappMaintenance => _num('whatsapp_maintenance');
  static String get phone => _num('phone');
  static String pretty(String n) {
    // 963955791888 -> +963 955 791 888 (kept left-to-right inside Arabic text)
    final b = StringBuffer('+');
    for (var i = 0; i < n.length; i++) {
      if (i == 3 || (i > 3 && (i - 3) % 3 == 0)) b.write(' ');
      b.write(n[i]);
    }
    return '\u2066$b\u2069';
  }

  static String get phoneDisplay => pretty(whatsapp);
  static String get brand => Cfg.i.s('general.app_name', 'كوفيكس سوريا');
}

/// Loads catalogue from the WooCommerce Store API (public, read-only),
/// caches it on device, and falls back to bundled demo data offline.
class Api {
  Api._();
  static final Api i = Api._();

  List<Category> categories = [];
  List<Product> products = [];
  bool live = false;

  Future<void> load() async {
    await Future.wait([Cfg.i.refresh(), _loadCatalogue()]);
    _applyPanel();
  }

  Future<void> _loadCatalogue() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await Future.wait([
        http.get(Uri.parse('${Config.site}/wp-json/wc/store/v1/products?per_page=100')),
        http.get(Uri.parse('${Config.site}/wp-json/wc/store/v1/products/categories?per_page=100')),
      ]).timeout(const Duration(seconds: 12));
      if (res[0].statusCode == 200 && res[1].statusCode == 200) {
        final p = utf8.decode(res[0].bodyBytes);
        final c = utf8.decode(res[1].bodyBytes);
        _parse(p, c);
        if (products.isNotEmpty) {
          live = true;
          await _topUpWithDemo();
          await prefs.setString('cache_p', p);
          await prefs.setString('cache_c', c);
          return;
        }
      }
    } catch (_) {}
    final cp = prefs.getString('cache_p');
    final cc = prefs.getString('cache_c');
    if (cp != null && cc != null) {
      _parse(cp, cc);
      if (products.isNotEmpty) {
        await _topUpWithDemo();
        return;
      }
    }
    if (!Cfg.i.b('products.use_demo', true)) {
      products = [];
      categories = [];
      return;
    }
    final demo = jsonDecode(await rootBundle.loadString('assets/demo.json')) as Map<String, dynamic>;
    _parse(jsonEncode(demo['products']), jsonEncode(demo['categories']));
  }

  /// Panel rules: category names/order/hidden, out-of-stock filter.
  List<Product> _allProducts = [];
  void _applyPanel() {
    Price.labelOverride = Cfg.i.s('products.currency_label').trim();
    _allProducts = products;
    if (!Cfg.i.b('products.show_out_of_stock', true)) {
      products = products.where((p) => p.inStock).toList();
    }
    final names = Cfg.i.map('categories.names');
    Category rename(Category c) => names['${c.id}'] == null
        ? c
        : Category(id: c.id, name: names['${c.id}']!, slug: c.slug, parent: c.parent, count: c.count, image: c.image);
    categories = categories.map(rename).toList();
    if (names.isNotEmpty) {
      products = products
          .map((p) => p.categories.any((c) => names.containsKey('${c.id}')) ? p.copyWith(categories: p.categories.map(rename).toList()) : p)
          .toList();
    }
    final hidden = Cfg.i.ints('categories.hidden').toSet();
    categories = categories.where((c) => !hidden.contains(c.id)).toList();
    final order = Cfg.i.ints('categories.order');
    if (order.isNotEmpty) {
      int pos(Category c) {
        final i = order.indexOf(c.id);
        return i < 0 ? 9999 : i;
      }
      final indexed = categories.asMap().entries.toList()
        ..sort((a, b) {
          final d = pos(a.value) - pos(b.value);
          return d != 0 ? d : a.key - b.key;
        });
      categories = indexed.map((e) => e.value).toList();
    }
  }

  /// The trial store holds only a few items; pad the showcase with sample
  /// catalogue entries so every section looks complete. Remove once the
  /// real catalogue is filled in.
  Future<void> _topUpWithDemo() async {
    if (!Cfg.i.b('products.use_demo', true)) return;
    if (products.length >= Cfg.i.n('products.min_catalogue', 8)) return;
    final demo = jsonDecode(await rootBundle.loadString('assets/demo.json')) as Map<String, dynamic>;
    final dCats = (demo['categories'] as List).map((e) => Category.fromJson((e as Map).cast<String, dynamic>())).toList();
    final dProds = (demo['products'] as List).map((e) => Product.fromJson((e as Map).cast<String, dynamic>())).toList();
    final ids = products.map((e) => e.id).toSet();
    // Live categories (as listed by the store, even if products don't carry them yet).
    final liveCats = _allLiveCats;
    // Give uncategorised live products a home: the store's only category, or by keyword.
    final fixed = <Product>[];
    for (final p in products) {
      if (p.categories.isNotEmpty) {
        fixed.add(p);
        continue;
      }
      Category? cat = liveCats.length == 1 ? liveCats.first : null;
      if (cat == null) {
        final n = p.name;
        final slug = (n.contains('شحن') || n.contains('بطارية'))
            ? 'battery'
            : (n.contains('دريل') || n.contains('مثقب') || n.contains('جلاخة') || n.contains('منشار'))
                ? 'electric'
                : null;
        cat = slug == null ? null : dCats.where((c) => c.slug == slug).firstOrNull;
      }
      fixed.add(cat == null
          ? p
          : Product(
              id: p.id, name: p.name, price: p.price, shortDesc: p.shortDesc, desc: p.desc, images: p.images,
              categories: [cat], inStock: p.inStock, sku: p.sku, permalink: p.permalink, specs: p.specs, featured: true));
    }
    // Sample products whose category matches a live one move into it (no duplicate sections).
    Category remap(Category d) {
      final icon = categoryIconFor(d.slug, d.name);
      return liveCats.where((l) => categoryIconFor(l.slug, l.name) == icon).firstOrNull ?? d;
    }
    final remapped = dProds.map((d) => Product(
        id: d.id, name: d.name, price: d.price, shortDesc: d.shortDesc, desc: d.desc, images: d.images,
        categories: d.categories.map(remap).toList(), inStock: d.inStock, sku: d.sku, specs: d.specs, featured: d.featured)).toList();
    dProds
      ..clear()
      ..addAll(remapped);
    products = [...fixed, ...dProds.where((d) => !ids.contains(d.id))];
    final cats = [...liveCats, ...dCats.where((d) => !liveCats.any((c) => c.id == d.id || c.slug == d.slug))];
    categories = cats.where((k) => products.any((p) => p.categories.any((pc) => pc.id == k.id))).toList();
  }

  List<Category> _allLiveCats = [];

  void _parse(String p, String c) {
    products = (jsonDecode(p) as List).map((e) => Product.fromJson((e as Map).cast<String, dynamic>())).toList();
    final cats = (jsonDecode(c) as List).map((e) => Category.fromJson((e as Map).cast<String, dynamic>())).toList();
    _allLiveCats = cats.where((k) => k.slug != 'uncategorized').toList();
    // Show only categories that hold products, skip WooCommerce's default bucket.
    categories = cats
        .where((k) => k.slug != 'uncategorized' && products.any((p) => p.categories.any((pc) => pc.id == k.id)))
        .toList();
  }

  List<Product> byCategory(int id) => products.where((p) => p.categories.any((c) => c.id == id)).toList();

  List<Product> get featured {
    final count = Cfg.i.n('products.featured_count', 8).clamp(1, 60);
    List<Product> l;
    switch (Cfg.i.s('products.featured_mode', 'featured')) {
      case 'manual':
        l = Cfg.i.ints('products.featured_ids').map(byId).whereType<Product>().toList();
      case 'latest':
        l = latest;
      case 'sale':
        l = deals;
      case 'all':
        l = products;
      default:
        l = products.where((p) => p.featured).toList();
    }
    if (l.isEmpty) l = products;
    return l.take(count).toList();
  }

  /// Newest first (Store API ids grow with time); sample items go last.
  List<Product> get latest {
    final l = [...products]..sort((a, b) => b.id.compareTo(a.id));
    return l.take(Cfg.i.n('products.latest_count', 8).clamp(1, 60)).toList();
  }

  List<Product> get deals => products.where((p) => p.price.onSale).toList();

  List<Product> search(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return [];
    return products
        .where((p) =>
            p.name.toLowerCase().contains(s) ||
            p.categoryName.toLowerCase().contains(s) ||
            p.sku.toLowerCase().contains(s) ||
            p.shortDesc.toLowerCase().contains(s))
        .toList();
  }

  Product? byId(int id) {
    for (final p in [...products, ..._allProducts]) {
      if (p.id == id) return p;
    }
    return null;
  }
}
