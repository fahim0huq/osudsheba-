// Caregiver alerts are shown in the viewer's language, with the day worked out when shown.
import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/utils/alert_text.dart';

void main() {
  final now = DateTime(2026, 11, 19, 10, 0);

  final fresh = CaregiverAlert(
    id: 'missed_x',
    title: 'Missed Dose: Napa 500mg',
    message: 'Napa 500mg scheduled at 08:00 AM was not marked as taken within an hour.',
    severity: 'High',
    time: 'Today, 08:00 AM',
    kind: 'missed_dose',
    medicineName: 'Napa 500mg',
    scheduledTime: '08:00 AM',
    occurredAt: DateTime(2026, 11, 19, 8, 0),
  );

  test('missed-dose alert in Bangla and English', () {
    expect(alertTitleText(fresh, 'bn'), 'ডোজ মিস হয়েছে: Napa 500mg');
    expect(alertMessageText(fresh, 'bn'), contains('এক ঘণ্টার মধ্যে'));
    expect(alertTimeText(fresh, 'bn', now), 'আজ, 08:00 AM');
    expect(alertSeverityText(fresh, 'bn'), 'জরুরি');
    expect(alertTitleText(fresh, 'en'), 'Missed dose: Napa 500mg');
    expect(alertTimeText(fresh, 'en', now), 'Today, 08:00 AM');
  });

  test('"Today" becomes "Yesterday" and then a date as days pass', () {
    expect(alertTimeText(fresh, 'en', DateTime(2026, 11, 20, 9)), 'Yesterday, 08:00 AM');
    expect(alertTimeText(fresh, 'bn', DateTime(2026, 11, 22, 9)), '১৯/১১/২০২৬, 08:00 AM');
  });

  test('alerts saved before this change are read back from their id and English text', () {
    final old = CaregiverAlert(
      id: 'missed_missed_m1_2026-11-18T21:00:00.000',
      title: 'Missed Dose: Seclo 20mg',
      message: 'Seclo 20mg scheduled at 09:00 PM was not marked as taken within an hour.',
      severity: 'High',
      time: 'Today, 09:00 PM',
    );
    expect(alertTitleText(old, 'bn'), 'ডোজ মিস হয়েছে: Seclo 20mg');
    expect(alertTimeText(old, 'bn', now), 'গতকাল, 09:00 PM');
    expect(alertMessageText(old, 'en'), 'Seclo 20mg due at 09:00 PM was not marked as taken within an hour.');
  });

  test('no-medicines alert and unknown alerts', () {
    final none = CaregiverAlert(
        id: 'no_medicines_alert', title: 'No Medicines Active', message: 'x', severity: 'Medium', time: 'Just now');
    expect(alertTitleText(none, 'bn'), 'কোনো চালু ওষুধ নেই');
    expect(alertTimeText(none, 'bn', now), ''); // old alerts said "Just now" forever
    final other = CaregiverAlert(id: 'a1', title: 'Hello', message: 'World', severity: 'Low', time: '9:00 AM');
    expect(alertTitleText(other, 'bn'), 'Hello');
    expect(alertTimeText(other, 'bn', now), '9:00 AM');
  });

  test('new fields survive saving and loading', () {
    final back = CaregiverAlert.fromJson(fresh.toJson());
    expect(back.kind, 'missed_dose');
    expect(back.scheduledTime, '08:00 AM');
    expect(back.occurredAt, fresh.occurredAt);
  });
}
