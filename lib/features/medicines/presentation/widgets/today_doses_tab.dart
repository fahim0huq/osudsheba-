import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/services/mock_data_service.dart';
import '../../../../core/utils/dose_text.dart';
import '../../../../core/utils/home_schedule.dart';
import '../../../../core/utils/time_label.dart';
import '../../../home/presentation/dose_recorder.dart';
import 'medicine_actions_sheet.dart';

/// Every dose today, grouped by time. A dose whose time has come has an empty circle:
/// tap it to record it as taken. Later doses show a clock. Tap a row for more actions.
class TodayDosesTab extends ConsumerWidget {
  const TodayDosesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).language;
    final bn = lang == 'bn';
    final now = ref.watch(minuteClockProvider).valueOrNull ?? DateTime.now();
    final doses = todayDoses(medicines: ref.watch(medicinesProvider), logs: ref.watch(doseLogsProvider), now: now);
    if (doses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(bn ? 'আজ কোনো ওষুধের সময় নেই' : 'No medicines scheduled today',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: AppColors.textSecondary)),
        ),
      );
    }
    final nowMinute = now.hour * 60 + now.minute;
    final open = {DoseState.pending, DoseState.missed};
    final nextMinute = doses.where((d) => open.contains(d.state) && d.minute > nowMinute).firstOrNull?.minute;
    final groups = <int, List<TodayDose>>{};
    for (final d in doses) {
      groups.putIfAbsent(d.minute, () => []).add(d);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        for (final entry in groups.entries) ...[
          _GroupHeader(
            time: displayTime(entry.value.first.time, lang),
            chip: entry.value.every((d) => d.state == DoseState.taken)
                ? (bn ? '✓ সব খাওয়া হয়েছে' : '✓ All taken')
                : entry.key <= nowMinute && entry.value.any((d) => open.contains(d.state))
                    ? (bn ? 'রেকর্ড বাকি' : 'Not recorded')
                    : entry.key == nextMinute
                        ? (bn ? 'পরের ডোজ' : 'Next')
                        : null,
            chipColor: entry.value.every((d) => d.state == DoseState.taken)
                ? AppColors.success
                : entry.key <= nowMinute
                    ? AppColors.warning
                    : AppColors.primary,
          ),
          for (final d in entry.value)
            _DoseRow(
              dose: d,
              lang: lang,
              // Only once its time has come: a dose cannot be recorded in advance.
              canTick: open.contains(d.state) && d.minute <= nowMinute,
              onTick: () => recordDoses(context, ref, [d.medicine], d.time, 'taken'),
              onTap: () => showMedicineActions(context, ref, d.medicine, time: d.time),
            ),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String time;
  final String? chip;
  final Color chipColor;
  const _GroupHeader({required this.time, required this.chip, required this.chipColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
      child: Row(children: [
        const Icon(Icons.schedule_rounded, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(time, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const Spacer(),
        if (chip != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(color: chipColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(chip!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: chipColor)),
          ),
      ]),
    );
  }
}

class _DoseRow extends StatelessWidget {
  final TodayDose dose;
  final String lang;
  final bool canTick;
  final VoidCallback onTick;
  final VoidCallback onTap;
  const _DoseRow({
    required this.dose,
    required this.lang,
    required this.canTick,
    required this.onTick,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bn = lang == 'bn';
    final m = dose.medicine;
    final name = '${m.name} ${m.strength}'.trim();
    final Widget trailing;
    switch (dose.state) {
      case DoseState.taken:
        trailing = Semantics(
          label: bn ? 'খাওয়া হয়েছে' : 'Taken',
          child: const CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.success,
              child: Icon(Icons.check_rounded, color: Colors.white, size: 26)),
        );
      case DoseState.skipped:
        trailing = Text(bn ? 'বাদ দেওয়া' : 'Skipped',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary));
      case DoseState.pending || DoseState.missed when canTick:
        trailing = Semantics(
          button: true,
          label: bn ? '$name খেয়েছি' : 'Mark $name as taken',
          excludeSemantics: true,
          child: InkResponse(
            onTap: onTick,
            radius: 30,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: dose.state == DoseState.missed ? AppColors.warning : AppColors.primary, width: 3),
              ),
            ),
          ),
        );
      default:
        trailing = const Icon(Icons.schedule_rounded, color: Color(0xFF9CA3AF), size: 28);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 62),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text(
                      [doseLabel(m, lang), mealLabel(m.mealRelation, lang)].where((s) => s.isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                trailing,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
