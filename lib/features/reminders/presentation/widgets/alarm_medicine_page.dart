import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../core/models/mock_models.dart';
import '../../../../core/utils/dose_text.dart';
import '../../../../core/utils/time_label.dart';

/// The medicine's photo, or a large icon for its type when there is none (or the file is gone).
class MedicinePhoto extends StatelessWidget {
  final Medicine medicine;
  final double height;
  final double radius;
  const MedicinePhoto({super.key, required this.medicine, this.height = 240, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    final path = medicine.photoPath;
    final placeholder = Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(formIcon(medicine.form), size: height * 0.42, color: Colors.white.withValues(alpha: 0.85)),
    );
    if (kIsWeb || path == null || path.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(
        File(path),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

IconData formIcon(MedicineForm form) => switch (form) {
  MedicineForm.syrup => Icons.local_drink_rounded,
  MedicineForm.injection => Icons.vaccines_rounded,
  MedicineForm.drops => Icons.water_drop_rounded,
  _ => Icons.medication_rounded,
};

/// One medicine on the alarm screen: photo, name, how much and when.
class AlarmMedicinePage extends StatelessWidget {
  final Medicine medicine;
  final String lang;
  final bool taken;
  const AlarmMedicinePage({super.key, required this.medicine, required this.lang, required this.taken});

  @override
  Widget build(BuildContext context) {
    final bn = lang == 'bn';
    final m = medicine;
    final how = [doseLabel(m, lang), mealLabel(m.mealRelation, lang)].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, box) {
          final photoHeight = (box.maxHeight * 0.55).clamp(120.0, 300.0);
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    MedicinePhoto(medicine: m, height: photoHeight),
                    if (taken)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xCC047857),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 72),
                              Text(
                                bn ? 'খাওয়া হয়েছে' : 'Taken',
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${m.name} ${m.strength}'.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1.2),
                ),
                if (how.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    how,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ],
                if (m.instruction.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    m.instruction.trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 17),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
