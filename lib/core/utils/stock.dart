import 'dart:math' as math;
import '../models/mock_models.dart';
import 'time_label.dart';

/// Medicine stock: how much is left, when it runs out, and how much to buy.
///
/// Stock is saved as a count at a moment ([Medicine.stockCount] at [Medicine.stockSetAt]).
/// What is left is that count minus the doses marked taken since then, so undoing a dose
/// puts it back and nothing has to be changed on every tap.

/// Drops are not counted (nobody counts drops in a bottle).
bool tracksStock(MedicineForm f) => f != MedicineForm.drops;

/// Counted in ml (syrup, injection) rather than in pieces.
bool countsInMl(MedicineForm f) => f == MedicineForm.syrup || f == MedicineForm.injection;

/// Units used by one dose, read from the saved dose text: "1 Tablet" -> 1, "½ Tablet" -> 0.5,
/// "1/2" -> 0.5, "5ml" -> 5, "২টি" -> 2. Anything unreadable counts as 1.
double doseAmount(String dose) {
  var d = dose.trim().replaceAll('½', '0.5').replaceAll(',', '.');
  const bnDigits = '০১২৩৪৫৬৭৮৯';
  for (var i = 0; i < 10; i++) {
    d = d.replaceAll(bnDigits[i], '$i');
  }
  final frac = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(d);
  if (frac != null) {
    final den = int.parse(frac.group(2)!);
    if (den > 0) return int.parse(frac.group(1)!) / den;
  }
  final n = double.tryParse(RegExp(r'\d+(?:\.\d+)?').firstMatch(d)?.group(0) ?? '');
  return n == null || n <= 0 ? 1 : n;
}

class StockStatus {
  const StockStatus({
    required this.left,
    required this.perDay,
    required this.daysLeft,
    required this.runsOutOn,
    required this.low,
    required this.empty,
    required this.courseEndsFirst,
  });

  /// Units left now.
  final double left;

  /// Units used per day (0 when paused or no times).
  final double perDay;

  /// Whole days the stock lasts; null when nothing is used per day.
  final int? daysLeft;
  final DateTime? runsOutOn;

  /// Time to buy: runs out within the alert window and the course does not end first.
  final bool low;

  /// Not enough left for one more dose.
  final bool empty;

  /// The course's end date comes before the stock runs out: nothing to buy.
  final bool courseEndsFirst;

  bool get needsBuying => low || (empty && !courseEndsFirst);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Stock of [m] now, or null when stock is not tracked for it.
StockStatus? stockStatus(Medicine m, List<DoseLog> logs, DateTime now, {int alertDays = 5}) {
  final count = m.stockCount;
  if (count == null || !tracksStock(m.form)) return null;
  final amount = doseAmount(m.dose);
  final since = m.stockSetAt;
  final takenSince = logs.where(
    (l) =>
        l.medicineId == m.id &&
        (l.status == 'taken' || l.status == 'late') &&
        l.actualTime != null &&
        (since == null || l.actualTime!.isAfter(since)),
  );
  final left = math.max(0.0, count - takenSince.length * amount);
  final active = m.status.toLowerCase() == 'active';
  final perDay = active ? m.times.length * amount : 0.0;
  final daysLeft = perDay > 0 ? (left / perDay).floor() : null;
  final today = _day(now);
  final runsOutOn = daysLeft == null ? null : today.add(Duration(days: daysLeft));
  final end = m.endDate == null ? null : _day(m.endDate!);
  final courseEndsFirst = end != null && runsOutOn != null && !end.isAfter(runsOutOn);
  final empty = left + 1e-9 < amount;
  final low = active && !courseEndsFirst && daysLeft != null && daysLeft <= alertDays;
  return StockStatus(
    left: left,
    perDay: perDay,
    daysLeft: daysLeft,
    runsOutOn: runsOutOn,
    low: low,
    empty: empty,
    courseEndsFirst: courseEndsFirst,
  );
}

/// How much to buy: enough to reach the course's end date, or 30 days for ongoing medicines.
/// Tablets and capsules are rounded up to whole strips of 10.
({double amount, int days}) suggestedPurchase(Medicine m, StockStatus s, DateTime now) {
  if (s.perDay <= 0) return (amount: 0, days: 0);
  var days = 30;
  if (m.endDate != null) days = math.max(1, _day(m.endDate!).difference(_day(now)).inDays + 1);
  var need = math.max(0.0, days * s.perDay - s.left);
  if (!countsInMl(m.form)) need = (need / 10).ceil() * 10.0;
  return (amount: need, days: days);
}

/// "12", "2.5" (no trailing ".0"), in Bangla digits for Bangla.
String amountText(double n, String lang) {
  final t = n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);
  return localDigits(t, lang);
}

