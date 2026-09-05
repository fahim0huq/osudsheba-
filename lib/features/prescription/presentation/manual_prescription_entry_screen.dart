import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class ManualPrescriptionEntryScreen extends ConsumerStatefulWidget {
  const ManualPrescriptionEntryScreen({super.key});

  @override
  ConsumerState<ManualPrescriptionEntryScreen> createState() => _ManualPrescriptionEntryScreenState();
}

class _ManualPrescriptionEntryScreenState extends ConsumerState<ManualPrescriptionEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorController = TextEditingController();
  final _medNameController = TextEditingController();
  final _strengthController = TextEditingController(text: '500mg');
  final _doseController = TextEditingController(text: '1 Tablet');
  final _durationController = TextEditingController(text: '7 days');
  final _instructionController = TextEditingController();

  DateTime _prescriptionDate = DateTime.now();
  String _selectedFrequency = 'twice';
  String _selectedMealRelation = 'After Meal';

  @override
  void dispose() {
    _doctorController.dispose();
    _medNameController.dispose();
    _strengthController.dispose();
    _doseController.dispose();
    _durationController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _prescriptionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _prescriptionDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    final title = lang == 'bn' ? 'প্রেসক্রিপশন এন্ট্রি' : 'Manual Entry';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10.0),
                FadeSlideIn(
                  child: Text(
                    lang == 'bn' ? 'প্রেসক্রিপশন এন্ট্রি ফর্ম' : 'Prescription Entry Form',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                  ),
                ),
                const SizedBox(height: 24.0),

                // Doctor Name
                FadeSlideIn(
                  delay: const Duration(milliseconds: 100),
                  child: TextFormField(
                    controller: _doctorController,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'ডাক্তারের নাম' : 'Doctor Name',
                      prefixIcon: const Icon(Icons.person_pin_rounded, color: AppColors.primary),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 16.0),

                // Date Picker Button Styled Modernly
                FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        '${lang == 'bn' ? 'প্রেসক্রিপশনের তারিখ' : 'Prescription Date'}: ',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 14.5),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: _selectDate,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          '${_prescriptionDate.day}/${_prescriptionDate.month}/${_prescriptionDate.year}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20.0),

                const Divider(color: AppColors.border),
                const SizedBox(height: 20.0),

                // Medicine Name
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: TextFormField(
                    controller: _medNameController,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'ওষুধের নাম' : 'Medicine Name',
                      prefixIcon: const Icon(Icons.medication_rounded, color: AppColors.primary),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 16.0),

                // Strength
                FadeSlideIn(
                  delay: const Duration(milliseconds: 250),
                  child: TextFormField(
                    controller: _strengthController,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'মাত্রা (Strength)' : 'Strength',
                      prefixIcon: const Icon(Icons.star_rounded, color: AppColors.primary),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 16.0),

                // Dose
                FadeSlideIn(
                  delay: const Duration(milliseconds: 300),
                  child: TextFormField(
                    controller: _doseController,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'ওষুধের ডোজ' : 'Dose Amount',
                      prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.primary),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 16.0),

                // Meal Relation
                FadeSlideIn(
                  delay: const Duration(milliseconds: 350),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedMealRelation,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'খাবারের আগে/পরে' : 'Meal Relation',
                      prefixIcon: const Icon(Icons.restaurant_rounded, color: AppColors.primary),
                    ),
                    items: ['Before Meal', 'After Meal', 'With Meal', 'None']
                        .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedMealRelation = val;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16.0),

                // Frequency
                FadeSlideIn(
                  delay: const Duration(milliseconds: 400),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedFrequency,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'ওষুধ খাওয়ার ফ্রিকোয়েন্সি' : 'Frequency',
                      prefixIcon: const Icon(Icons.repeat_rounded, color: AppColors.primary),
                    ),
                    items: [
                      DropdownMenuItem(value: 'once', child: Text(lang == 'bn' ? 'দিনে একবার' : 'Once daily')),
                      DropdownMenuItem(value: 'twice', child: Text(lang == 'bn' ? 'দিনে দুইবার' : 'Twice daily')),
                      DropdownMenuItem(value: 'three times', child: Text(lang == 'bn' ? 'দিনে তিনবার' : 'Three times daily')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedFrequency = val;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16.0),

                // Duration
                FadeSlideIn(
                  delay: const Duration(milliseconds: 450),
                  child: TextFormField(
                    controller: _durationController,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'মেয়াদ কাল' : 'Duration (e.g. 7 days)',
                      prefixIcon: const Icon(Icons.timelapse_rounded, color: AppColors.primary),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 16.0),

                // Instructions
                FadeSlideIn(
                  delay: const Duration(milliseconds: 500),
                  child: TextFormField(
                    controller: _instructionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'বিশেষ নির্দেশনা' : 'Special Instructions',
                      prefixIcon: const Icon(Icons.note_alt_rounded, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 36.0),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 550),
                  child: AppPrimaryButton(
                    text: lang == 'bn' ? 'সূচিতে যোগ করুন' : 'Add to Schedule',
                    icon: Icons.add_circle_outline_rounded,
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        List<String> reminderTimes = ['08:00 AM'];
                        if (_selectedFrequency == 'twice') {
                          reminderTimes = ['08:00 AM', '08:00 PM'];
                        } else if (_selectedFrequency == 'three times') {
                          reminderTimes = ['08:00 AM', '02:00 PM', '08:00 PM'];
                        }

                        final newMed = Medicine(
                          id: Random().nextInt(2000).toString(),
                          name: _medNameController.text,
                          strength: _strengthController.text,
                          form: MedicineForm.tablet,
                          dose: _doseController.text,
                          times: reminderTimes,
                          mealRelation: _selectedMealRelation,
                          instruction: 'Dr. ${_doctorController.text}: ${_instructionController.text}',
                          status: 'Pending',
                        );

                        ref.read(medicinesProvider.notifier).addMedicine(newMed);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(lang == 'bn' ? 'সূচি আপডেট করা হয়েছে' : 'Schedule updated successfully!'),
                            backgroundColor: AppColors.success,
                          ),
                        );

                        context.go('/home');
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
