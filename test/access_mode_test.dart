// Without a subscription, a patient keeps their reminders: only premium screens (and brand-new
// users with nothing saved) go to the subscribe screen.
import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/utils/access_mode.dart';

void main() {
  test('subscribed users go anywhere', () {
    for (final r in ['/home', '/add-medicine', '/caregiver', '/family/invite']) {
      expect(lapsedRedirect(location: r, entitled: true, hasMedicines: false), isNull, reason: r);
    }
  });

  test('lapsed user with medicines keeps reminders and the free screens', () {
    for (final r in ['/home', '/my-medicines', '/medicines', '/medicine-detail', '/dose-action', '/settings',
        '/reminder-settings', '/meal-times', '/adherence', '/refill']) {
      expect(lapsedRedirect(location: r, entitled: false, hasMedicines: true), isNull, reason: r);
    }
  });

  test('lapsed user: adding, editing, scan and family need a subscription', () {
    for (final r in ['/add-medicine', '/new-medicine', '/edit-medicine', '/upload-prescription',
        '/prescription-photo-entry', '/caregiver', '/caregiver-alerts', '/family/invite', '/family/person']) {
      expect(lapsedRedirect(location: r, entitled: false, hasMedicines: true), '/subscription', reason: r);
    }
  });

  test('profile setup is not mistaken for a caregiver screen', () {
    expect(isPremiumRoute('/caregiver-profile-setup'), isFalse);
    expect(isPremiumRoute('/patient-profile-setup'), isFalse);
  });

  test('a new user with no medicines starts at the subscribe screen', () {
    expect(lapsedRedirect(location: '/home', entitled: false, hasMedicines: false), '/subscription');
  });

  test('premium tabs are Add, Scan and Family', () {
    expect(kPremiumTabs, {1, 2, 4});
    expect(keepsFreeAccess(entitled: false, hasMedicines: true), isTrue);
    expect(keepsFreeAccess(entitled: true, hasMedicines: true), isFalse);
  });
}
