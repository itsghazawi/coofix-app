import 'package:flutter_test/flutter_test.dart';
import 'package:coofix_app/data/models.dart';

void main() {
  test('variable product parses options with codes and prices', () {
    final j = {
      'id': 10, 'name': 'CF-IW006 | فرد شد عزق &#8211; Cordless Impact Wrench', 'sku': '',
      'prices': {'price': '0', 'regular_price': '0', 'currency_minor_unit': 2, 'currency_suffix': ' \$'},
      'attributes': [
        {'name': 'البطارية والشاحن', 'has_variations': true, 'terms': [{'name': 'a'}]},
        {'name': 'الجهد', 'has_variations': false, 'terms': [{'name': '20 فولط'}]},
      ],
      'variations': [
        {'id': 11, 'attributes': [{'name': 'البطارية والشاحن', 'value': 'بدون بطارية وشاحن'}]},
        {'id': 12, 'attributes': [{'name': 'البطارية والشاحن', 'value': 'بطارية واحدة + شاحن'}]},
      ],
      '_variants': {
        '11': {'id': 11, 'sku': 'CF-IW006-0', 'prices': {'price': '0', 'regular_price': '0', 'currency_minor_unit': 2}, 'is_in_stock': true},
        '12': {'id': 12, 'sku': 'CF-IW006', 'prices': {'price': '6950', 'regular_price': '6950', 'currency_minor_unit': 2}, 'is_in_stock': true},
      },
    };
    final p = Product.fromJson(j);
    expect(p.sku, 'CF-IW006');
    expect(p.variants.length, 2);
    expect(p.optionNames, ['البطارية والشاحن']);
    expect(p.specs.map((e) => e.key), ['الجهد']);
    expect(p.defaultVariant!.sku, 'CF-IW006');
    final v = p.forVariant(p.variants.first);
    expect(v.sku, 'CF-IW006-0');
    expect(v.name.contains('بدون بطارية'), true);
    expect(p.forVariant(p.variants[1]).price.price, 69.5);
  });
}
