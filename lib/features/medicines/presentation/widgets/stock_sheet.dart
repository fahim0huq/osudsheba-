import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/mock_models.dart';
import '../../../../core/utils/stock.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import 'medicine_form_parts.dart';

/// Number field for a stock amount, with one-tap amounts people usually buy
/// ("1 strip (10)", "1 bottle (100 ml)").
class StockInput extends StatelessWidget {
  const StockInput({super.key, required this.controller, required this.form, required this.lang, this.label});

  final TextEditingController controller;
  final MedicineForm form;
  final String lang;
  final String? label;

  List<(String, double)> _quick() {
    final bn = lang == 'bn';
    if (form == MedicineForm.syrup) {
      return [
        (bn ? '১ বোতল (১০০ ml)' : '1 bottle (100 ml)', 100),
        (bn ? '২ বোতল (২০০ ml)' : '2 bottles (200 ml)', 200),
      ];
    }
    if (form == MedicineForm.injection) return [('5 ml', 5), ('10 ml', 10)];
    return [
      (bn ? '১ পাতা (১০)' : '1 strip (10)', 10),
      (bn ? '২ পাতা (২০)' : '2 strips (20)', 20),
      (bn ? '৩০টি' : '30', 30),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bn = lang == 'bn';
    final unit = countsInMl(form) ? 'ml' : (bn ? 'টি' : (form == MedicineForm.capsule ? 'capsules' : 'tablets'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.০-৯]'))],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          decoration: compactFieldDecoration(
            label ?? (bn ? 'কতগুলো আছে' : 'How many you have'),
            hint: '0',
            icon: Icons.inventory_2_rounded,
            suffix: unit,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final (text, n) in _quick())
              ActionChip(
                label: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
                backgroundColor: AppColors.primaryLight,
                side: BorderSide.none,
                onPressed: () => controller.text = amountText(n, 'en'),
              ),
          ],
        ),
      ],
    );
  }
}

/// Field text -> amount (Bangla digits allowed); null when empty or not a number.
double? parseStock(String text) {
  var t = text.trim();
  const bnDigits = '০১২৩৪৫৬৭৮৯';
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(bnDigits[i], '$i');
  }
  final n = double.tryParse(t);
  return n == null || n < 0 ? null : n;
}

/// Asks for an amount: what was bought ([adding]) or what is left now. Returns null if closed.
Future<double?> showStockSheet(
  BuildContext context, {
  required Medicine medicine,
  required String lang,
  required bool adding,
  double? current,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _StockSheet(medicine: medicine, lang: lang, adding: adding, current: current),
  );
}

class _StockSheet extends StatefulWidget {
  const _StockSheet({required this.medicine, required this.lang, required this.adding, this.current});
  final Medicine medicine;
  final String lang;
  final bool adding;
  final double? current;

  @override
  State<_StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends State<_StockSheet> {
  late final _controller = TextEditingController(
    text: widget.adding || widget.current == null ? '' : amountText(widget.current!, 'en'),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bn = widget.lang == 'bn';
    final m = widget.medicine;
    final title = widget.adding
        ? (bn ? 'কতগুলো কিনেছেন?' : 'How many did you buy?')
        : (bn ? 'এখন কতগুলো আছে?' : 'How many do you have now?');
    final hint = widget.adding
        ? (bn ? 'যা আছে তার সাথে যোগ হবে।' : 'This is added to what you have.')
        : (bn ? 'গুনে দেখে লিখুন। খেয়েছি চাপলে এখান থেকে কমবে।' : 'Count and enter it. Each "Taken" uses some up.');
    return Padding(
      // Room for the keyboard and for the phone's navigation bar (Done sat under it).
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              '${m.name} ${m.strength}'.trim(),
              style: const TextStyle(fontSize: 16, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(hint, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            StockInput(
              controller: _controller,
              form: m.form,
              lang: widget.lang,
              label: widget.adding ? (bn ? 'কিনেছি' : 'Bought') : null,
            ),
            const SizedBox(height: 18),
            AppPrimaryButton(
              text: bn ? 'সংরক্ষণ করুন' : 'Save',
              icon: Icons.check_rounded,
              onPressed: () {
                final n = parseStock(_controller.text);
                if (n == null || (widget.adding && n == 0)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(bn ? 'একটি সংখ্যা লিখুন' : 'Enter a number'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(n);
              },
            ),
            if (!widget.adding && widget.current != null) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(context).pop(-1),
                child: Text(
                  bn ? 'স্টক হিসাব বন্ধ করুন' : 'Stop counting stock',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
