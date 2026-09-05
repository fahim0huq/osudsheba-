import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class EditMedicineScreen extends ConsumerStatefulWidget {
  final Medicine? medicine;

  const EditMedicineScreen({
    super.key,
    this.medicine,
  });

  @override
  ConsumerState<EditMedicineScreen> createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends ConsumerState<EditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _strengthController;
  late TextEditingController _doseController;
  late TextEditingController _instructionController;

  late MedicineForm _selectedForm;
  late String _selectedMealRelation;
  late List<String> _reminderTimes;
  late Medicine _targetMedicine;

  @override
  void initState() {
    super.initState();
    final medList = ref.read(medicinesProvider);
    _targetMedicine = widget.medicine ?? ref.read(selectedMedicineProvider) ?? (medList.isNotEmpty ? medList.first : Medicine(
      id: '0',
      name: '',
      strength: '',
      form: MedicineForm.tablet,
      dose: '1 Tablet',
      times: ['08:00 AM'],
      mealRelation: 'After Meal',
      instruction: '',
    ));

    _nameController = TextEditingController(text: _targetMedicine.name);
    _strengthController = TextEditingController(text: _targetMedicine.strength);
    _doseController = TextEditingController(text: _targetMedicine.dose);
    _instructionController = TextEditingController(text: _targetMedicine.instruction);
    _selectedForm = _targetMedicine.form;
    _selectedMealRelation = _targetMedicine.mealRelation;
    _reminderTimes = List.from(_targetMedicine.times);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _strengthController.dispose();
    _doseController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  void _addReminderTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        _reminderTimes.add(time.format(context));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    final title = lang == 'bn' ? 'ওষুধ পরিমার্জন করুন' : 'Edit Medicine';

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
                // Section: Basic Info
                FadeSlideIn(
                  child: _buildSectionHeader(lang == 'bn' ? 'ওষুধের তথ্য' : 'Basic Info'),
                ),
                const SizedBox(height: 12.0),

                // Name
                FadeSlideIn(
                  delay: const Duration(milliseconds: 100),
                  child: TextFormField(
                    controller: _nameController,
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
                  delay: const Duration(milliseconds: 150),
                  child: TextFormField(
                    controller: _strengthController,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'ওষুধের মাত্রা/পাওয়ার' : 'Strength (e.g. 500mg)',
                      prefixIcon: const Icon(Icons.health_and_safety_rounded, color: AppColors.primary),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 16.0),

                // Form selection
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: Text(
                    lang == 'bn' ? 'ওষুধের ধরন' : 'Medicine Form',
                    style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 8.0),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 250),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: MedicineForm.values.map((form) {
                        final isSelected = _selectedForm == form;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedForm = form;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(form.icon, size: 16, color: isSelected ? Colors.white : AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    form.displayName,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),

                // Section: Schedule
                FadeSlideIn(
                  delay: const Duration(milliseconds: 300),
                  child: _buildSectionHeader(lang == 'bn' ? 'ওষুধ খাওয়ার সূচি' : 'Schedule & Frequency'),
                ),
                const SizedBox(height: 12.0),

                // Dose amount
                FadeSlideIn(
                  delay: const Duration(milliseconds: 350),
                  child: TextFormField(
                    controller: _doseController,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'ওষুধের পরিমাণ' : 'Dose (e.g. 1 Tablet)',
                      prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.primary),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 16.0),

                // Meal relation
                FadeSlideIn(
                  delay: const Duration(milliseconds: 400),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedMealRelation,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'খাবারের সাথে সম্পর্ক' : 'Meal Relation',
                      prefixIcon: const Icon(Icons.restaurant_rounded, color: AppColors.primary),
                    ),
                    items: ['Before Meal', 'After Meal', 'With Meal', 'None']
                        .map((val) => DropdownMenuItem(
                              value: val,
                              child: Text(val),
                            ))
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
                const SizedBox(height: 20.0),

                // Reminder times list
                FadeSlideIn(
                  delay: const Duration(milliseconds: 450),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang == 'bn' ? 'রিমাইন্ডারের সময়সমূহ' : 'Reminder Times',
                        style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      GestureDetector(
                        onTap: _addReminderTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.add_alarm_rounded, color: AppColors.primary, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                lang == 'bn' ? 'সময় যোগ করুন' : 'Add Time',
                                style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 12),
                              )
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 500),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _reminderTimes.map((time) {
                      return Chip(
                        label: Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        deleteIcon: const Icon(Icons.close_rounded, size: 14, color: AppColors.error),
                        onDeleted: () {
                          setState(() {
                            _reminderTimes.remove(time);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24.0),

                // Section: Instructions
                FadeSlideIn(
                  delay: const Duration(milliseconds: 550),
                  child: _buildSectionHeader(lang == 'bn' ? 'বিশেষ নির্দেশনা' : 'Instructions'),
                ),
                const SizedBox(height: 12.0),

                // Instructions
                FadeSlideIn(
                  delay: const Duration(milliseconds: 600),
                  child: TextFormField(
                    controller: _instructionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'বিশেষ নির্দেশনা' : 'Special Instructions',
                      prefixIcon: const Icon(Icons.note_alt_rounded, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 40.0),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 650),
                  child: AppPrimaryButton(
                    text: lang == 'bn' ? 'পরিবর্তন সংরক্ষণ করুন' : 'Save Changes',
                    icon: Icons.save_rounded,
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final updatedMed = _targetMedicine.copyWith(
                          name: _nameController.text,
                          strength: _strengthController.text,
                          form: _selectedForm,
                          dose: _doseController.text,
                          times: _reminderTimes,
                          mealRelation: _selectedMealRelation,
                          instruction: _instructionController.text,
                        );

                        ref.read(medicinesProvider.notifier).updateMedicine(updatedMed);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(lang == 'bn' ? 'পরিবর্তন সংরক্ষণ করা হয়েছে' : 'Changes saved successfully!'),
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

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 4.0),
        Container(
          width: 32,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ],
    );
  }
}
