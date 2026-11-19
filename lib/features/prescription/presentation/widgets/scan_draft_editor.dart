import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/mock_models.dart';
import '../../../../core/services/scan/prescription_text_parser.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../medicines/presentation/widgets/medicine_form_parts.dart';
import 'dose_pattern_chips.dart';

/// Opens a sheet to fix one scanned medicine. Returns the corrected draft, or null on cancel.
Future<ScanDraft?> editScanDraft(BuildContext context, ScanDraft draft, bool bn) {
  return showModalBottomSheet<ScanDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ScanDraftEditor(draft: draft, bn: bn),
  );
}

class _ScanDraftEditor extends StatefulWidget {
  const _ScanDraftEditor({required this.draft, required this.bn});

  final ScanDraft draft;
  final bool bn;

  @override
  State<_ScanDraftEditor> createState() => _ScanDraftEditorState();
}

class _ScanDraftEditorState extends State<_ScanDraftEditor> {
  final _formKey = GlobalKey<FormState>();
  late final Medicine _m = widget.draft.medicine;
  late final _name = TextEditingController(text: _m.name);
  late final _strength = TextEditingController(text: _m.strength);
  late final _dose = TextEditingController(text: doseFieldText(_m.dose, _m.form));
  late final _days = TextEditingController(
    text: _m.endDate == null || _m.startDate == null ? '' : '${_m.endDate!.difference(_m.startDate!).inDays + 1}',
  );
  late MedicineForm _form = _m.form;
  late String _meal = _m.mealRelation;
  late final List<String> _times = List.of(_m.times);

  @override
  void dispose() {
    for (final c in [_name, _strength, _dose, _days]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTime(String? current) async {
    final minutes = current == null ? 8 * 60 : minutesOfDay(current);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    final t = formatTimeOfDay(picked.hour, picked.minute);
    setState(() {
      if (current != null) _times.remove(current);
      if (!_times.contains(t)) _times.add(t);
      _times.sort((a, b) => minutesOfDay(a).compareTo(minutesOfDay(b)));
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.bn ? 'অন্তত একটি সময় দিন' : 'Add at least one reminder time'),
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
      mealRelation: _meal,
      times: _times,
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
                MealRelationDropdown(value: _meal, bn: bn, onChanged: (v) => setState(() => _meal = v)),
              ),
              const SizedBox(height: 10),
              DosePatternChips(
                times: _times,
                bn: bn,
                onSelected: (t) => setState(
                  () => _times
                    ..clear()
                    ..addAll(t),
                ),
              ),
              const SizedBox(height: 6),
              ReminderTimesRow(
                times: _times,
                bn: bn,
                onRemove: (t) => setState(() => _times.remove(t)),
                onAdd: () => _pickTime(null),
                onEdit: _pickTime,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _days,
                keyboardType: TextInputType.number,
                decoration: compactFieldDecoration(
                  bn ? 'কত দিন' : 'Days',
                  hint: bn ? 'খালি = চলবে' : 'Empty = keeps going',
                ),
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
