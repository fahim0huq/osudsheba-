import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/models/subscription.dart';

/// AppsPro `GET /api/v1/sdk/app-info` sends `pricing` as a list of methods and a
/// BDApps-required `disclosure_md` line (https://appspro.dev/docs).
void main() {
  group('AppPricingInfo reads the AppsPro app-info payload', () {
    test('documented shape: price, total with tax, period and disclosure', () {
      final info = AppPricingInfo.fromJson({
        'name': 'OsudSheba',
        'pricing': [
          {
            'method_name': 'bdapps',
            'display_name': 'Robi / Airtel',
            'price': '2.00',
            'price_inclusive': '2.62',
            'billing_period': 'daily',
          },
        ],
        'disclosure_md': '**Tk 2.00 + VAT, SD & SC** per day, auto-renewing.',
        'is_sandbox': false,
      });
      expect(info.amount, '2.00');
      expect(info.amountInclusive, '2.62');
      expect(info.frequency, 'daily');
      expect(info.isFallback, isFalse);
      expect(info.disclosure, 'Tk 2.00 + VAT, SD & SC per day, auto-renewing.');
      expect(info.taxLine(true), contains('৳2.62'));
      expect(info.taxLine(false), 'Total with VAT, SD & SC: ৳2.62 / day');
    });

    test('no tax-inclusive total: generic tax line in both languages', () {
      final info = AppPricingInfo.fromJson({
        'pricing': [
          {'method_name': 'bdapps', 'price': '3.00', 'price_inclusive': null, 'billing_period': 'monthly'},
        ],
        'disclosure_md': null,
      });
      expect(info.amount, '3.00');
      expect(info.amountInclusive, isNull);
      expect(info.disclosure, isNull);
      expect(info.periodLabel(true), 'মাস');
      expect(info.periodLabel(false), 'month');
      expect(info.taxLine(false), '+ VAT, SD & SC applicable');
      expect(info.taxLine(true), '+ ভ্যাট, এসডি ও এসসি প্রযোজ্য');
    });

    test('server fallback (AppsPro unreachable) is flagged', () {
      final info = AppPricingInfo.fromJson({
        'pricing': [
          {'method_name': 'bdapps', 'price': '2.00', 'price_inclusive': null, 'billing_period': 'daily'},
        ],
        'disclosure_md': null,
        'fallback': true,
      });
      expect(info.isFallback, isTrue);
      expect(info.amount, '2.00');
    });

    test('older server builds that send a single pricing object still parse', () {
      final info = AppPricingInfo.fromJson({
        'pricing': {'amount': '2.00', 'currency': 'BDT', 'frequency': 'daily'},
      });
      expect(info.amount, '2.00');
      expect(info.frequency, 'daily');
    });

    test('empty or missing pricing falls back without throwing', () {
      expect(AppPricingInfo.fromJson({'pricing': []}).amount, AppPricingInfo.fallback.amount);
      expect(AppPricingInfo.fromJson({}).frequency, 'daily');
    });
  });
}
