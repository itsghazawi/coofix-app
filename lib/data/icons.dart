import 'package:flutter/material.dart';

IconData categoryIconFor(String slug, [String name = '']) {
  final s = '$slug $name';
  if (s.contains('battery') || slug == 'bt' || s.contains('بطار') || s.contains('شحن')) return Icons.battery_charging_full_rounded;
  if (s.contains('electric') || s.contains('كهرب')) return Icons.bolt_rounded;
  if (s.contains('fuel') || s.contains('وقود') || s.contains('بنزين')) return Icons.local_gas_station_rounded;
  if (s.contains('air') || s.contains('هواء')) return Icons.air_rounded;
  if (s.contains('manual') || s.contains('hand') || s.contains('يدوي')) return Icons.handyman_rounded;
  if (s.contains('access') || s.contains('إكسس') || s.contains('اكسس')) return Icons.extension_rounded;
  return Icons.construction_rounded;
}

