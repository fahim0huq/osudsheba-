// Launch switches for features that are built but not ready to ship.

/// The "Caregiver" role (a separate profile type with its own dashboard as the home screen).
///
/// Off at launch: there is no syncing between phones yet, so a caregiver using their own
/// phone would see an empty dashboard and wrongly believe the patient's doses are being
/// tracked. With this off, everyone is a Patient; the Family tab, which shows doses taken
/// or missed on *this* phone, stays available. Turn on only once cross-phone sync exists.
const bool kCaregiverRoleEnabled = false;

/// The role the app should act on. Maps a stored "Caregiver" role to "Patient" while the
/// caregiver role is switched off, so users who picked it earlier are not stranded.
String effectiveRole(String role) {
  if (!kCaregiverRoleEnabled && role == 'Caregiver') return 'Patient';
  return role;
}
