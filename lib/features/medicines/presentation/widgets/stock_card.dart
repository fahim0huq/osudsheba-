import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/mock_models.dart';
import '../../../../core/services/mock_data_service.dart';
import '../../../../core/utils/stock.dart';
import '../../../../core/utils/time_label.dart';
import 'medicine_form_parts.dart';
import 'stock_sheet.dart';

StockStatus? currentStock(WidgetRef ref, Medicine m) => stockStatus(
  m,
  ref.read(doseLogsProvider),
  DateTime.now(),
  alertDays: ref.read(appSettingsProvider).refillAlertDays,
);

void _saved(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text), backgroundColor: AppColors.success));

/// "I bought some": adds the amount to what is left now.
Future<bool> recordPurchase(BuildContext context, WidgetRef ref, Medicine m, String lang) async {
  final n = await showStockSheet(context, medicine: m, lang: lang, adding: true);
  if (n == null || !context.mounted) return false;
  final left = currentStock(ref, m)?.left ?? 0;
  final total = left + n;
  ref.read(medicinesProvider.notifier).updateMedicine(m.copyWith(stockCount: total, stockSetAt: DateTime.now()));
  _saved(
    context,
    lang == 'bn'
        ? 'স্টকে যোগ হয়েছে। এখন আছে ${stockUnits(total, m.form, lang)}'
        : 'Added. You now have ${stockUnits(total, m.form, lang)}',
  );
  return true;
}

/// Set (or correct, or stop) the count of what is left now.
Future<void> setStock(BuildContext context, WidgetRef ref, Medicine m, String lang) async {
  final s = currentStock(ref, m);
  final n = await showStockSheet(context, medicine: m, lang: lang, adding: false, current: s?.left);
  if (n == null || !context.mounted) return;
  final notifier = ref.read(medicinesProvider.notifier);
  if (n < 0) {
    notifier.updateMedicine(m.copyWith(clearStock: true));
    _saved(context, lang == 'bn' ? 'স্টক হিসাব বন্ধ করা হয়েছে' : 'Stock is no longer counted');
    return;
  }
  notifier.updateMedicine(m.copyWith(stockCount: n, stockSetAt: DateTime.now()));
  _saved(context, lang == 'bn' ? 'স্টক সংরক্ষণ হয়েছে' : 'Stock saved');
}

Color stockColor(StockStatus s) =>
    s.empty && !s.courseEndsFirst ? AppColors.error : (s.low ? AppColors.warning : AppColors.success);

/// Stock on the medicine page: what is left, how long it lasts, and Bought / Correct.
/// Without a count it is one quiet line inviting the person to add it.
class StockCard extends ConsumerWidget {
  const StockCard({super.key, required this.medicine, required this.lang});
  final Medicine medicine;
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bn = lang == 'bn';
    final m = medicine;
    if (!tracksStock(m.form)) return const SizedBox.shrink();
    final s = stockStatus(
      m,
      ref.watch(doseLogsProvider),
      DateTime.now(),
      alertDays: ref.watch(appSettingsProvider.select((x) => x.refillAlertDays)),
    );
    if (s == null) {
      return Material(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setStock(context, ref, m, lang),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bn ? 'স্টক লিখুন · শেষের আগে মনে করাব' : 'Add stock · we remind you before it runs out',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.add_circle_rounded, color: AppColors.primary),
              ],
            ),
          ),
        ),
      );
    }
    final color = stockColor(s);
    final level = s.daysLeft == null ? 1.0 : (s.daysLeft! / 30).clamp(0.03, 1.0);
    final when = s.runsOutOn == null || s.empty
        ? ''
        : ' · ${bn ? 'শেষ' : 'until'} ${localDigits(shortDate(s.runsOutOn!), lang)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.needsBuying ? color.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bn ? '${stockUnits(s.left, m.form, lang)} আছে' : '${stockUnits(s.left, m.form, lang)} left',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              Text(
                daysLeftText(s, lang),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: level,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
          if (when.isNotEmpty || s.courseEndsFirst) ...[
            const SizedBox(height: 6),
            Text(
              s.courseEndsFirst
                  ? (bn ? 'কোর্স শেষ হওয়া পর্যন্ত যথেষ্ট আছে' : 'Enough until the course ends')
                  : '${daysLeftText(s, lang)}$when',
              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
          ],
          Row(
            children: [
              if (s.needsBuying)
                TextButton.icon(
                  icon: const Icon(Icons.shopping_bag_rounded, size: 20),
                  label: Text(bn ? 'কী কিনবেন' : 'What to buy'),
                  onPressed: () => context.push('/refill?medicineId=${m.id}'),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => setStock(context, ref, m, lang),
                child: Text(bn ? 'ঠিক করুন' : 'Correct', style: const TextStyle(color: AppColors.textSecondary)),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                label: Text(bn ? 'কিনেছি' : 'Bought'),
                onPressed: () => recordPurchase(context, ref, m, lang),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small warning under a medicine in lists, only when it is time to buy.
class StockBadge extends ConsumerWidget {
  const StockBadge({super.key, required this.medicine, required this.lang});
  final Medicine medicine;
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stockStatus(
      medicine,
      ref.watch(doseLogsProvider),
      DateTime.now(),
      alertDays: ref.watch(appSettingsProvider.select((x) => x.refillAlertDays)),
    );
    if (s == null || !s.needsBuying) return const SizedBox.shrink();
    final color = stockColor(s);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag_rounded, size: 15, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${lang == 'bn' ? 'কিনতে হবে' : 'Buy soon'} · ${daysLeftText(s, lang)}',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
