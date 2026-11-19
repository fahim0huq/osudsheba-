import '../models/mock_models.dart';
import '../services/medication_voice_service.dart';

/// The dose as shown on screen, in the viewer's language.
///
/// Doses are saved as typed ("1 Tablet", "2", "5 ml"). In Bangla they are shown as
/// "১টি ট্যাবলেট", "৫ মিলিলিটার সিরাপ"; text that is not a number plus a unit is
/// shown as typed (with Bangla digits). In English a bare number gets its unit
/// ("2" -> "2 tablets"); anything else is shown as typed.
String doseLabel(Medicine m, String lang) {
  final dose = m.dose.trim();
  if (dose.isEmpty) return '';
  if (lang == 'bn') return MedicationVoiceService.formToSpokenUnit(m.form, dose, 'bn');
  final bareNumber = RegExp(r'^([0-9]+(?:[.,/][0-9]+)?|½)$').hasMatch(dose);
  return bareNumber ? MedicationVoiceService.formToSpokenUnit(m.form, dose, 'en') : dose;
}
