import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/mock_models.dart';
import '../../../../core/utils/stock.dart';
import '../../../../core/utils/time_label.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import 'add_medicine_parts.dart';
import 'medicine_form_parts.dart';
import 'stock_sheet.dart';

/// Start date, end date, stock and special instructions: options many people leave as they
/// are, so they live in a sheet instead of crowding the Add Medicine screen.
class DatesNotes {
  const DatesNotes({required this.start, this.end, this.note = '', this.stock});
  final DateTime start;
  final DateTime? end;
  final String note;

  /// How many the person has now (tablets, capsules or ml); null = not counted.
  final double? stock;
}

bool _isToday(DateTime d) {
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day;
}

/// "Starts today · keeps going · 30 tablets · with warm water".
String datesNotesSummary(DatesNotes v, String lang, MedicineForm form) {
  final bn = lang == 'bn';
  final start = _isToday(v.start)
      ? (bn ? 'আজ থেকে শুরু' : 'Starts today')
      : '${bn ? 'শুরু' : 'Starts'} ${localDigits(shortDate(v.start), lang)}';
  final end = v.end == null
      ? (bn ? 'চলতে থাকবে' : 'keeps going')
      : '${bn ? 'শেষ' : 'ends'} ${localDigits(shortDate(v.end!), lang)}';
  final extras = [
    if (v.stock != null && tracksStock(form)) stockUnits(v.stock!, form, lang),
    if (v.note.trim().isNotEmpty) v.note.trim(),
  ];
  if (extras.isEmpty) extras.add(bn ? 'স্টক ও নির্দেশনা যোগ করুন' : 'add stock and notes');
  return [start, end, ...extras].join(' · ');
}

Future<DatesNotes?> showDatesNotesSheet(BuildContext context, DatesNotes initial, String lang, MedicineForm form) {
  return showModalBottomSheet<DatesNotes>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DatesNotesSheet(initial: initial, lang: lang, form: form),
  );
}

class _DatesNotesSheet extends StatefulWidget {
  const _DatesNotesSheet({required this.initial, required this.lang, required this.form});
  final DatesNotes initial;
  final String lang;
  final MedicineForm form;

  @override
  State<_DatesNotesSheet> createState() => _DatesNotesSheetState();
}

class _DatesNotesSheetState extends State<_DatesNotesSheet> {
  late DateTime _start = widget.initial.start;
  late DateTime? _end = widget.initial.end;
  late final _note = TextEditingController(text: widget.initial.note);
  late final _stock = TextEditingController(
    text: widget.initial.stock == null ? '' : amountText(widget.initial.stock!, 'en'),
  );

  bool get bn => widget.lang == 'bn';

  @override
  void dispose() {
    _note.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (d == null) return;
    setState(() {
      _start = d;
      if (_end != null && _end!.isBefore(d)) _end = null;
    });
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _end ?? _start.add(const Duration(days: 7)),
      firstDate: _start,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (d != null) setState(() => _end = d);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final startText = _isToday(_start) ? (bn ? 'আজ' : 'Today') : localDigits(shortDate(_start), lang);
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
              bn ? 'তারিখ, স্টক ও নির্দেশনা' : 'Dates, stock and notes',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            _row(Icons.play_circle_outline_rounded, bn ? 'কবে থেকে শুরু' : 'Start', startText, _pickStart),
            const SizedBox(height: 16),
            Text(
              bn ? 'কতদিন খাবেন' : 'How long',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            ChoicePills(
              choices: [
                PillChoice(
                  bn ? 'চলতে থাকবে' : 'Keep going',
                  selected: _end == null,
                  onTap: () => setState(() => _end = null),
                ),
                PillChoice(bn ? 'শেষ তারিখ আছে' : 'Until a date', selected: _end != null, onTap: _pickEnd),
              ],
            ),
            if (_end != null) ...[
              const SizedBox(height: 10),
              _row(Icons.event_rounded, bn ? 'শেষ তারিখ' : 'End date', localDigits(shortDate(_end!), lang), _pickEnd),
            ],
            if (tracksStock(widget.form)) ...[
              const SizedBox(height: 18),
              Text(
                bn
                    ? 'স্টক (ঐচ্ছিক): শেষ হওয়ার আগে মনে করিয়ে দেব'
                    : 'Stock (optional): we remind you before it runs out',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              StockInput(controller: _stock, form: widget.form, lang: lang),
            ],
            const SizedBox(height: 18),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: compactFieldDecoration(
                bn ? 'বিশেষ নির্দেশনা (ঐচ্ছিক)' : 'Special instructions (optional)',
                hint: bn ? 'যেমন: গরম পানির সাথে' : 'e.g. Take with warm water',
                icon: Icons.note_alt_rounded,
              ),
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              text: bn ? 'ঠিক আছে' : 'Done',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(
                context,
              ).pop(DatesNotes(start: _start, end: _end, note: _note.text, stock: parseStock(_stock.text))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, VoidCallback onTap) => Material(
    color: AppColors.primaryLight,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    ),
  );
}
