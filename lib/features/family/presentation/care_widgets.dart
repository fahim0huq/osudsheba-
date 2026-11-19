import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/utils/care_view.dart';
import '../../../core/utils/dose_text.dart';

/// Display pieces for the caregiver's view of one person (care_person_screen.dart).

String bnDigits(String s, bool bn) =>
    bn ? s.split('').map((c) => '0123456789'.contains(c) ? '০১২৩৪৫৬৭৮৯'['0123456789'.indexOf(c)] : c).join() : s;

String timeLabel(String slot, bool bn) => bnDigits(slot.replaceFirst(RegExp(r'^0'), ''), bn);

class CareSection extends StatelessWidget {
  const CareSection({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// "What to take now": the doses due now, or the next one coming up.
class NowCard extends StatelessWidget {
  const NowCard({super.key, required this.doses, required this.bn});
  final List<DayDose> doses;
  final bool bn;

  @override
  Widget build(BuildContext context) {
    final due = doses.where((d) => d.state == DoseState.dueNow).toList();
    final next = doses.where((d) => d.state == DoseState.upcoming).firstOrNull;
    final hasDue = due.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasDue ? AppColors.warning.withValues(alpha: 0.10) : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (hasDue ? AppColors.warning : AppColors.primary).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasDue ? (bn ? 'এখন খাওয়ার সময়' : 'Due now') : (bn ? 'এখন কিছু খাওয়ার নেই' : 'Nothing due now'),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: hasDue ? AppColors.textPrimary : AppColors.primaryDark),
          ),
          const SizedBox(height: 6),
          if (hasDue)
            for (final d in due) _line(d)
          else if (next != null)
            Text(
              '${bn ? 'পরের ডোজ' : 'Next'}: ${timeLabel(next.slot, bn)} · ${next.medicine.name} ${next.medicine.strength}'.trim(),
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            )
          else
            Text(bn ? 'আজকের সব ডোজ শেষ।' : 'No more doses today.', style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  Widget _line(DayDose d) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '${timeLabel(d.slot, bn)} · ${d.medicine.name} ${d.medicine.strength} · ${doseLabel(d.medicine, bn ? 'bn' : 'en')}',
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      );
}

/// One of today's doses: time, medicine, and a coloured state chip.
class DoseRow extends StatelessWidget {
  const DoseRow({super.key, required this.dose, required this.bn});
  final DayDose dose;
  final bool bn;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (dose.state) {
      DoseState.taken => (bn ? 'খেয়েছেন' : 'Taken', AppColors.success, Icons.check_circle_rounded),
      DoseState.skipped => (bn ? 'বাদ' : 'Skipped', AppColors.textSecondary, Icons.remove_circle_outline_rounded),
      DoseState.missed => (bn ? 'মিস' : 'Missed', AppColors.error, Icons.cancel_rounded),
      DoseState.dueNow => (bn ? 'এখন' : 'Due now', AppColors.warning, Icons.alarm_rounded),
      DoseState.upcoming => (bn ? 'পরে' : 'Later', AppColors.textSecondary, Icons.schedule_rounded),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(timeLabel(dose.slot, bn), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Expanded(
            child: Text('${dose.medicine.name} ${dose.medicine.strength}'.trim(),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5)),
          ),
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13.5)),
        ],
      ),
    );
  }
}

/// Last 7 days: a small box per day with the taken percentage.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.values, required this.now, required this.bn});
  final List<int?> values;
  final DateTime now;
  final bool bn;

  @override
  Widget build(BuildContext context) {
    const daysEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const daysBn = ['সো', 'ম', 'বু', 'বৃ', 'শু', 'শ', 'র'];
    return Row(
      children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Builder(builder: (context) {
              final v = values[i];
              final day = now.subtract(Duration(days: values.length - 1 - i));
              final color = v == null
                  ? AppColors.border
                  : v >= 90
                      ? AppColors.success
                      : v >= 50
                          ? AppColors.warning
                          : AppColors.error;
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: color.withValues(alpha: v == null ? 0.4 : 0.18), borderRadius: BorderRadius.circular(8)),
                    child: Text(v == null ? '–' : bnDigits('$v', bn),
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: v == null ? AppColors.textSecondary : color)),
                  ),
                  const SizedBox(height: 2),
                  Text((bn ? daysBn : daysEn)[day.weekday - 1], style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              );
            }),
          ),
      ],
    );
  }
}

class MedicineLine extends StatelessWidget {
  const MedicineLine({super.key, required this.medicine, required this.bn});
  final Medicine medicine;
  final bool bn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(medicine.form.icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${medicine.name} ${medicine.strength} · ${doseLabel(medicine, bn ? 'bn' : 'en')}'.trim(),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5)),
          ),
          Text(medicine.times.map((t) => timeLabel(t, bn)).join(', '),
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
