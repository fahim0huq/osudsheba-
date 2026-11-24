import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/mock_models.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../shared/widgets/tap_area.dart';

/// Compact building blocks shared by the Add and Edit Medicine forms, sized so the whole
/// form fits on one screen on normal phones (see test/add_medicine_fit_test.dart).

const double kFormGap = 14.0;

/// Paired fields stack (and the form scrolls) on narrow phones or at large text sizes.
bool useStackedFormLayout(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1.0) > 1.3 || MediaQuery.sizeOf(context).width < 340;

/// Compact field style: about 52px tall, still above the 48px touch-target minimum.
InputDecoration compactFieldDecoration(String label, {String? hint, IconData? icon, String? suffix}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixText: suffix,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
    prefixIcon: icon == null ? null : Icon(icon, color: AppColors.primary),
  );
}

String? requiredField(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;

/// "18 Nov", plus the year only when it is not this year.
String shortDate(DateTime d) =>
    DateFormat(d.year == DateTime.now().year ? 'd MMM' : 'd MMM yy').format(d);

/// Two fields side by side, or stacked when there is not enough room.
Widget pairedFields(bool stacked, Widget a, Widget b) {
  if (stacked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [a, const SizedBox(height: kFormGap), b],
    );
  }
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Expanded(child: a), const SizedBox(width: 10.0), Expanded(child: b)],
  );
}

/// The Dose field. For an injection it asks for the amount in ml (number keypad, "ml"
/// shown after the number), like the marks on a syringe. See [doseFieldText] / [doseForSave].
class DoseField extends StatelessWidget {
  const DoseField({super.key, required this.controller, required this.form, required this.bn, this.filled = false});

  final TextEditingController controller;
  final MedicineForm form;
  final bool bn;

  /// White fill, for fields on a coloured card.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final injection = form == MedicineForm.injection;
    return TextFormField(
      controller: controller,
      keyboardType: injection ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: injection ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
      decoration: compactFieldDecoration(
        injection ? (bn ? 'কত ml' : 'Amount') : (bn ? 'পরিমাণ' : 'Dose'),
        hint: injection ? 'e.g. 2' : form.defaultDose,
        suffix: injection ? 'ml' : null,
      ).copyWith(filled: filled ? true : null, fillColor: filled ? Colors.white : null),
      validator: (value) {
        if (requiredField(value) != null) return 'Required';
        if (injection && double.tryParse(value!.trim().replaceAll(',', '.')) == null) {
          return bn ? 'শুধু সংখ্যা লিখুন' : 'Numbers only';
        }
        return null;
      },
    );
  }
}

/// Tablet / Capsule / Syrup / Injection / Drops: all five on one line as equal-width,
/// text-only buttons (a long word shrinks a little rather than wrapping). At large text
/// sizes they wrap, two per line, with their icons.
class MedicineFormPicker extends StatelessWidget {
  const MedicineFormPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.bn,
    required this.stacked,
  });

  final MedicineForm selected;
  final ValueChanged<MedicineForm> onChanged;
  final bool bn;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return LayoutBuilder(builder: (context, constraints) {
        const spacing = 6.0;
        final width = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final form in MedicineForm.values) SizedBox(width: width, child: _option(form, withIcon: true)),
          ],
        );
      });
    }
    return Row(
      children: [
        for (final form in MedicineForm.values) ...[
          if (form != MedicineForm.values.first) const SizedBox(width: 4.0),
          Expanded(child: _option(form, withIcon: false)),
        ],
      ],
    );
  }

  Widget _option(MedicineForm form, {required bool withIcon}) {
    final isSelected = selected == form;
    final color = isSelected ? Colors.white : AppColors.textPrimary;
    final label = Text(
      bn ? form.bnName : form.displayName,
      maxLines: 1,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: withIcon ? 13.0 : 12.5),
    );
    return Semantics(
      button: true,
      selected: isSelected,
      child: TapArea(
        onTap: () => onChanged(form),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 38.0),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: withIcon ? 4.0 : 2.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: withIcon
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(form.icon, size: 15, color: isSelected ? Colors.white : AppColors.primary),
                    const SizedBox(width: 4),
                    Flexible(child: label),
                  ],
                )
              : FittedBox(fit: BoxFit.scaleDown, child: label),
        ),
      ),
    );
  }
}

