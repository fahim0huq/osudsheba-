import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/mock_models.dart';
import '../../../../core/services/mock_data_service.dart';
import '../../../../core/utils/dose_text.dart';
import '../../../../core/utils/time_label.dart';
import 'medicine_actions_sheet.dart';
import 'stock_card.dart';

/// Every saved medicine: search, then Running / Paused / Finished. Tap one (or ⋮)
/// for its sheet: today's dose, details, edit, pause and delete.
class AllMedicinesTab extends ConsumerStatefulWidget {
  const AllMedicinesTab({super.key});

  @override
  ConsumerState<AllMedicinesTab> createState() => _AllMedicinesTabState();
}

class _AllMedicinesTabState extends ConsumerState<AllMedicinesTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    final bn = lang == 'bn';
    final q = _query.trim().toLowerCase();
    final meds = ref
        .watch(medicinesProvider)
        .where((m) => q.isEmpty || '${m.name} ${m.strength}'.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final groups = <(String, List<Medicine>)>[
      (bn ? 'চলছে' : 'Running', meds.where((m) => m.status.toLowerCase() == 'active').toList()),
      (bn ? 'বিরতিতে' : 'Paused', meds.where((m) => m.status.toLowerCase() == 'paused').toList()),
      (bn ? 'শেষ হয়েছে' : 'Finished', meds.where((m) => m.status.toLowerCase() == 'completed').toList()),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), // room for the Add button
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(fontSize: 17),
          decoration: InputDecoration(
            hintText: bn ? 'ওষুধ খুঁজুন' : 'Search medicines',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
        if (meds.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text(
              q.isEmpty ? (bn ? 'কোনো ওষুধ যোগ করা নেই' : 'No medicines added yet') : (bn ? 'কিছু পাওয়া যায়নি' : 'Nothing found'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
          ),
        for (final (title, list) in groups)
          if (list.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 16, 2, 6),
              child: Text('$title (${localDigits(list.length, lang)})',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            ),
            for (final m in list) _MedicineRow(medicine: m, lang: lang),
          ],
      ],
    );
  }
}

class _MedicineRow extends ConsumerWidget {
  final Medicine medicine;
  final String lang;
  const _MedicineRow({required this.medicine, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = medicine;
    final active = m.status.toLowerCase() == 'active';
    final times = m.times.map((t) => displayTime(t, lang)).join(', ');
    void open() => showMedicineActions(context, ref, m);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: active ? 1 : 0.6,
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
          child: InkWell(
            onTap: open,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 2, 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${m.name} ${m.strength}'.trim(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text([doseLabel(m, lang), times].where((s) => s.isNotEmpty).join(' · '),
                        style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                    if (active) StockBadge(medicine: m, lang: lang),
                  ]),
                ),
                IconButton(
                  onPressed: open,
                  iconSize: 28,
                  tooltip: lang == 'bn' ? 'আরও' : 'More',
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
