import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/prescription_service.dart';
import '../../../core/services/scan/prescription_text_parser.dart';
import '../../../core/utils/dose_slots.dart';
import '../../medicines/presentation/widgets/when_to_take_card.dart';
import 'widgets/medicine_name_picker.dart';

/// For handwritten prescriptions: the photo stays on screen (pinch to zoom) while the
/// person types the first letters of each medicine and taps the dose. Each medicine
/// goes to the review screen; nothing is saved here.
class PhotoEntryScreen extends ConsumerStatefulWidget {
  const PhotoEntryScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  ConsumerState<PhotoEntryScreen> createState() => _PhotoEntryScreenState();
}

class _PhotoEntryScreenState extends ConsumerState<PhotoEntryScreen> {
  final _name = TextEditingController();
  final List<ScanDraft> _added = [];
  NamePick? _pick;
  Set<DoseSlot> _slots = {}; // Morning / Noon / Night x Before / After meal, like "1+0+1"
  int? _days; // null = keeps going

  static const _dayOptions = [null, 3, 5, 7, 10, 14, 30];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _snack(String text, {bool error = false}) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );

  void _add(bool bn) {
    final pick = _pick;
    if (pick == null || pick.name.isEmpty) {
      _snack(bn ? 'ওষুধের নাম লিখুন' : 'Type the medicine name', error: true);
      return;
    }
    if (_slots.isEmpty) {
      _snack(bn ? 'কখন খাবেন বেছে নিন (যেমন ১+০+১)' : 'Choose when to take it (e.g. 1+0+1)', error: true);
      return;
    }
    final slots = DoseSlot.values.where(_slots.contains).toList();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final med = Medicine(
      id: const Uuid().v4(),
      name: pick.name,
      strength: pick.strength,
      form: pick.form,
      dose: pick.form.defaultDose,
      times: timesForSlots(slots, ref.read(appSettingsProvider).slotTimes),
      mealRelation: mealRelationForSlots(slots),
      slots: [for (final s in slots) s.key],
      instruction: '',
      startDate: start,
      endDate: _days == null ? null : start.add(Duration(days: _days! - 1)),
      status: 'active',
      createdAt: now,
    );
    setState(() {
      _added.add(ScanDraft(medicine: med, sourceText: '', generic: pick.entry?.generic));
      _pick = null;
      _slots = {};
      _name.clear();
    });
    _snack(bn ? '${med.name} যোগ হয়েছে' : 'Added ${med.name}');
  }

  Widget _chips<T>(List<T> values, T selected, String Function(T) label, ValueChanged<T> onTap) => SizedBox(
    height: 40,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final v in values)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(label(v), style: const TextStyle(fontSize: 13.5)),
              selected: v == selected,
              selectedColor: AppColors.primaryLight,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => onTap(v)),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bn = ref.watch(appSettingsProvider).language == 'bn';
    final catalog = ref.watch(medicineCatalogProvider).valueOrNull;
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(bn ? 'ছবি দেখে লিখুন' : 'Type from the photo'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: Colors.black12,
                    child: InteractiveViewer(
                      maxScale: 6,
                      child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              if (!typing)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    bn ? 'দুই আঙুলে ছবি বড় করুন' : 'Pinch to zoom the photo',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              const SizedBox(height: 8),
              MedicineNamePicker(
                catalog: catalog,
                controller: _name,
                pick: _pick,
                bn: bn,
                onPick: (p) => setState(() => _pick = p),
              ),
              if (!typing) ...[
                SlotGrid(
                  selected: _slots,
                  slotTimes: ref.watch(appSettingsProvider.select((s) => s.slotTimes)),
                  onChanged: (v) => setState(() => _slots = v),
                  lang: bn ? 'bn' : 'en',
                ),
                const SizedBox(height: 4),
                _chips<int?>(
                  _dayOptions,
                  _days,
                  (d) => d == null ? (bn ? 'চলবে' : 'Keeps going') : (bn ? '$d দিন' : '$d days'),
                  (d) => _days = d,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _add(bn),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(bn ? 'যোগ করুন' : 'Add'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _added.isEmpty
                            ? null
                            : () => context.push(
                                '/ai-prescription-review',
                                extra: {'drafts': List<ScanDraft>.of(_added), 'source': 'typed'},
                              ),
                        icon: const Icon(Icons.fact_check_rounded),
                        label: Text(bn ? 'দেখুন (${_added.length})' : 'Review (${_added.length})'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