/// "Before / After / With meal / Any time", shown in Bangla in the Bangla interface.
class MealRelationDropdown extends StatelessWidget {
  const MealRelationDropdown({super.key, required this.value, required this.onChanged, required this.bn});

  final String value;
  final ValueChanged<String> onChanged;
  final bool bn;

  static const _labelsBn = {
    'Before Meal': 'খাবারের আগে',
    'After Meal': 'খাবারের পরে',
    'With Meal': 'খাবারের সাথে',
    'None': 'যে কোনো সময়',
  };

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _labelsBn.containsKey(value) ? value : 'None',
      decoration: compactFieldDecoration(bn ? 'খাবার' : 'Meal'),
      items: _labelsBn.keys
          .map((val) => DropdownMenuItem(
                value: val,
                child: Text(bn ? _labelsBn[val]! : (val == 'None' ? 'Any time' : val),
                    overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }
}

/// [count] reminder times spread over the day: up to 4 between 8 AM and 10 PM (waking
/// hours), more than that evenly round the clock from 6 AM (e.g. every 4 hours).
List<String> evenlySpacedTimes(int count) {
  if (count <= 1) return ['08:00 AM'];
  final List<int> minutes;
  if (count <= 4) {
    const start = 8 * 60, end = 22 * 60;
    minutes = [for (var i = 0; i < count; i++) start + ((end - start) * i / (count - 1) / 30).round() * 30];
  } else {
    final step = 24 * 60 / count;
    minutes = [for (var i = 0; i < count; i++) (6 * 60 + (step * i / 30).round() * 30) % (24 * 60)];
  }
  final times = {for (final m in minutes) formatTimeOfDay(m ~/ 60, m % 60)}.toList();
  times.sort((a, b) => minutesOfDay(a).compareTo(minutesOfDay(b)));
  return times;
}

/// Reminder times as compact chips (tap the time to change it, x to remove it), with a small
/// round "add time" button at the end.
class ReminderTimesRow extends StatelessWidget {
  const ReminderTimesRow({
    super.key,
    required this.times,
    required this.onRemove,
    required this.onAdd,
    required this.onEdit,
    required this.bn,
  });

  final List<String> times;
  final ValueChanged<String> onRemove;
  final VoidCallback onAdd;
  final ValueChanged<String> onEdit;
  final bool bn;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            spacing: 6.0,
            runSpacing: 6.0,
            children: [
              if (times.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(bn ? 'কোনো সময় নেই, + চাপুন' : 'No times yet: tap +',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ),
              for (final time in times)
                _TimeChip(
                  time: time,
                  onEdit: () => onEdit(time),
                  onRemove: () => onRemove(time),
                  bn: bn,
                ),
            ],
          ),
        ),
        const SizedBox(width: 4.0),
        // Looks small (36px) but keeps the standard 48px touch area around it.
        IconButton.filledTonal(
          tooltip: bn ? 'সময় যোগ করুন' : 'Add time',
          icon: const Icon(Icons.add_alarm_rounded, color: AppColors.primaryDark, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primaryLight,
            minimumSize: const Size(36.0, 36.0),
            fixedSize: const Size(36.0, 36.0),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          onPressed: onAdd,
        ),
      ],
    );
  }
}

/// A compact reminder time: just the time and a small x, about 32px tall (no empty
/// space between them as in a standard chip).
class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.time, required this.onEdit, required this.onRemove, required this.bn});

  final String time;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final bool bn;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: '${bn ? 'অ্যালার্ম' : 'Alarm'} $time',
            hint: bn ? 'সময় বদলাতে চাপুন' : 'Tap to change',
            excludeSemantics: true,
            child: InkWell(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 6.0, 2.0, 6.0),
                // "8:00 AM" (no leading zero) keeps three times on one line.
                child: Text(
                  time.replaceFirst(RegExp(r'^0'), ''),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: bn ? 'সময় মুছুন' : 'Remove time',
            excludeSemantics: true,
            child: InkWell(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(2.0, 6.0, 6.0, 6.0),
                child: Icon(Icons.close_rounded, size: 15, color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
