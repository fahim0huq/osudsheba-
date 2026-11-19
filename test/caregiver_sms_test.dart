// SMS reminders a caregiver sends from their own SIM: number check and message text.
import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/utils/caregiver_sms.dart';

void main() {
  test('accepts Bangladeshi mobile numbers in the usual ways people type them', () {
    expect(normalizeBdMobile('01712345678'), '01712345678');
    expect(normalizeBdMobile('017 1234-5678'), '01712345678');
    expect(normalizeBdMobile('+8801712345678'), '01712345678');
    expect(normalizeBdMobile('8801712345678'), '01712345678');
    expect(normalizeBdMobile('০১৭১২৩৪৫৬৭৮'), '01712345678');
  });

  test('rejects numbers that are not Bangladeshi mobiles', () {
    expect(normalizeBdMobile(''), isNull);
    expect(normalizeBdMobile('0171234567'), isNull); // too short
    expect(normalizeBdMobile('01212345678'), isNull); // no 012 operator
    expect(normalizeBdMobile('029876543'), isNull); // landline
  });

  test('the SMS says it is from OsudSheba and who sent it', () {
    expect(caregiverSmsBody(message: 'ওষুধ খেয়ে নিন।', fromName: 'Rafi', bn: true), 'ওষুধসেবা: ওষুধ খেয়ে নিন। — Rafi');
    expect(caregiverSmsBody(message: 'Take your medicine.', fromName: ' ', bn: false), 'OsudSheba: Take your medicine.');
  });
}