/// "12 tablets" / "১২টি ট্যাবলেট" / "100 ml".
String stockUnits(double n, MedicineForm f, String lang) {
  final num = amountText(n, lang);
  if (countsInMl(f)) return '$num ml';
  final bn = lang == 'bn';
  final one = n == 1;
  return switch (f) {
    MedicineForm.capsule => bn ? '$numটি ক্যাপসুল' : '$num ${one ? 'capsule' : 'capsules'}',
    _ => bn ? '$numটি ট্যাবলেট' : '$num ${one ? 'tablet' : 'tablets'}',
  };
}

/// "6 days left" / "আর ৬ দিন চলবে"; "Runs out today"; "Finished".
String daysLeftText(StockStatus s, String lang) {
  final bn = lang == 'bn';
  if (s.empty) return bn ? 'শেষ হয়ে গেছে' : 'Finished';
  final d = s.daysLeft;
  if (d == null) return bn ? 'এখন খাওয়া বন্ধ' : 'Not in use now';
  if (d == 0) return bn ? 'আজই শেষ হবে' : 'Runs out today';
  return bn ? 'আর ${localDigits(d, lang)} দিন চলবে' : '$d ${d == 1 ? 'day' : 'days'} left';
}

/// When to remind about buying (10 AM each day): from the day stock gets low (runs out within
/// [alertDays]) until the day it runs out, or for two more days once it has run out. At most
/// [maxReminders]; today only if it is not yet 10 AM. Nothing when the course ends first.
List<DateTime> refillReminderTimes(StockStatus s, DateTime now, {int alertDays = 5, int maxReminders = 7}) {
  final out = s.runsOutOn;
  if (out == null || s.courseEndsFirst || s.perDay <= 0) return const [];
  final today = _day(now);
  final first = out.subtract(Duration(days: alertDays));
  var day = first.isAfter(today) ? first : today;
  final last = out.isAfter(today) ? out : today.add(const Duration(days: 2));
  final times = <DateTime>[];
  while (!day.isAfter(last) && times.length < maxReminders) {
    final at = DateTime(day.year, day.month, day.day, 10);
    if (at.isAfter(now)) times.add(at);
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return times;
}

/// Title and text of the buy reminder shown on [at] for medicine [m].
({String title, String body}) refillNoticeText(Medicine m, StockStatus s, DateTime at, String lang) {
  final bn = lang == 'bn';
  final name = '${m.name} ${m.strength}'.trim();
  final days = s.runsOutOn == null ? 0 : s.runsOutOn!.difference(_day(at)).inDays;
  if (days <= 0) {
    return bn
        ? (title: '$name শেষ হয়ে যাচ্ছে', body: 'আজই কিনে নিন, যাতে কোনো ডোজ বাদ না পড়ে।')
        : (title: '$name is running out', body: 'Buy it today so you do not miss a dose.');
  }
  return bn
      ? (
          title: 'ওষুধ কিনতে হবে: $name',
          body: 'আর প্রায় ${localDigits(days, lang)} দিনের ওষুধ আছে। শেষ হওয়ার আগে কিনে নিন।',
        )
      : (
          title: 'Time to buy $name',
          body: 'About $days ${days == 1 ? 'day' : 'days'} left. Buy more before it runs out.',
        );
}
