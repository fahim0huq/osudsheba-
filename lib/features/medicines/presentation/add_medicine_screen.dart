import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class AddMedicineScreen extends ConsumerStatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  ConsumerState<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends ConsumerState<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _strengthController = TextEditingController();
  final _doseController = TextEditingController(text: '1 Tablet');
  final _instructionController = TextEditingController();

  MedicineForm _selectedForm = MedicineForm.tablet;
  String _selectedMealRelation = 'After Meal';
  String _selectedFrequency = 'twice'; // once, twice, three times, custom
  List<String> _reminderTimes = ['08:00 AM', '08:00 PM'];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _isSaving = false;

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

  void _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  void _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    final title = lang == 'bn' ? 'নতুন ওষুধ যুক্ত করুন' : 'Add Medicine';

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
                // Info Banner
                FadeSlideIn(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    margin: const EdgeInsets.only(bottom: 24.0),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.0),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_rounded, color: AppColors.primary, size: 20.0),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            lang == 'bn'
                                ? 'প্রেসক্রিপশন স্ক্যান অস্পষ্ট হলে বা এআই শনাক্তকরণ ভুল হলে এই ম্যানুয়াল ফর্মটি ব্যবহার করুন।'
                                : 'Use this manual option if the prescription scan is unclear.',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Section: Basic Info
                FadeSlideIn(
                  delay: const Duration(milliseconds: 100),
                  child: _buildSectionHeader(lang == 'bn' ? 'ওষুধের তথ্য' : 'Basic Info'),
                ),
                const SizedBox(height: 12.0),
                
                FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'ওষুধের নাম' : 'Medicine Name',
                      hintText: 'e.g. Napa, Seclo',
                      prefixIcon: const Icon(Icons.medication_rounded, color: AppColors.primary),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 16.0),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: TextFormField(
                    controller: _strengthController,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'ওষুধের মাত্রা/পাওয়ার' : 'Strength (e.g. 500mg)',
                      hintText: 'e.g. 500mg, 20mg',
                      prefixIcon: const Icon(Icons.health_and_safety_rounded, color: AppColors.primary),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 16.0),

                // Form selection (Chips)
                FadeSlideIn(
                  delay: const Duration(milliseconds: 250),
                  child: Text(
                    lang == 'bn' ? 'ওষুধের ধরন' : 'Medicine Form',
                    style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 8.0),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 300),
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

                // Section: Schedule & Intake
                FadeSlideIn(
                  delay: const Duration(milliseconds: 350),
                  child: _buildSectionHeader(lang == 'bn' ? 'ওষুধ খাওয়ার সূচি' : 'Schedule & Frequency'),
                ),
                const SizedBox(height: 12.0),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 400),
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

                FadeSlideIn(
                  delay: const Duration(milliseconds: 450),
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
                const SizedBox(height: 16.0),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 500),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedFrequency,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'দিনের ফ্রিকোয়েন্সি' : 'Frequency',
                      prefixIcon: const Icon(Icons.repeat_rounded, color: AppColors.primary),
                    ),
                    items: [
                      DropdownMenuItem(value: 'once', child: Text(lang == 'bn' ? 'দিনে একবার' : 'Once daily')),
                      DropdownMenuItem(value: 'twice', child: Text(lang == 'bn' ? 'দিনে দুইবার' : 'Twice daily')),
                      DropdownMenuItem(value: 'three times', child: Text(lang == 'bn' ? 'দিনে তিনবার' : 'Three times daily')),
                      DropdownMenuItem(value: 'custom', child: Text(lang == 'bn' ? 'কাস্টম সময়' : 'Custom frequency')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedFrequency = val;
                          if (val == 'once') {
                            _reminderTimes = ['08:00 AM'];
                          } else if (val == 'twice') {
                            _reminderTimes = ['08:00 AM', '08:00 PM'];
                          } else if (val == 'three times') {
                            _reminderTimes = ['08:00 AM', '02:00 PM', '08:00 PM'];
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20.0),

                // Reminder times list
                FadeSlideIn(
                  delay: const Duration(milliseconds: 550),
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
                  delay: const Duration(milliseconds: 600),
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

                // Date selectors styled well
                FadeSlideIn(
                  delay: const Duration(milliseconds: 650),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text('Start: ${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                          onPressed: _selectStartDate,
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text('End: ${_endDate.day}/${_endDate.month}/${_endDate.year}'),
                          onPressed: _selectEndDate,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24.0),

                // Instructions Section
                FadeSlideIn(
                  delay: const Duration(milliseconds: 700),
                  child: _buildSectionHeader(lang == 'bn' ? 'বিশেষ নির্দেশনা' : 'Instructions'),
                ),
                const SizedBox(height: 12.0),
                
                FadeSlideIn(
                  delay: const Duration(milliseconds: 750),
                  child: TextFormField(
                    controller: _instructionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'বিশেষ নির্দেশনা' : 'Special Instructions',
                      prefixIcon: const Icon(Icons.note_alt_rounded, color: AppColors.primary),
                      hintText: 'e.g. Take with warm water',
                    ),
                  ),
                ),
                const SizedBox(height: 40.0),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 800),
                  child: _isSaving
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        )
                      : AppPrimaryButton(
                          text: lang == 'bn' ? 'সংরক্ষণ করুন' : 'Save Medicine',
                          icon: Icons.save_rounded,
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              if (_reminderTimes.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(lang == 'bn'
                                        ? 'কমপক্ষে একটি অ্যালার্মের সময় নির্ধারণ করুন'
                                        : 'At least one reminder time is required'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }

                              if (_endDate.isBefore(_startDate)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(lang == 'bn'
                                        ? 'শেষ তারিখ শুরুর তারিখের পূর্বে হতে পারবে না'
                                        : 'End date cannot be before start date'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }

                              setState(() {
                                _isSaving = true;
                              });

                              final newMed = Medicine(
                                id: const Uuid().v4(),
                                name: _nameController.text,
                                strength: _strengthController.text,
                                form: _selectedForm,
                                dose: _doseController.text,
                                times: _reminderTimes,
                                mealRelation: _selectedMealRelation,
                                instruction: _instructionController.text,
                                status: 'active',
                                startDate: _startDate,
                                endDate: _endDate,
                                createdAt: DateTime.now(),
                              );

                              ref.read(medicinesProvider.notifier).addMedicine(newMed);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(lang == 'bn'
                                      ? 'ওষুধ সফলভাবে যুক্ত করা হয়েছে!'
                                      : 'Medicine added successfully!'),
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
