import 'dart:convert';
import 'dart:typed_data';

import 'package:coofix_price/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Settings.load();
  });
  test('utf8 csv with header, quotes, thousands, BOM', () {
    final csv = '﻿الاسم,السعر,الباركود\r\nمثقب 850 واط,"1,249.50",6291041500213\r\n"منشار, دائري",\$75,012345678905\r\nشي خربان,abc,111\r\nبدون باركود,5,\r\nمخرب,3,6.29104E+12\r\n';
    final r = importFile('a.csv', Uint8List.fromList(utf8.encode(csv)));
    expect(r.products.length, 2);
    expect(r.products[0].price, 1249.5);
    expect(r.products[1].name, 'منشار, دائري');
    expect(r.skipped, 3);
    expect(r.scientific, 1);
    expect(fmtPrice(1249.5), '\$1,249.50');
    expect(fmtPrice(1234567), '\$1,234,567.00');
  });
  test('cp1256 + semicolon', () {
    final bytes = Uint8List.fromList([0xE3, 0xCB, 0xDE, 0xC8, ...';12.5;123456'.codeUnits, 13, 10]);
    final r = importFile('b.csv', bytes);
    expect(r.products.single.name, 'مثقب');
    expect(r.products.single.price, 12.5);
  });
}
