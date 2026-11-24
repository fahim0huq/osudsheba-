import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../core/utils/time_utils.dart';
import 'widgets/medicine_form_parts.dart';
import 'widgets/medicine_photo_field.dart';

class EditMedicineScreen extends ConsumerStatefulWidget {
  final Medicine? medicine;

  const EditMedicineScreen({super.key, this.medicine});

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
  bool _missing = false;
  DateTime? _endDate;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    final medList = ref.read(medicinesProvider);
    // Edit only the medicine that was actually selected. (Previously this fell back to the
    // first medicine in the list, or a blank placeholder that was then saved as a new entry.)
    final target = widget.medicine ?? ref.read(selectedMedicineProvider);
    _missing = target == null || !medList.any((m) => m.id == target.id);
    _targetMedicine =
        target ??
        Medicine(
          id: '',
          name: '',
          strength: '',
          form: MedicineForm.tablet,
          dose: '',
          times: const [],
          mealRelation: 'None',
          instruction: '',
        );
    _endDate = _targetMedicine.endDate;
    _photoPath = _targetMedicine.photoPath;

    _nameController = TextEditingController(text: _targetMedicine.name);
    _strengthController = TextEditingController(text: _targetMedicine.strength);
    _doseController = TextEditingController(text: doseFieldText(_targetMedicine.dose, _targetMedicine.form));
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
    final TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time != null) {
      setState(() {
        final formatted = formatTimeOfDay(time.hour, time.minute);
        if (!_reminderTimes.any((t) => sameTimeOfDay(t, formatted))) {
          _reminderTimes.add(formatted);
          _reminderTimes.sort((a, b) => minutesOfDay(a).compareTo(minutesOfDay(b)));
        }
      });
    }
  }

  /// Tapping a time chip: pick a new time for it.
  Future<void> _editReminderTime(String old) async {
    final m = minutesOfDay(old);
    final picked = await showTimePicker(
      context: context,
      initialTime: m < 0 ? TimeOfDay.now() : TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final formatted = formatTimeOfDay(picked.hour, picked.minute);
      _reminderTimes = [..._reminderTimes.where((t) => t != old && !sameTimeOfDay(t, formatted)), formatted]
        ..sort((a, b) => minutesOfDay(a).compareTo(minutesOfDay(b)));
    });
  }

  Future<void> _selectEndDate() async {
    final start = _targetMedicine.startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: start.isBefore(DateTime.now()) ? start : DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;
    final bn = lang == 'bn';

    final title = bn ? 'ওষুধ পরিমার্জন করুন' : 'Edit Medicine';

    if (_missing) {
      return Scaffold(
        appBar: AppBar(title: Text(lang == 'bn' ? 'ওষুধ পাওয়া যায়নি' : 'Medicine not found')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              lang == 'bn'
                  ? 'এই ওষুধটি আর তালিকায় নেই। ওষুধের তালিকা থেকে আবার বেছে নিন।'
                  : 'This medicine is no longer in your list. Please choose it again from your medicines.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18.0),
            ),
          ),
        ),
      );
    }

    // Same compact layout as Add Medicine: fits on one screen on normal phones.
    final stacked = useStackedFormLayout(context);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final ended = _endDate != null && _endDate!.isBefore(today);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 8.0),
                  child: FadeSlideIn(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration:
                              compactFieldDecoration(
                                bn ? 'ওষুধের নাম' : 'Medicine name',
                                icon: Icons.medication_rounded,
                              ).copyWith(
                                suffixIcon: MedicinePhotoButton(
                                  path: _photoPath,
                                  onChanged: (p) => setState(() => _photoPath = p),
                                  bn: bn,
                                ),
                              ),
                          validator: requiredField,
                        ),
                        const SizedBox(height: kFormGap),
                        pairedFields(
                          stacked,
                          TextFormField(
                            controller: _strengthController,
                            decoration: compactFieldDecoration(bn ? 'মাত্রা/পাওয়ার' : 'Strength', hint: 'e.g. 500mg'),
                            validator: requiredField,
                          ),
                          DoseField(controller: _doseController, form: _selectedForm, bn: bn),
                        ),
                        const SizedBox(height: kFormGap),
                        MedicineFormPicker(
                          selected: _selectedForm,
                          onChanged: (f) => setState(() {
                            _doseController.text = doseFieldAfterFormChange(_doseController.text, _selectedForm, f);
                            _selectedForm = f;
                          }),
                          bn: bn,
                          stacked: stacked,
                        ),
                        const SizedBox(height: kFormGap),
                        pairedFields(
                          stacked,
                          MealRelationDropdown(
                            value: _selectedMealRelation,
                            onChanged: (v) => setState(() => _selectedMealRelation = v),
                            bn: bn,
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 52.0),
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                            ),
                            icon: Icon(_endDate == null ? Icons.all_inclusive_rounded : Icons.event_rounded, size: 20),
                            label: Text(
                              _endDate == null
                                  ? (bn ? 'শেষ: চলতে থাকবে' : 'Ends: never')
                                  : '${bn ? 'শেষ' : 'End'} ${shortDate(_endDate!)}',
                            ),
                            onPressed: _selectEndDate,
                          ),
                        ),
                        if (ended)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              bn
                                  ? 'এই ওষুধের শেষ তারিখ পার হয়ে গেছে, তাই অ্যালার্ম বাজছে না।'
                                  : 'This end date has passed, so no alarms ring for this medicine.',
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 15.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (_endDate != null)
                          TextButton.icon(
                            icon: const Icon(Icons.all_inclusive_rounded),
                            label: Text(bn ? 'শেষ তারিখ সরান (চলতে থাকবে)' : 'Remove end date (keep going)'),
                            onPressed: () => setState(() => _endDate = null),
                          ),
                        const SizedBox(height: kFormGap),
                        ReminderTimesRow(
                          times: _reminderTimes,
                          onRemove: (t) => setState(() => _reminderTimes.remove(t)),
                          onAdd: _addReminderTime,
                          onEdit: _editReminderTime,
                          bn: bn,
                        ),
                        const SizedBox(height: kFormGap),
                        TextFormField(
                          controller: _instructionController,
                          decoration: compactFieldDecoration(
                            bn ? 'বিশেষ নির্দেশনা (ঐচ্ছিক)' : 'Special instructions (optional)',
                            hint: 'e.g. Take with warm water',
                            icon: Icons.note_alt_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Always visible, outside the scrolling area.
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 12.0),
                child: AppPrimaryButton(
                  text: bn ? 'পরিবর্তন সংরক্ষণ করুন' : 'Save Changes',
                  icon: Icons.save_rounded,
                  onPressed: () => _save(lang),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save(String lang) {
    if (!_formKey.currentState!.validate()) return;
    if (_reminderTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang == 'bn' ? 'কমপক্ষে একটি অ্যালার্মের সময় দিন' : 'Add at least one reminder time'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final updatedMed = _targetMedicine.copyWith(
      name: _nameController.text.trim(),
      strength: _strengthController.text.trim(),
      form: _selectedForm,
      dose: doseForSave(_doseController.text, _selectedForm),
      times: _reminderTimes,
      mealRelation: _selectedMealRelation,
      instruction: _instructionController.text.trim(),
      endDate: _endDate,
      clearEndDate: _endDate == null,
      photoPath: _photoPath,
      clearPhoto: _photoPath == null,
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
}
