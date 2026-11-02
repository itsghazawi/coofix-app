import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'icons.dart';

class Config {
  static const site = 'https://www.coofix.sy';
  static const whatsapp = '963955791888';
  static const phoneDisplay = '\u2066+963 955 791 888\u2069';
  static const brand = 'كوفيكس سوريا';
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
    final demo = jsonDecode(await rootBundle.loadString('assets/demo.json')) as Map<String, dynamic>;
    _parse(jsonEncode(demo['products']), jsonEncode(demo['categories']));
  }

  /// The trial store holds only a few items; pad the showcase with sample
  /// catalogue entries so every section looks complete. Remove once the
  /// real catalogue is filled in.
  static const minCatalogue = 8;
  Future<void> _topUpWithDemo() async {
    if (products.length >= minCatalogue) return;
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
    final f = products.where((p) => p.featured).toList();
    return f.isNotEmpty ? f : products.take(8).toList();
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
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }
}
