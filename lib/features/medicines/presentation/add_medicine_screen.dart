import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../core/utils/stock.dart';
import 'widgets/add_medicine_parts.dart';
import 'widgets/dates_notes_sheet.dart';
import 'widgets/medicine_form_parts.dart';
import 'widgets/medicine_photo_field.dart';
import 'widgets/when_to_take_card.dart';
import '../../../core/utils/dose_slots.dart';

/// Add Medicine: three friendly blocks (what it is, its type, when to take it) answered
/// mostly by tapping, plus one quiet row for dates and notes. Fits one screen on normal phones.
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

  /// Meal-time slots (the usual case): "1+0+1, after meal" = morning and night after meal.
  Set<DoseSlot> _slots = {DoseSlot.morningAfter, DoseSlot.nightAfter};

  /// "Custom" chosen: exact times for this medicine instead of meal-time slots.
  bool _custom = false;
  List<String> _customTimes = evenlySpacedTimes(4);

  DateTime _startDate = DateTime.now();

  /// null = ongoing (no end date). Previously every manually added medicine silently
  /// stopped reminding after 30 days, which is dangerous for long-term medicines
  /// (blood pressure, diabetes, thyroid...).
  DateTime? _endDate;
  bool _isSaving = false;
  String? _photoPath;

  /// How many the person has now (optional, set in the dates and notes sheet).
  double? _stock;

  @override
  void dispose() {
    _nameController.dispose();
    _strengthController.dispose();
    _doseController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  Future<void> _openDatesNotes(String lang) async {
    final result = await showDatesNotesSheet(
      context,
      DatesNotes(start: _startDate, end: _endDate, note: _instructionController.text, stock: _stock),
      lang,
      _selectedForm,
    );
    if (result == null || !mounted) return;
    setState(() {
      _startDate = result.start;
      _endDate = result.end;
      _instructionController.text = result.note;
      _stock = result.stock;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    final bn = lang == 'bn';

    // On narrow phones or at large text sizes the header stacks and the form scrolls,
    // so nothing gets cramped.
    final stacked = useStackedFormLayout(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F5),
      appBar: AppBar(
        title: Text(bn ? 'নতুন ওষুধ' : 'New medicine'),
        toolbarHeight: 48,
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
                  padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
                  child: FadeSlideIn(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(bn, stacked),
                        const SizedBox(height: 10),
                        WhenToTakeCard(
                          custom: _custom,
                          slots: _slots,
                          slotTimes: ref.watch(appSettingsProvider.select((s) => s.slotTimes)),
                          times: _customTimes,
                          onModeChanged: (c) => setState(() => _custom = c),
                          onSlotsChanged: (v) => setState(() => _slots = v),
                          onTimesChanged: (v) => setState(() => _customTimes = v),
                          lang: lang,
                        ),
                        const SizedBox(height: 10),
                        MoreOptionsRow(
                          summary: datesNotesSummary(
                            DatesNotes(
                              start: _startDate,
                              end: _endDate,
                              note: _instructionController.text,
                              stock: _stock,
                            ),
                            lang,
                            _selectedForm,
                          ),
                          onTap: () => _openDatesNotes(lang),
                          bn: bn,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Always visible, outside the scrolling area.
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 10.0),
                child: AppPrimaryButton(
                  text: bn ? 'ওষুধ যুক্ত করুন' : 'Add medicine',
                  icon: Icons.check_circle_rounded,
                  isLoading: _isSaving,
                  onPressed: () => _save(lang),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Photo, name, strength, dose and type on a soft green card: what the medicine is.
  Widget _header(bool bn, bool stacked) {
    InputDecoration deco(String label, {String? hint}) =>
        compactFieldDecoration(label, hint: hint).copyWith(filled: true, fillColor: Colors.white);
    void setPhoto(String? p) => setState(() => _photoPath = p);
    final name = TextFormField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      decoration: deco(bn ? 'ওষুধের নাম' : 'Medicine name', hint: bn ? 'যেমন: নাপা, সেকলো' : 'e.g. Napa, Seclo')
          .copyWith(
            suffixIcon: stacked ? MedicinePhotoButton(path: _photoPath, onChanged: setPhoto, bn: bn) : null,
          ),
      validator: requiredField,
    );
    final strength = TextFormField(
      controller: _strengthController,
      // Label always on the border (like Dose), so "Strength" is never cut to "Stren..." in the narrow field.
      decoration: deco(bn ? 'মাত্রা' : 'Strength', hint: '500mg').copyWith(floatingLabelBehavior: FloatingLabelBehavior.always),
      validator: requiredField,
    );
    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        name,
        const SizedBox(height: 10),
        pairedFields(
          stacked,
          strength,
          DoseField(controller: _doseController, form: _selectedForm, bn: bn, filled: true),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCCF5E1), Color(0xFFEFFCF6)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stacked)
            fields
          else
            Row(
              children: [
                MedicinePhotoButton(path: _photoPath, onChanged: setPhoto, bn: bn, size: 108),
                const SizedBox(width: 12),
                Expanded(child: fields),
              ],
            ),
          const SizedBox(height: 10),
          MedicineTypeTiles(
            selected: _selectedForm,
            onChanged: (f) => setState(() {
              _doseController.text = doseFieldAfterFormChange(_doseController.text, _selectedForm, f);
              _selectedForm = f;
            }),
            bn: bn,
          ),
        ],
      ),
    );
  }

  void _error(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: AppColors.error));

  void _save(String lang) {
    final bn = lang == 'bn';
    if (!_formKey.currentState!.validate()) return;
    final slots = DoseSlot.values.where(_slots.contains).toList();
    if (_custom ? _customTimes.isEmpty : slots.isEmpty) {
      _error(_custom
          ? (bn ? 'কমপক্ষে একটি সময় দিন' : 'Add at least one time')
          : (bn ? 'সকাল, দুপুর বা রাত: কমপক্ষে একটি বেছে নিন' : 'Choose at least one: morning, noon or night'));
      return;
    }
    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      _error(bn ? 'শেষ তারিখ শুরুর তারিখের পূর্বে হতে পারবে না' : 'End date cannot be before start date');
      return;
    }

    setState(() => _isSaving = true);

    final newMed = Medicine(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      strength: _strengthController.text.trim(),
      form: _selectedForm,
      dose: doseForSave(_doseController.text, _selectedForm),
      // Slot medicines share their slot's time (one reminder per slot); custom ones keep theirs.
      times: _custom ? _customTimes : timesForSlots(slots, ref.read(appSettingsProvider).slotTimes),
      mealRelation: _custom ? 'None' : mealRelationForSlots(slots),
      slots: _custom ? const [] : [for (final s in slots) s.key],
      instruction: _instructionController.text.trim(),
      status: 'active',
      startDate: _startDate,
      endDate: _endDate,
      createdAt: DateTime.now(),
      photoPath: _photoPath,
      stockCount: tracksStock(_selectedForm) ? _stock : null,
      stockSetAt: tracksStock(_selectedForm) && _stock != null ? DateTime.now() : null,
    );

    ref.read(medicinesProvider.notifier).addMedicine(newMed);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(bn ? 'ওষুধ সফলভাবে যুক্ত করা হয়েছে!' : 'Medicine added successfully!'),
        backgroundColor: AppColors.success,
      ),
    );

    // The Add tab stays alive between visits: start the next medicine from an empty form.
    // (On its own page, opened from a scan, the page closes instead.)
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    _resetForm();
    context.go('/home');
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _strengthController.clear();
    _doseController.text = MedicineForm.tablet.defaultDose;
    _instructionController.clear();
    setState(() {
      _selectedForm = MedicineForm.tablet;
      _slots = {DoseSlot.morningAfter, DoseSlot.nightAfter};
      _customTimes = evenlySpacedTimes(4);
      _custom = false;
      _startDate = DateTime.now();
      _endDate = null;
      _photoPath = null;
      _stock = null;
      _isSaving = false;
    });
  }
}
