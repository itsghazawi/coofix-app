import 'package:flutter/material.dart';

import 'config.dart';

/// Icon keys selectable in the control panel.
const Map<String, IconData> kIcons = {
  'battery': Icons.battery_charging_full_rounded,
  'bolt': Icons.bolt_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'air': Icons.air_rounded,
  'handyman': Icons.handyman_rounded,
  'extension': Icons.extension_rounded,
  'construction': Icons.construction_rounded,
  'build': Icons.build_circle_rounded,
  'shield': Icons.shield_rounded,
  'verified': Icons.verified_rounded,
  'handshake': Icons.handshake_rounded,
  'truck': Icons.local_shipping_rounded,
  'storefront': Icons.storefront_rounded,
  'support': Icons.support_agent_rounded,
  'star': Icons.star_rounded,
  'percent': Icons.percent_rounded,
  'gift': Icons.card_giftcard_rounded,
  'flash': Icons.flash_on_rounded,
  'garden': Icons.grass_rounded,
  'paint': Icons.format_paint_rounded,
  'water': Icons.water_drop_rounded,
  'measure': Icons.straighten_rounded,
  'safety': Icons.health_and_safety_rounded,
  'home': Icons.home_rounded,
  'phone': Icons.call_rounded,
  'chat': Icons.chat_rounded,
  'clock': Icons.schedule_rounded,
  'location': Icons.location_on_rounded,
  'info': Icons.info_rounded,
};

IconData iconByKey(String? key, [IconData fallback = Icons.construction_rounded]) => kIcons[key] ?? fallback;

IconData categoryIconFor(String slug, [String name = '', int? id]) {
  if (id != null) {
    final k = Cfg.i.map('categories.icons')['$id'];
    if (k != null && kIcons.containsKey(k)) return kIcons[k]!;
  }
  final s = '$slug $name';
  if (s.contains('battery') || slug == 'bt' || s.contains('بطار') || s.contains('شحن')) return Icons.battery_charging_full_rounded;
  if (s.contains('electric') || s.contains('كهرب')) return Icons.bolt_rounded;
  if (s.contains('fuel') || s.contains('وقود') || s.contains('بنزين')) return Icons.local_gas_station_rounded;
  if (s.contains('air') || s.contains('هواء')) return Icons.air_rounded;
  if (s.contains('manual') || s.contains('hand') || s.contains('يدوي')) return Icons.handyman_rounded;
  if (s.contains('access') || s.contains('إكسس') || s.contains('اكسس')) return Icons.extension_rounded;
  return Icons.construction_rounded;
}
