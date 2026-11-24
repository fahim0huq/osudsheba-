import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/confirm_dialog.dart';

/// Records [status] ("taken" / "skipped") for every medicine in [meds] at [slot] today,
/// then shows a snackbar with Undo. Used by Home and the Today's medicines screen.
void recordDoses(BuildContext context, WidgetRef ref, List<Medicine> meds, String slot, String status) {
  final bn = ref.read(appSettingsProvider).language == 'bn';
  final notifier = ref.read(doseLogsProvider.notifier);
  final changes = <(DoseLog, DoseLog?)>[];
  for (final med in meds) {
    final log = DoseLog(
      id: const Uuid().v4(),
      medicineId: med.id,
      medicineName: '${med.name} ${med.strength}'.trim(),
      scheduledTime: slot,
      status: status,
      actualTime: DateTime.now(),
    );
    final previous = notifier.findSameSlotLog(log);
    final stored = notifier.addLogReturning(log);
    changes.add((stored, previous));
  }
  final taken = status == 'taken';
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    duration: const Duration(seconds: 6),
    content: Text(taken
        ? (bn ? 'খাওয়া হয়েছে বলে রেকর্ড করা হলো' : 'Recorded as taken')
        : (bn ? 'বাদ দেওয়া হয়েছে বলে রেকর্ড করা হলো' : 'Recorded as skipped')),
    backgroundColor: taken ? AppColors.success : AppColors.textSecondary,
    action: SnackBarAction(
      label: bn ? 'ফিরিয়ে নিন' : 'UNDO',
      textColor: Colors.white,
      onPressed: () {
        for (final (added, previous) in changes) {
          notifier.undoLog(added, previous);
        }
      },
    ),
  ));
}

/// Asks first (skipping medicine is a health decision), then records the skip.
Future<void> confirmSkipDoses(BuildContext context, WidgetRef ref, List<Medicine> meds, String slot) async {
  final bn = ref.read(appSettingsProvider).language == 'bn';
  final ok = await showConfirmDialog(
    context,
    title: bn ? 'এই ডোজ বাদ দেবেন?' : 'Skip this dose?',
    message: bn
        ? 'ডাক্তারের পরামর্শ ছাড়া ওষুধ বাদ দেবেন না। তবুও বাদ দিলে এটি রেকর্ড হবে।'
        : 'Do not skip medicines unless your doctor told you to. If you skip, it will be recorded.',
    confirmLabel: bn ? 'হ্যাঁ, বাদ দিন' : 'Yes, skip it',
    cancelLabel: bn ? 'না, ফিরে যান' : 'No, go back',
    icon: Icons.skip_next_rounded,
  );
  if (ok && context.mounted) recordDoses(context, ref, meds, slot, 'skipped');
}
