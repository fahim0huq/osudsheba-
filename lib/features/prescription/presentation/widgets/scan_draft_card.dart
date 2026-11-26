import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/mock_models.dart';
import '../../../../core/services/scan/prescription_text_parser.dart';
import '../../../../core/utils/dose_slots.dart';

String scanIssueText(ScanIssue issue, bool bn) {
  switch (issue) {
    case ScanIssue.nameGuessed:
      return bn ? 'নাম অনুমান করা হয়েছে' : 'Name is a best guess';
    case ScanIssue.timesMissing:
      return bn ? 'সময় পড়া যায়নি' : 'Times not found';
    case ScanIssue.strengthMissing:
      return bn ? 'শক্তি দেখুন' : 'Check strength';
    case ScanIssue.durationMissing:
      return bn ? 'কত দিন লেখা নেই' : 'No duration found';
    case ScanIssue.unusualForm:
      return bn ? 'ধরন দেখুন' : 'Check the type';
  }
}

const _mealBn = {'Before Meal': 'খাবারের আগে', 'After Meal': 'খাবারের পরে', 'With Meal': 'খাবারের সাথে'};

/// One scanned medicine on the review screen: what was read, and what to check.
class ScanDraftCard extends StatelessWidget {
  const ScanDraftCard({super.key, required this.draft, required this.bn, required this.onEdit, required this.onDelete});

  final ScanDraft draft;
  final bool bn;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final m = draft.medicine;
    final days = m.endDate == null || m.startDate == null ? null : m.endDate!.difference(m.startDate!).inDays + 1;
    final meal = m.mealRelation == 'None' ? null : (bn ? _mealBn[m.mealRelation] : m.mealRelation);
    final details = [
      m.dose,
      if (m.slots.isEmpty && meal != null) meal,
      days == null ? (bn ? 'চলবে' : 'ongoing') : (bn ? '$days দিন' : '$days days'),
    ].join(' • ');
    final warn = draft.needsCheck;
    const small = TextStyle(fontSize: 13.0, color: AppColors.textSecondary);

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: warn ? AppColors.warning : AppColors.border, width: warn ? 1.5 : 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(m.form.icon, color: AppColors.primary, size: 20.0),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${m.name} ${m.strength}'.trim(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: AppColors.textPrimary),
                ),
                if (draft.generic != null && draft.generic!.isNotEmpty)
                  Text(
                    '${bn ? m.form.bnName : m.form.displayName} · ${draft.generic}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: small,
                  ),
                Text(details, style: small.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  m.slots.isEmpty ? m.times.join(', ') : slotsFromKeys(m.slots).map((s) => s.label(bn)).join(', '),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primaryDark),
                ),
                if (draft.readAs != null)
                  Text(
                    bn ? 'ছবিতে পড়া গেছে: "${draft.readAs}"' : 'Read on the photo as "${draft.readAs}"',
                    style: small.copyWith(fontStyle: FontStyle.italic),
                  ),
                if (draft.issues.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [for (final i in draft.issues) _chip(scanIssueText(i, bn))],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: bn ? 'ঠিক করুন' : 'Edit',
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20.0),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: bn ? 'বাদ দিন' : 'Remove',
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20.0),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(6.0),
    ),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.warning, fontSize: 12.0, fontWeight: FontWeight.bold),
    ),
  );
}
