import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/home_schedule.dart';

/// Doses whose time has passed today but that were not recorded (for example the alarm
/// was dismissed by accident), one compact row per time slot, so they can still be marked.
class OverdueDosesCard extends StatelessWidget {
  final List<DoseSlot> slots;
  final String lang;
  final void Function(DoseSlot slot) onTaken;
  final void Function(DoseSlot slot) onSkip;

  const OverdueDosesCard({
    super.key,
    required this.slots,
    required this.lang,
    required this.onTaken,
    required this.onSkip,
  });

  bool get _bn => lang == 'bn';

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(1.0) > 1.3;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.warning, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: AppColors.warning, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _bn ? 'এই ওষুধ কি খেয়েছেন?' : 'Did you take these?',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          for (final slot in slots) ...[
            const SizedBox(height: 4),
            _row(slot, large),
          ],
        ],
      ),
    );
  }

  Widget _row(DoseSlot slot, bool large) {
    final names = slot.medicines.map((m) => '${m.name} ${m.strength}'.trim()).join(', ');
    final text = Text.rich(
      TextSpan(children: [
        TextSpan(text: '${slot.time}  ', style: const TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: names),
      ]),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
    );
    final take = ElevatedButton(
      onPressed: () => onTaken(slot),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      child: Text(_bn ? 'খেয়েছি' : 'Took it'),
    );
    final skip = OutlinedButton(
      onPressed: () => onSkip(slot),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.textSecondary),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      child: Text(_bn ? 'বাদ দিয়েছি' : 'Skipped'),
    );
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          text,
          const SizedBox(height: 4),
          Row(children: [Expanded(child: take), const SizedBox(width: 8), Expanded(child: skip)]),
        ],
      );
    }
    // The buttons shrink a little rather than overflow when the labels are wide.
    return Row(
      children: [
        Expanded(child: text),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(mainAxisSize: MainAxisSize.min, children: [take, const SizedBox(width: 6), skip]),
          ),
        ),
      ],
    );
  }
}
