import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/mock_models.dart';
import '../../../../core/services/scan/medicine_catalog.dart';

/// The medicine the person chose: from the list ([entry] set) or typed as is.
class NamePick {
  final String name;
  final CatalogEntry? entry;
  final MedicineForm form;
  final String strength;

  const NamePick(this.name, this.entry, this.form, this.strength);
}

/// A name field that suggests Bangladeshi brands after 2 letters, then offers the forms
/// and strengths that brand is sold in. Suggestions sit inline (no pop-up), so the
/// keyboard never covers them.
class MedicineNamePicker extends StatefulWidget {
  const MedicineNamePicker({
    super.key,
    required this.catalog,
    required this.controller,
    required this.pick,
    required this.onPick,
    required this.bn,
  });

  final MedicineCatalog? catalog;
  final TextEditingController controller;
  final NamePick? pick;
  final ValueChanged<NamePick?> onPick;
  final bool bn;

  @override
  State<MedicineNamePicker> createState() => _MedicineNamePickerState();
}

class _MedicineNamePickerState extends State<MedicineNamePicker> {
  List<CatalogEntry> _suggestions = const [];

  void _onTyped(String text) {
    setState(() => _suggestions = widget.catalog?.search(text) ?? const []);
    widget.onPick(text.trim().isEmpty ? null : NamePick(text.trim(), null, MedicineForm.tablet, ''));
  }

  List<(MedicineForm, String)> _variants(CatalogEntry e) => [
    for (final f in e.forms.entries)
      if (formForCode(f.key) != null)
        ...(f.value.isEmpty ? [(formForCode(f.key)!, '')] : f.value.map((s) => (formForCode(f.key)!, s))),
  ];

  void _choose(CatalogEntry e) {
    widget.controller.text = e.brand;
    FocusManager.instance.primaryFocus?.unfocus();
    final v = _variants(e);
    setState(() => _suggestions = const []);
    widget.onPick(NamePick(e.brand, e, v.isEmpty ? MedicineForm.tablet : v.first.$1, v.isEmpty ? '' : v.first.$2));
  }

  Widget _chip(String label, {bool selected = false, required VoidCallback onTap}) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 13.5)),
      selected: selected,
      selectedColor: AppColors.primaryLight,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onTap(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bn = widget.bn;
    final pick = widget.pick;
    final entry = pick?.entry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          onChanged: _onTyped,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
            labelText: bn ? 'ওষুধের নাম (প্রথম কয়েকটি অক্ষর)' : 'Medicine name (first letters)',
            helperText: widget.catalog == null ? (bn ? 'তালিকা খোলা হচ্ছে…' : 'Loading the medicine list…') : null,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: entry == null
                ? [
                    for (final e in _suggestions)
                      _chip('${e.brand} · ${e.generic.split(RegExp(r'[\s(+]')).first}', onTap: () => _choose(e)),
                  ]
                : [
                    for (final v in _variants(entry))
                      _chip(
                        '${bn ? v.$1.bnName : v.$1.displayName} ${v.$2}'.trim(),
                        selected: pick!.form == v.$1 && pick.strength == v.$2,
                        onTap: () => widget.onPick(NamePick(entry.brand, entry, v.$1, v.$2)),
                      ),
                  ],
          ),
        ),
      ],
    );
  }
}
