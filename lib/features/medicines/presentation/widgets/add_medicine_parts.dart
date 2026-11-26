import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/mock_models.dart';
import '../../../../core/utils/time_label.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../shared/widgets/tap_area.dart';

/// Building blocks of the Add Medicine screen: friendly, tap-first choices (no dropdowns),
/// grouped in soft cards so the eye reads one question at a time.

/// A white rounded card with a small heading.
class FormCard extends StatelessWidget {
  const FormCard({super.key, required this.title, required this.icon, required this.child, this.trailing});

  final String title;
  final IconData icon;
  final Widget child;

  /// Optional small action at the end of the heading (e.g. a settings icon).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Tablet / Capsule / Syrup / Injection / Drops as five round icon tiles.
class MedicineTypeTiles extends StatelessWidget {
  const MedicineTypeTiles({super.key, required this.selected, required this.onChanged, required this.bn});

  final MedicineForm selected;
  final ValueChanged<MedicineForm> onChanged;
  final bool bn;

  /// Material has no tablet or capsule icon, so those two are drawn.
  static Widget glyph(MedicineForm f, Color c) => switch (f) {
    MedicineForm.tablet => Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c, width: 2.5),
      ),
      alignment: Alignment.center,
      child: Container(width: 2.5, height: 14, color: c),
    ),
    MedicineForm.capsule => Transform.rotate(
      angle: -0.75,
      child: Container(
        width: 12,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c, width: 2.2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c, c, Colors.transparent, Colors.transparent],
            stops: const [0, 0.5, 0.5, 1],
          ),
        ),
      ),
    ),
    MedicineForm.syrup => Icon(Icons.local_drink_rounded, size: 24, color: c),
    MedicineForm.injection => Icon(Icons.vaccines_rounded, size: 24, color: c),
    MedicineForm.drops => Icon(Icons.water_drop_rounded, size: 24, color: c),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in MedicineForm.values)
          Expanded(
            child: Semantics(
              button: true,
              selected: f == selected,
              child: TapArea(
                onTap: () => onChanged(f),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: f == selected ? AppColors.primary : AppColors.primaryLight,
                        boxShadow: f == selected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: glyph(f, f == selected ? Colors.white : AppColors.primary),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        bn ? f.bnName : f.displayName,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: f == selected ? FontWeight.w800 : FontWeight.w500,
                          color: f == selected ? AppColors.primaryDark : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One choice in a [ChoicePills] row.
class PillChoice {
  const PillChoice(this.label, {required this.selected, required this.onTap, this.semantics});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? semantics;
}

/// Equal-width pills in a soft track, like a segmented control.
class ChoicePills extends StatelessWidget {
  const ChoicePills({super.key, required this.choices});

  final List<PillChoice> choices;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F4), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (final c in choices)
            Expanded(
              child: Semantics(
                button: true,
                selected: c.selected,
                label: c.semantics,
                child: TapArea(
                  onTap: c.onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    constraints: const BoxConstraints(minHeight: 38),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.selected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        c.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: c.selected ? FontWeight.w800 : FontWeight.w600,
                          color: c.selected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

IconData dayPartIcon(int hour) {
  if (hour < 5 || hour >= 20) return Icons.bedtime_rounded;
  if (hour < 12) return Icons.wb_twilight_rounded;
  if (hour < 17) return Icons.wb_sunny_rounded;
  return Icons.nights_stay_rounded;
}

String dayPartLabel(int hour, String lang) {
  if (lang == 'bn') return dayPart(hour);
  if (hour < 5) return 'Night';
  if (hour < 12) return 'Morning';
  if (hour < 15) return 'Noon';
  if (hour < 18) return 'Afternoon';
  if (hour < 20) return 'Evening';
  return 'Night';
}

/// Reminder times as tiles ("Morning 8:00 AM"): tap to change, x to remove, + to add.
class TimeTiles extends StatelessWidget {
  const TimeTiles({
    super.key,
    required this.times,
    required this.onEdit,
    required this.onRemove,
    required this.onAdd,
    required this.lang,
  });

  final List<String> times;
  final ValueChanged<String> onEdit;
  final ValueChanged<String> onRemove;
  final VoidCallback onAdd;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final bn = lang == 'bn';
    final add = Semantics(
      button: true,
      label: bn ? 'সময় যোগ করুন' : 'Add time',
      excludeSemantics: true,
      child: Tooltip(
        message: bn ? 'সময় যোগ করুন' : 'Add time',
        child: TapArea(
          onTap: onAdd,
          child: Container(
            constraints: const BoxConstraints(minHeight: _tileHeight),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.45), width: 1.5),
            ),
            child: const Icon(Icons.add_alarm_rounded, color: AppColors.primary, size: 24),
          ),
        ),
      ),
    );
    const gap = 6.0;
    // Up to four times sit on one line with a slim + at the end; more wrap, four to a line.
    if (times.length <= 4) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final t in times) ...[Expanded(child: _tile(t, bn)), const SizedBox(width: gap)],
            if (times.isEmpty)
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    bn ? 'কোনো সময় নেই, + চাপুন' : 'No times yet: tap +',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ),
              ),
            SizedBox(width: 48, child: add),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - gap * 3) / 4;
        return Wrap(
          spacing: gap,
          runSpacing: gap + 4,
          children: [
            for (final t in times) SizedBox(width: w, child: _tile(t, bn)),
            SizedBox(width: w, child: add),
          ],
        );
      },
    );
  }

  static const double _tileHeight = 52;

  Widget _tile(String t, bool bn) {
    final m = minutesOfDay(t);
    final hour = m < 0 ? 8 : m ~/ 60;
    final shown = displayTime(t, lang).replaceFirst('${dayPart(hour)} ', '');
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Semantics(
          button: true,
          label: '${bn ? 'অ্যালার্ম' : 'Alarm'} ${displayTime(t, lang)}',
          hint: bn ? 'সময় বদলাতে চাপুন' : 'Tap to change',
          excludeSemantics: true,
          child: TapArea(
            onTap: () => onEdit(t),
            child: Container(
              constraints: const BoxConstraints(minHeight: _tileHeight),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.softGreen),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(dayPartIcon(hour), size: 14, color: AppColors.warning),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          dayPartLabel(hour, lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      shown,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Semantics(
            button: true,
            label: bn ? 'সময় মুছুন' : 'Remove time',
            excludeSemantics: true,
            child: InkResponse(
              onTap: () => onRemove(t),
              radius: 18,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.close_rounded, size: 14, color: AppColors.error),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Starts today · keeps going · no note": one quiet row that opens the less-used options.
class MoreOptionsRow extends StatelessWidget {
  const MoreOptionsRow({super.key, required this.summary, required this.onTap, required this.bn});

  final String summary;
  final VoidCallback onTap;
  final bool bn;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.event_note_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
