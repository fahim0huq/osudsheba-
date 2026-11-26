import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/dose_slots.dart';
import '../../../../core/utils/time_label.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../shared/widgets/tap_area.dart';
import 'add_medicine_parts.dart';
import 'medicine_form_parts.dart';

/// "When to take", shared by Add and Edit Medicine.
///
/// - **Meal times** (the usual case): tick Morning / Noon / Night x Before / After meal, like
///   a prescription's "1+0+1, after meal". Each slot has one clock time for ALL medicines (set
///   in Reminder settings), so the person gets one reminder per slot, not one per medicine.
/// - **Custom**: exact times for this medicine (every 4 hours, 6 or 8 times a day, any time).
class WhenToTakeCard extends StatelessWidget {
  const WhenToTakeCard({
    super.key,
    required this.custom,
    required this.slots,
    required this.slotTimes,
    required this.times,
    required this.onModeChanged,
    required this.onSlotsChanged,
    required this.onTimesChanged,
    required this.lang,
  });

  final bool custom;
  final Set<DoseSlot> slots;
  final Map<String, String> slotTimes;
  final List<String> times;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<Set<DoseSlot>> onSlotsChanged;
  final ValueChanged<List<String>> onTimesChanged;
  final String lang;

  bool get _bn => lang == 'bn';

  List<String> _sorted(Iterable<String> t) =>
      t.toList()..sort((a, b) => minutesOfDay(a).compareTo(minutesOfDay(b)));

  Future<void> _add(BuildContext context) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked == null) return;
    final t = formatTimeOfDay(picked.hour, picked.minute);
    if (!times.any((x) => sameTimeOfDay(x, t))) onTimesChanged(_sorted([...times, t]));
  }

  Future<void> _edit(BuildContext context, String old) async {
    final m = minutesOfDay(old);
    final picked = await showTimePicker(
      context: context,
      initialTime: m < 0 ? TimeOfDay.now() : TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked == null) return;
    final t = formatTimeOfDay(picked.hour, picked.minute);
    onTimesChanged(_sorted([...times.where((x) => x != old && !sameTimeOfDay(x, t)), t]));
  }

  @override
  Widget build(BuildContext context) {
    final bn = _bn;
    return FormCard(
      title: bn ? 'কখন খাবেন' : 'When to take',
      icon: Icons.alarm_rounded,
      // Small settings icon: change the clock times of morning / noon / night.
      trailing: SizedBox(
        width: 36,
        height: 24,
        child: IconButton(
          tooltip: bn ? 'খাবারের সময় বদলান' : 'Change meal times',
          padding: EdgeInsets.zero,
          iconSize: 22,
          style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.padded),
          icon: const Icon(Icons.settings_rounded, color: AppColors.textSecondary),
          onPressed: () => context.push('/meal-times'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoicePills(choices: [
            PillChoice(
              bn ? 'খাবারের সময়' : 'Meal times',
              selected: !custom,
              semantics: bn ? 'সকাল, দুপুর, রাতে খাবারের আগে বা পরে' : 'Morning, noon or night, before or after meal',
              onTap: () => onModeChanged(false),
            ),
            PillChoice(
              bn ? 'নির্দিষ্ট সময়' : 'Custom',
              selected: custom,
              semantics: bn ? 'নিজের মতো সময় দিন' : 'Choose exact times',
              onTap: () => onModeChanged(true),
            ),
          ]),
          const SizedBox(height: 8),
          if (!custom)
            SlotGrid(selected: slots, slotTimes: slotTimes, onChanged: onSlotsChanged, lang: lang)
          else ...[
            ChoicePills(choices: [
              for (final n in const [4, 6, 8])
                PillChoice(
                  bn ? 'দিনে ${localDigits(n, lang)} বার' : '$n× a day',
                  selected: times.length == n && times.join() == evenlySpacedTimes(n).join(),
                  semantics: bn ? 'দিনে ${localDigits(n, lang)} বার, সমান সময় পরপর' : '$n times a day, evenly spaced',
                  onTap: () => onTimesChanged(evenlySpacedTimes(n)),
                ),
            ]),
            const SizedBox(height: 10),
            // Up to four times as tiles; more (6 or 8 a day) as one summary line that opens the
            // tiles in a sheet, so the form still fits on one screen.
            if (times.length <= 4)
              TimeTiles(
                times: times,
                onEdit: (t) => _edit(context, t),
                onRemove: (t) => onTimesChanged([...times]..remove(t)),
                onAdd: () => _add(context),
                lang: lang,
              )
            else
              _TimesSummary(times: times, lang: lang, onChange: () => _openTimesSheet(context)),
          ],
        ],
      ),
    );
  }

  /// All custom times, editable, in a bottom sheet (used when there are more than four).
  Future<void> _openTimesSheet(BuildContext context) async {
    var current = times;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void update(List<String> next) {
            setSheet(() => current = next);
            onTimesChanged(next);
          }

          Future<void> pick(String? old) async {
            final m = old == null ? -1 : minutesOfDay(old);
            final picked = await showTimePicker(
              context: ctx,
              initialTime: m < 0 ? TimeOfDay.now() : TimeOfDay(hour: m ~/ 60, minute: m % 60),
            );
            if (picked == null) return;
            final t = formatTimeOfDay(picked.hour, picked.minute);
            update(_sorted([...current.where((x) => x != old && !sameTimeOfDay(x, t)), t]));
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_bn ? 'সময়গুলো' : 'Times',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  TimeTiles(
                    times: current,
                    onEdit: pick,
                    onRemove: (t) => update([...current]..remove(t)),
                    onAdd: () => pick(null),
                    lang: lang,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "6 times: 6:00 AM, 10:00 AM, ... [Change]" for custom schedules with many times.
class _TimesSummary extends StatelessWidget {
  const _TimesSummary({required this.times, required this.lang, required this.onChange});
  final List<String> times;
  final String lang;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final bn = lang == 'bn';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.softGreen),
      ),
      child: Row(
        children: [
          const Icon(Icons.alarm_rounded, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              times.map((t) => displayTime(t, lang)).join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
            ),
          ),
          TextButton(onPressed: onChange, child: Text(bn ? 'বদলান' : 'Change')),
        ],
      ),
    );
  }
}

