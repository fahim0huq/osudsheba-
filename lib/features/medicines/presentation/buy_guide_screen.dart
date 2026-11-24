import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/utils/stock.dart';
import '../../../core/utils/time_label.dart';
import '../../../shared/widgets/app_primary_button.dart';
import 'widgets/add_medicine_parts.dart';
import 'widgets/stock_card.dart';

/// "What to buy": opened from the low-stock reminder or the medicine page. Shows the medicine,
/// how much to buy, a large view to show at the pharmacy, and "I bought it".
class BuyGuideScreen extends ConsumerWidget {
  const BuyGuideScreen({super.key, required this.medicineId});
  final String medicineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).language;
    final bn = lang == 'bn';
    final meds = ref.watch(medicinesProvider).where((m) => m.id == medicineId);
    final m = meds.isEmpty ? null : meds.first;
    final now = DateTime.now();
    final s = m == null
        ? null
        : stockStatus(m, ref.watch(doseLogsProvider), now, alertDays: ref.watch(appSettingsProvider).refillAlertDays);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F5),
      appBar: AppBar(
        title: Text(bn ? 'কী কিনবেন' : 'What to buy'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: m == null || s == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  bn ? 'এই ওষুধের স্টক হিসাব নেই।' : 'Stock is not counted for this medicine.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
                ),
              ),
            )
          : SafeArea(child: _body(context, ref, m, s, lang, now)),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, Medicine m, StockStatus s, String lang, DateTime now) {
    final bn = lang == 'bn';
    final buy = suggestedPurchase(m, s, now);
    final color = stockColor(s);
    final strips = countsInMl(m.form) || buy.amount < 10
        ? ''
        : (bn
              ? ' · প্রায় ${localDigits((buy.amount / 10).ceil(), lang)} পাতা'
              : ' · about ${(buy.amount / 10).ceil()} strips');
    final forDays = m.endDate != null
        ? (bn ? 'কোর্স শেষ হওয়া পর্যন্ত' : 'until the course ends')
        : (bn ? '${localDigits(buy.days, lang)} দিনের জন্য' : 'for ${buy.days} days');
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Icon(s.empty ? Icons.error_rounded : Icons.hourglass_bottom_rounded, color: color, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.empty
                            ? daysLeftText(s, lang)
                            : '${daysLeftText(s, lang)} · ${stockUnits(s.left, m.form, lang)} ${bn ? 'আছে' : 'left'}',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Photo(medicine: m, size: 76),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${m.name} ${m.strength}'.trim(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                bn ? m.form.bnName : m.form.displayName,
                                style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Text(
                      bn ? 'কতগুলো কিনবেন' : 'How many to buy',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      buy.amount <= 0
                          ? (bn ? 'এখন কেনার দরকার নেই' : 'Nothing needed now')
                          : stockUnits(buy.amount, m.form, lang),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                    ),
                    if (buy.amount > 0)
                      Text('$forDays$strips', style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      bn
                          ? 'প্রেসক্রিপশন সাথে নিন। কতদিন খাবেন তা ডাক্তার ঠিক করবেন। হিসাবটি আপনার "খেয়েছি" চাপার উপর নির্ভর করে।'
                          : 'Take your prescription along. Your doctor decides how long to take it. The count depends on your "Taken" taps.',
                      style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
                  icon: const Icon(Icons.storefront_rounded),
                  label: Text(bn ? 'দোকানে দেখান' : 'Show at pharmacy'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => _PharmacyView(medicine: m, amount: buy.amount, lang: lang),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppPrimaryButton(
                  text: bn ? 'কিনেছি' : 'Bought',
                  icon: Icons.add_shopping_cart_rounded,
                  onPressed: () async {
                    final done = await recordPurchase(context, ref, m, lang);
                    if (done && context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.medicine, required this.size});
  final Medicine medicine;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
      alignment: Alignment.center,
      child: MedicineTypeTiles.glyph(medicine.form, AppColors.primary),
    );
    final path = medicine.photoPath;
    if (kIsWeb || path == null || path.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

/// Large, plain view to hand to the pharmacist.
class _PharmacyView extends StatelessWidget {
  const _PharmacyView({required this.medicine, required this.amount, required this.lang});
  final Medicine medicine;
  final double amount;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final bn = lang == 'bn';
    final m = medicine;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, foregroundColor: AppColors.textPrimary, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Photo(medicine: m, size: 160),
                const SizedBox(height: 24),
                Text(
                  bn ? 'এই ওষুধটি দিন' : 'Please give me',
                  style: const TextStyle(fontSize: 20, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  m.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                if (m.strength.trim().isNotEmpty)
                  Text(
                    m.strength,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                  ),
                Text(
                  bn ? m.form.bnName : m.form.displayName,
                  style: const TextStyle(fontSize: 22, color: AppColors.textSecondary),
                ),
                if (amount > 0) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
                    child: Text(
                      stockUnits(amount, m.form, lang),
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
