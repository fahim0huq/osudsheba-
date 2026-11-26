import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/mock_models.dart';
import '../../../../core/services/mock_data_service.dart';
import '../../../../core/services/scan/prescription_text_parser.dart';
import '../../../../core/utils/dose_slots.dart';
import '../../../medicines/presentation/widgets/medicine_form_parts.dart';
import '../../../medicines/presentation/widgets/when_to_take_card.dart';

/// Opens a sheet to fix one scanned medicine. Returns the corrected draft, or null on cancel.
Future<ScanDraft?> editScanDraft(BuildContext context, ScanDraft draft, bool bn) {
  return showModalBottomSheet<ScanDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ScanDraftEditor(draft: draft, bn: bn),
  );
}

class _ScanDraftEditor extends ConsumerStatefulWidget {
  const _ScanDraftEditor({required this.draft, required this.bn});

  final ScanDraft draft;
  final bool bn;

  @override
  ConsumerState<_ScanDraftEditor> createState() => _ScanDraftEditorState();
}

class _ScanDraftEditorState extends ConsumerState<_ScanDraftEditor> {
  final _formKey = GlobalKey<FormState>();
  late final Medicine _m = widget.draft.medicine;
  late final _name = TextEditingController(text: _m.name);
  late final _strength = TextEditingController(text: _m.strength);
  late final _dose = TextEditingController(text: doseFieldText(_m.dose, _m.form));
  late final _days = TextEditingController(
    text: _m.endDate == null || _m.startDate == null ? '' : '${_m.endDate!.difference(_m.startDate!).inDays + 1}',
  );
  late MedicineForm _form = _m.form;
  // Same "When to take" as Add Medicine: meal-time slots, or custom times.
  late bool _custom = _m.slots.isEmpty && _m.times.isNotEmpty;
  late Set<DoseSlot> _slots = slotsFromKeys(_m.slots).toSet();
  late List<String> _customTimes = _custom ? List.of(_m.times) : const [];

  @override
  void dispose() {
    for (final c in [_name, _strength, _dose, _days]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final slots = DoseSlot.values.where(_slots.contains).toList();
    if (_custom ? _customTimes.isEmpty : slots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.bn ? 'কখন খাবেন, অন্তত একটি বেছে নিন' : 'Choose at least one time to take it'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final days = int.tryParse(_days.text.trim());
    final start = _m.startDate ?? DateTime.now();
    final updated = _m.copyWith(
      name: _name.text.trim(),
      strength: _strength.text.trim(),
      form: _form,
      dose: doseForSave(_dose.text, _form),
      times: _custom ? _customTimes : timesForSlots(slots, ref.read(appSettingsProvider).slotTimes),
      mealRelation: _custom ? 'None' : mealRelationForSlots(slots),
      slots: _custom ? const [] : [for (final s in slots) s.key],
      endDate: days == null || days < 1 ? null : start.add(Duration(days: days - 1)),
      clearEndDate: days == null || days < 1,
    );
    Navigator.pop(context, widget.draft.withMedicine(updated, checked: true));
  }

  @override
  Widget build(BuildContext context) {
    final bn = widget.bn;
    final stacked = useStackedFormLayout(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                bn ? 'ওষুধ ঠিক করুন' : 'Fix this medicine',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 12),
              pairedFields(
                stacked,
                TextFormField(
                  controller: _name,
                  decoration: compactFieldDecoration(bn ? 'ওষুধের নাম' : 'Medicine name'),
                  validator: requiredField,
                ),
                TextFormField(
                  controller: _strength,
                  decoration: compactFieldDecoration(bn ? 'শক্তি' : 'Strength', hint: '500 mg'),
                ),
              ),
              const SizedBox(height: 10),
              MedicineFormPicker(
                selected: _form,
                bn: bn,
                stacked: stacked,
                onChanged: (f) => setState(() {
                  _dose.text = doseFieldAfterFormChange(_dose.text, _form, f);
                  _form = f;
                }),
              ),
              const SizedBox(height: 10),
              pairedFields(
                stacked,
                DoseField(controller: _dose, form: _form, bn: bn),
                TextFormField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: compactFieldDecoration(
                    bn ? 'কত দিন' : 'Days',
                    hint: bn ? 'খালি = চলবে' : 'Empty = keeps going',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              WhenToTakeCard(
                custom: _custom,
                slots: _slots,
                slotTimes: ref.watch(appSettingsProvider.select((s) => s.slotTimes)),
                times: _customTimes,
                onModeChanged: (c) => setState(() {
                  _custom = c;
                  if (c && _customTimes.isEmpty) _customTimes = evenlySpacedTimes(4);
                }),
                onSlotsChanged: (v) => setState(() => _slots = v),
                onTimesChanged: (v) => setState(() => _customTimes = v),
                lang: bn ? 'bn' : 'en',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(bn ? 'বাতিল' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(onPressed: _save, child: Text(bn ? 'ঠিক আছে' : 'Done')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