/// Morning / Noon / Night (columns) x Before / After meal (rows). Each cell shows its slot's
/// time and toggles that slot.
class SlotGrid extends StatelessWidget {
  const SlotGrid({
    super.key,
    required this.selected,
    required this.slotTimes,
    required this.onChanged,
    required this.lang,
  });

  final Set<DoseSlot> selected;
  final Map<String, String> slotTimes;
  final ValueChanged<Set<DoseSlot>> onChanged;
  final String lang;

  static const _icons = {
    DayPart.morning: Icons.wb_twilight_rounded,
    DayPart.noon: Icons.wb_sunny_rounded,
    DayPart.night: Icons.nights_stay_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final bn = lang == 'bn';
    const rowLabelWidth = 58.0;
    Widget rowLabel(String text) => SizedBox(
          width: rowLabelWidth,
          child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        );

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: rowLabelWidth),
            for (final part in DayPart.values)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_icons[part], size: 16, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(part.label(bn),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (final before in const [true, false]) ...[
          Row(
            children: [
              rowLabel(before ? (bn ? 'খাবারের আগে' : 'Before meal') : (bn ? 'খাবারের পরে' : 'After meal')),
              for (final part in DayPart.values)
                Expanded(child: _cell(DoseSlot.values[part.index * 2 + (before ? 0 : 1)], bn)),
            ],
          ),
          if (before) const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _cell(DoseSlot slot, bool bn) {
    final on = selected.contains(slot);
    final time = displayTime(slotTime(slot, slotTimes), lang);
    // "সকাল ৮:৩০" -> "৮:৩০": the column already says which part of the day.
    final shown = time.replaceFirst(RegExp(r'^\S+\s(?=\S*[0-9০-৯])'), '');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Semantics(
        button: true,
        selected: on,
        label: '${slot.label(bn)}, ${displayTime(slotTime(slot, slotTimes), lang)}',
        excludeSemantics: true,
        child: TapArea(
          onTap: () => onChanged(on ? ({...selected}..remove(slot)) : {...selected, slot}),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 40),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: on ? AppColors.primary : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? AppColors.primary : AppColors.softGreen),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (on) ...[const Icon(Icons.check_rounded, size: 16, color: Colors.white), const SizedBox(width: 3)],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(shown,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: on ? Colors.white : AppColors.primaryDark,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
