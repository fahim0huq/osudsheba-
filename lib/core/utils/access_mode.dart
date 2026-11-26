/// What a signed-in user may open without an active subscription.
///
/// A patient whose ৳2 charge failed, or whose subscription lapsed, must never lose their
/// medicine reminders: they keep Home, today's doses, their medicine list, the alarm and
/// settings screens and the report. Adding or changing medicines, Scan and Family stay
/// premium. A brand-new user with no medicines saved has nothing to protect yet, so they
/// still start at the subscribe screen.
library;

/// Screens (and everything under them) that need an active subscription.
const kPremiumRoutes = <String>[
  '/add-medicine',
  '/new-medicine',
  '/edit-medicine',
  '/upload-prescription',
  '/ai-prescription-review',
  '/prescription-photo-entry',
  '/caregiver',
  '/caregiver-invite',
  '/caregiver-patient-detail',
  '/caregiver-alerts',
  '/family',
];

/// The bottom tabs that need a subscription: Add, Scan, Family (Home and Medicines are free).
const kPremiumTabs = <int>{1, 2, 4};

bool isPremiumRoute(String location) =>
    kPremiumRoutes.any((r) => location == r || location.startsWith('$r/'));

/// Without a subscription, a user who already has medicines keeps the free part of the app.
bool keepsFreeAccess({required bool entitled, required bool hasMedicines}) => !entitled && hasMedicines;

/// Where a signed-in user without a subscription goes instead of [location], or null to stay.
String? lapsedRedirect({required String location, required bool entitled, required bool hasMedicines}) {
  if (entitled) return null;
  if (hasMedicines && !isPremiumRoute(location)) return null;
  return '/subscription';
}
