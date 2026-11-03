import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/store.dart';
import '../screens/categories.dart';
import '../screens/more.dart';
import '../screens/search.dart';
import '../screens/shell.dart';
import 'product_card.dart';

/// Runs a tap action configured in the control panel
/// (banners, announcement bar, popup).
Future<void> runAction(BuildContext context, String type, String value) async {
  final v = value.trim();
  switch (type) {
    case 'category':
      final id = int.tryParse(v);
      final cat = Api.i.categories.where((c) => c.id == id || c.slug == v || c.name == v).firstOrNull;
      if (cat != null) {
        openCategory(context, cat);
      } else {
        Shell.of(context)?.goKey('categories');
      }
    case 'product':
      final p = Api.i.byId(int.tryParse(v) ?? -1);
      if (p != null) openProduct(context, p, tag: 'act');
    case 'search':
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchScreen(initial: v)));
    case 'tab':
      Shell.of(context)?.goKey(v.isEmpty ? 'home' : v);
    case 'whatsapp':
      await openWhatsApp(v.isEmpty ? 'مرحباً ${Config.brand} 👋' : v, number: Config.whatsappSupport);
    case 'phone':
      await openUrl('tel:+${(v.isEmpty ? Config.phone : v).replaceAll(RegExp(r'\D'), '')}');
    case 'url':
      if (v.isNotEmpty) await openUrl(v);
    case 'page':
      final w = switch (v) {
        'warranty' => const WarrantyScreen(),
        'maintenance' => const MaintenanceScreen(),
        _ => const AboutScreen(),
      };
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    default:
      break;
  }
}
