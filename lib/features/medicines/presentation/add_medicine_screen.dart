import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../core/utils/time_utils.dart';
import 'widgets/medicine_form_parts.dart';

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
  /// null = ongoing (no end date). Previously every manually added medicine silently
  /// stopped reminding after 30 days, which is dangerous for long-term medicines
  /// (blood pressure, diabetes, thyroid...).
  DateTime? _endDate;
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
        // Store in the app's canonical format. time.format(context) produced "20:30" on
        // phones set to 24-hour time, which the alarm scheduler could not read.
        final formatted = formatTimeOfDay(time.hour, time.minute);
        if (!_reminderTimes.any((t) => sameTimeOfDay(t, formatted))) {
          _reminderTimes.add(formatted);
          _reminderTimes.sort((a, b) => minutesOfDay(a).compareTo(minutesOfDay(b)));
          _syncFrequencyToTimes();
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
      _reminderTimes = [
        ..._reminderTimes.where((t) => t != old && !sameTimeOfDay(t, formatted)),
        formatted,
      ]..sort((a, b) => minutesOfDay(a).compareTo(minutesOfDay(b)));
      _syncFrequencyToTimes();
    });
  }

  /// Keeps "How often" truthful after times are added or removed by hand.
  void _syncFrequencyToTimes() {
    const byCount = {1: 'once', 2: 'twice', 3: 'three times'};
    if (_selectedFrequency == 'custom' && _reminderTimes.length > 3) return;
    _selectedFrequency = byCount[_reminderTimes.length] ?? 'custom';
  }

  void _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      });
    }
  }

  void _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 7)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
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
    final bn = lang == 'bn';

    final title = bn ? 'নতুন ওষুধ যুক্ত করুন' : 'Add Medicine';

    // The whole form fits on one screen on normal phones. Paired fields stack (and the form
    // scrolls) only on narrow phones or at large text sizes, so nothing gets cramped.
    final stacked = useStackedFormLayout(context);

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
                          decoration: compactFieldDecoration(bn ? 'ওষুধের নাম' : 'Medicine name',
                              hint: 'e.g. Napa, Seclo', icon: Icons.medication_rounded),
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
                          _buildFrequencyDropdown(bn),
                        ),
                        if (_selectedFrequency == 'custom') ...[
                          const SizedBox(height: kFormGap),
                          TimesPerDayStepper(
                            count: _reminderTimes.isEmpty ? 1 : _reminderTimes.length,
                            onChanged: (n) => setState(() => _reminderTimes = evenlySpacedTimes(n)),
                            bn: bn,
                          ),
                        ],
                        const SizedBox(height: kFormGap),
                        ReminderTimesRow(
                          times: _reminderTimes,
                          onRemove: (t) => setState(() {
                            _reminderTimes.remove(t);
                            _syncFrequencyToTimes();
                          }),
                          onAdd: _addReminderTime,
                          onEdit: _editReminderTime,
                          bn: bn,
                        ),
                        const SizedBox(height: kFormGap),
                        _buildDates(bn, stacked),
                        const SizedBox(height: kFormGap),
                        TextFormField(
                          controller: _instructionController,
                          decoration: compactFieldDecoration(bn ? 'বিশেষ নির্দেশনা (ঐচ্ছিক)' : 'Special instructions (optional)',
                              hint: 'e.g. Take with warm water', icon: Icons.note_alt_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Always visible, outside the scrolling area.
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 12.0),
                child: _isSaving
                    ? const SizedBox(
                        height: 54.0,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      )
                    : AppPrimaryButton(
                        text: bn ? 'সংরক্ষণ করুন' : 'Save Medicine',
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

  Widget _buildFrequencyDropdown(bool bn) {
    DropdownMenuItem<String> item(String value, String en, String bnText) =>
        DropdownMenuItem(value: value, child: Text(bn ? bnText : en, overflow: TextOverflow.ellipsis));
    return DropdownButtonFormField<String>(
      // Rebuilt when the value changes in code (times added/removed by hand), because
      // initialValue is only read once.
      key: ValueKey(_selectedFrequency),
      isExpanded: true,
      initialValue: _selectedFrequency,
      decoration: compactFieldDecoration(bn ? 'দিনে কতবার' : 'How often'),
      items: [
        item('once', 'Once a day', 'দিনে একবার'),
        item('twice', 'Twice a day', 'দিনে দুইবার'),
        item('three times', '3 times a day', 'দিনে তিনবার'),
        item('custom', 'Custom', 'কাস্টম সময়'),
      ],
      onChanged: (val) {
        if (val == null) return;
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
      },
    );
  }

  Widget _buildDates(bool bn, bool stacked) {
    const fmt = shortDate; // "18 Nov": keeps both buttons on one line
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
    );
    final start = OutlinedButton.icon(
      style: style,
      icon: const Icon(Icons.calendar_today_rounded, size: 20),
      label: Text('${bn ? 'শুরু' : 'Start'} ${fmt(_startDate)}'),
      onPressed: _selectStartDate,
    );
    final end = OutlinedButton.icon(
      style: style,
      icon: Icon(_endDate == null ? Icons.all_inclusive_rounded : Icons.event_rounded, size: 20),
      label: Text(_endDate == null
          ? (bn ? 'শেষ: চলতে থাকবে' : 'Ends: never')
          : '${bn ? 'শেষ' : 'End'} ${fmt(_endDate!)}'),
      onPressed: _selectEndDate,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pairedFields(stacked, start, end),
        if (_endDate != null)
          TextButton.icon(
            icon: const Icon(Icons.all_inclusive_rounded),
            label: Text(bn ? 'শেষ তারিখ সরান (চলতে থাকবে)' : 'Remove end date (keep going)'),
            onPressed: () => setState(() => _endDate = null),
          ),
      ],
    );
  }

  void _save(String lang) {
    if (!_formKey.currentState!.validate()) return;
    if (_reminderTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang == 'bn'
              ? 'কমপক্ষে একটি অ্যালার্মের সময় নির্ধারণ করুন'
              : 'At least one reminder time is required'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_endDate != null && _endDate!.isBefore(_startDate)) {
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
      dose: doseForSave(_doseController.text, _selectedForm),
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
        content: Text(lang == 'bn' ? 'ওষুধ সফলভাবে যুক্ত করা হয়েছে!' : 'Medicine added successfully!'),
        backgroundColor: AppColors.success,
      ),
    );

    context.go('/home');
  }
}
