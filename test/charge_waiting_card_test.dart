// After the OTP the operator may still be charging: the app waits instead of reporting
// "insufficient balance", and after a while explains what to do without a new OTP.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/features/subscription/presentation/widgets/charge_waiting_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('while waiting: a spinner and no failure wording', (tester) async {
    await tester.pumpWidget(_wrap(ChargeWaitingCard(bn: true, timedOut: false, onCheckAgain: () {}, onUseOtherNumber: () {})));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('নিশ্চিত করছে'), findsOneWidget);
    expect(find.textContaining('পর্যাপ্ত ব্যালেন্স না থাকায়'), findsNothing);
    expect(find.text('আবার দেখুন'), findsNothing);
  });

  testWidgets('after waiting: explains it starts by itself and offers Check again', (tester) async {
    var checks = 0;
    await tester.pumpWidget(_wrap(ChargeWaitingCard(bn: false, timedOut: true, onCheckAgain: () => checks++, onUseOtherNumber: () {})));
    expect(find.textContaining('no new OTP'), findsOneWidget);
    await tester.tap(find.text('Check again'));
    expect(checks, 1);
  });
}
