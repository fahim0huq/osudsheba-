import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// The usual Bangladeshi dose patterns as one-tap buttons: morning + noon + night.
const dosePatterns = <String, List<String>>{
  '1+0+0': ['08:00 AM'],
  '0+1+0': ['02:00 PM'],
  '0+0+1': ['08:00 PM'],
  '1+0+1': ['08:00 AM', '08:00 PM'],
  '1+1+1': ['08:00 AM', '02:00 PM', '08:00 PM'],
};

/// The pattern that gives exactly [times], if any.
String? patternForTimes(List<String> times) {
  for (final e in dosePatterns.entries) {
    if (e.value.length == times.length && e.value.every(times.contains)) return e.key;
  }
  return null;
}

/// A row of "1+0+1" style buttons; tapping one sets the reminder times.
class DosePatternChips extends StatelessWidget {
  const DosePatternChips({super.key, required this.times, required this.onSelected, required this.bn});

  final List<String> times;
  final ValueChanged<List<String>> onSelected;
  final bool bn;

  static const _bnDigits = {'0': '০', '1': '১'};

  @override
  Widget build(BuildContext context) {
    final selected = patternForTimes(times);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in dosePatterns.keys)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(
                  bn ? p.split('').map((c) => _bnDigits[c] ?? c).join() : p,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                selected: p == selected,
                selectedColor: AppColors.primaryLight,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onSelected(List.of(dosePatterns[p]!)),
              ),
            ),
        ],
      ),
    );
  }
}
