class Category {
  final int id;
  final String name;
  final String slug;
  final int parent;
  final int count;
  final String? image;

  Category({required this.id, required this.name, required this.slug, this.parent = 0, this.count = 0, this.image});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as int,
        name: _clean(j['name']?.toString() ?? ''),
        slug: j['slug']?.toString() ?? '',
        parent: (j['parent'] ?? 0) as int,
        count: (j['count'] ?? 0) as int,
        image: (j['image'] is Map) ? (j['image']['src'] as String?) : null,
      );
}

class Price {
  final num price;
  final num regular;
  final String symbol;
  final String prefix;
  final String suffix;
  final String thousands;

  const Price({required this.price, required this.regular, this.symbol = 'ل.س', this.prefix = '', this.suffix = ' ل.س', this.thousands = '.'});

  bool get onSale => regular > price && price > 0;
  int get discountPct => onSale ? (((regular - price) / regular) * 100).round() : 0;

  /// Currency label override from the control panel.
  static String labelOverride = '';
  String get unit => labelOverride.isNotEmpty ? labelOverride : (prefix.isNotEmpty ? prefix : suffix).trim();

  String num_(num v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(thousands);
      b.write(s[i]);
    }
    return b.toString();
  }

  String fmt(num v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(thousands);
      b.write(s[i]);
    }
    if (labelOverride.isNotEmpty) return '$b $labelOverride';
    return '$prefix$b$suffix'.trim();
  }

  factory Price.fromJson(Map<String, dynamic> p) {
    final mu = (p['currency_minor_unit'] ?? 0) as int;
    num parse(dynamic v) {
      final n = num.tryParse(v?.toString() ?? '') ?? 0;
      return n / _pow10(mu);
    }

    final prefix = (p['currency_prefix'] ?? '').toString();
    final suffix = (p['currency_suffix'] ?? '').toString();
    final sym = (p['currency_symbol'] ?? '').toString();
    final hasAffix = prefix.isNotEmpty || suffix.isNotEmpty;
    return Price(
      price: parse(p['price']),
      regular: parse(p['regular_price']),
      symbol: sym,
      prefix: hasAffix ? _clean(prefix) : '',
      suffix: hasAffix ? _clean(suffix) : ' $sym',
      thousands: (p['currency_thousand_separator'] ?? '.').toString(),
    );
  }
}

class Product {
  final int id;
  final String name;
  final String shortDesc;
  final String desc;
  final Price price;
  final List<String> images;
  final List<Category> categories;
  final bool inStock;
  final String sku;
  final String permalink;
  final List<MapEntry<String, String>> specs;
  final bool featured;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.shortDesc = '',
    this.desc = '',
    this.images = const [],
    this.categories = const [],
    this.inStock = true,
    this.sku = '',
    this.permalink = '',
    this.specs = const [],
    this.featured = false,
  });

  String? get cover => images.isEmpty ? null : images.first;

  Product copyWith({List<Category>? categories}) => Product(
        id: id, name: name, price: price, shortDesc: shortDesc, desc: desc, images: images,
        categories: categories ?? this.categories, inStock: inStock, sku: sku, permalink: permalink, specs: specs, featured: featured);

  /// Attributes plus any "name: value" lines written in the description.
  List<MapEntry<String, String>> specsWith({bool parseDescription = true}) {
    final out = [...specs];
    if (!parseDescription) return out;
    final seen = out.map((e) => e.key).toSet();
    for (final line in '$shortDesc\n$desc'.split('\n')) {
      final m = RegExp(r'^\s*[•\-\*]?\s*([^:：]{2,40})\s*[:：]\s*(.{1,80})$').firstMatch(line);
      if (m == null) continue;
      final k = m.group(1)!.trim(), v = m.group(2)!.trim();
      if (k.isEmpty || v.isEmpty || seen.contains(k)) continue;
      seen.add(k);
      out.add(MapEntry(k, v));
    }
    return out;
  }

  /// Description with the "name: value" spec lines removed (they show in the table).
  String aboutWithoutSpecs(String text) => text
      .split('\n')
      .where((l) => !RegExp(r'^\s*[•\-\*]?\s*[^:：]{2,40}\s*[:：]\s*.{1,80}$').hasMatch(l))
      .join('\n')
      .trim();
  String get categoryName => categories.isEmpty ? '' : categories.first.name;

  factory Product.fromJson(Map<String, dynamic> j) {
    final imgs = <String>[];
    for (final i in (j['images'] as List? ?? [])) {
      final s = (i is Map) ? (i['src'] ?? i['thumbnail']) : i;
      if (s is String && s.isNotEmpty) imgs.add(s);
    }
    final specs = <MapEntry<String, String>>[];
    for (final a in (j['attributes'] as List? ?? [])) {
      if (a is Map) {
        final terms = (a['terms'] as List? ?? []).map((t) => t is Map ? t['name'] : t).join('، ');
        if (terms.isNotEmpty) specs.add(MapEntry(_clean(a['name'].toString()), _clean(terms)));
      }
    }
    for (final s in (j['specs'] as List? ?? [])) {
      if (s is List && s.length == 2) specs.add(MapEntry(s[0].toString(), s[1].toString()));
    }
    var name = _clean(j['name']?.toString() ?? '');
    var sku = j['sku']?.toString() ?? '';
    final bar = name.indexOf('|');
    if (bar > 0) {
      final code = name.substring(0, bar).trim();
      if (sku.isEmpty) sku = code;
      name = name.substring(bar + 1).trim();
    }
    return Product(
      id: j['id'] as int,
      name: name,
      shortDesc: _strip(j['short_description']?.toString() ?? ''),
      desc: _strip(j['description']?.toString() ?? ''),
      price: Price.fromJson((j['prices'] as Map?)?.cast<String, dynamic>() ?? {}),
      images: imgs,
      categories: (j['categories'] as List? ?? []).map((c) => Category.fromJson((c as Map).cast<String, dynamic>())).toList(),
      inStock: (j['is_in_stock'] ?? true) as bool,
      sku: sku,
      permalink: j['permalink']?.toString() ?? '',
      specs: specs,
      featured: (j['featured'] ?? false) as bool,
    );
  }
}

num _pow10(int n) {
  num r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

String _clean(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&#8211;', '–')
    .replaceAll('&#8217;', '’')
    .replaceAll('&quot;', '"')
    .replaceAll('&nbsp;', ' ')
    .replaceAll(RegExp(r'&#\d+;'), '')
    .trim();

String _strip(String html) {
  final noTags = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|li|h\d)>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  return _clean(noTags).replaceAll(RegExp(r'\n\s*\n+'), '\n').trim();
}
