import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/mock_models.dart';
import '../../../../core/services/mock_data_service.dart';
import '../../../../core/utils/dose_text.dart';
import '../../../../core/utils/home_schedule.dart';
import '../../../../core/utils/schedule_utils.dart';
import '../../../../core/utils/time_label.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../home/presentation/dose_recorder.dart';

/// The sheet for one medicine: today's dose (Skip / Taken), then See details, Edit,
/// Pause (or Resume) and Delete. [time] picks which of today's doses to show; without it,
/// the first one not recorded yet. [context] must be the screen's, so snackbars outlive the sheet.
Future<void> showMedicineActions(BuildContext context, WidgetRef ref, Medicine medicine, {String? time}) {
  final lang = ref.read(appSettingsProvider).language;
  final bn = lang == 'bn';
  final now = DateTime.now();
  final today = todayDoses(medicines: [medicine], logs: ref.read(doseLogsProvider), now: now);
  final dose = time != null
      ? today.where((d) => d.time == time).firstOrNull
      : today.where((d) => d.state == DoseState.pending || d.state == DoseState.missed).firstOrNull;
  final active = medicine.isActive;
  final name = '${medicine.name} ${medicine.strength}'.trim();

  void act(VoidCallback fn) {
    Navigator.of(context).pop();
    fn();
  }

  Widget action(IconData icon, String label, VoidCallback onTap, {Color color = AppColors.textPrimary}) => ListTile(
        minTileHeight: 58,
        leading: Icon(icon, color: color, size: 28),
        title: Text(label, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: color)),
        onTap: () => act(onTap),
      );

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text(
            [
              doseLabel(medicine, lang),
              mealLabel(medicine.mealRelation, lang),
              medicine.times.map((t) => displayTime(t, lang)).join(', '),
            ].where((s) => s.isNotEmpty).join(' · '),
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          if (dose != null) ...[
            const SizedBox(height: 12),
            _TodayDoseBox(
              dose: dose,
              lang: lang,
              early: !doseTimeHasCome(dose.time, now),
              onSkip: () => act(() => confirmSkipDoses(context, ref, [medicine], dose.time)),
              onTaken: () => act(() => recordDoses(context, ref, [medicine], dose.time, 'taken')),
            ),
          ],
          const SizedBox(height: 6),
          action(Icons.info_outline_rounded, bn ? 'বিস্তারিত দেখুন' : 'See details', () {
            ref.read(selectedMedicineProvider.notifier).state = medicine;
            context.push('/medicine-detail', extra: medicine);
          }),
          action(Icons.edit_outlined, bn ? 'সম্পাদনা করুন' : 'Edit', () => context.push('/edit-medicine', extra: medicine)),
          action(active ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
              active ? (bn ? 'বিরতি দিন' : 'Pause') : (bn ? 'আবার চালু করুন' : 'Resume'),
              () => _setStatus(context, ref, medicine, active ? 'paused' : 'active', bn)),
          action(Icons.delete_outline_rounded, bn ? 'মুছে ফেলুন' : 'Delete', () => _delete(context, ref, medicine, bn),
              color: AppColors.error),
        ]),
      ),
    ),
  );
}

void _setStatus(BuildContext context, WidgetRef ref, Medicine medicine, String status, bool bn) {
  final notifier = ref.read(medicinesProvider.notifier);
  final before = medicine.status;
  notifier.updateStatus(medicine.id, status);
  final paused = status == 'paused';
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    duration: const Duration(seconds: 6),
    content: Text(paused
        ? (bn ? 'বিরতি দেওয়া হলো। আবার চালু না করা পর্যন্ত রিমাইন্ডার আসবে না।' : 'Paused. No reminders until you resume it.')
        : (bn ? 'আবার চালু হলো। রিমাইন্ডার আসবে।' : 'Resumed. Reminders are on again.')),
    action: SnackBarAction(
      label: bn ? 'ফিরিয়ে নিন' : 'UNDO',
      onPressed: () => notifier.updateStatus(medicine.id, before),
    ),
  ));
}

Future<void> _delete(BuildContext context, WidgetRef ref, Medicine medicine, bool bn) async {
  final name = '${medicine.name} ${medicine.strength}'.trim();
  final ok = await showConfirmDialog(
    context,
    title: bn ? '$name মুছবেন?' : 'Delete $name?',
    message: bn
        ? 'এই ওষুধের সব রিমাইন্ডার বন্ধ হবে। মুছে ফেললে আর ফেরানো যাবে না। শুধু কিছুদিন বন্ধ রাখতে চাইলে "বিরতি দিন" বেছে নিন।'
        : 'All reminders for this medicine will stop. This cannot be undone. To stop it for a while, choose "Pause" instead.',
    confirmLabel: bn ? 'হ্যাঁ, মুছুন' : 'Yes, delete',
    cancelLabel: bn ? 'না, রাখুন' : 'No, keep it',
    icon: Icons.delete_outline_rounded,
  );
  if (!ok || !context.mounted) return;
  ref.read(medicinesProvider.notifier).deleteMedicine(medicine.id);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(bn ? 'ওষুধটি মুছে ফেলা হয়েছে' : 'Medicine deleted'),
    backgroundColor: AppColors.error,
  ));
}

/// "Today's 8:00 PM dose" with Skip / Taken, or what was already recorded.
class _TodayDoseBox extends StatelessWidget {
  final TodayDose dose;
  final String lang;
  final bool early; // its time has not come yet
  final VoidCallback onSkip;
  final VoidCallback onTaken;
  const _TodayDoseBox(
      {required this.dose, required this.lang, required this.early, required this.onSkip, required this.onTaken});

  @override
  Widget build(BuildContext context) {
    final bn = lang == 'bn';
    final t = displayTime(dose.time, lang);
    final done = switch (dose.state) {
      DoseState.taken => bn ? '✓ খাওয়া হয়েছে' : '✓ Taken',
      DoseState.skipped => bn ? 'বাদ দেওয়া হয়েছে' : 'Skipped',
      _ => null,
    };
    const shape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14)));
    const text = TextStyle(fontSize: 17, fontWeight: FontWeight.bold);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(bn ? 'আজ $t-এর ডোজ' : "Today's $t dose",
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        if (done != null)
          Text(done, style: text.copyWith(color: AppColors.primaryDark))
        else if (early)
          Text(notYetText(dose.time, lang),
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w600))
        else
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSkip,
                icon: const Icon(Icons.skip_next_rounded),
                label: Text(bn ? 'বাদ দিন' : 'Skip'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52), shape: shape, textStyle: text, foregroundColor: AppColors.primary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onTaken,
                icon: const Icon(Icons.check_rounded),
                label: Text(bn ? 'খেয়েছি' : 'Taken'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    shape: shape,
                    textStyle: text,
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
              ),
            ),
          ]),
      ]),
    );
  }
}
