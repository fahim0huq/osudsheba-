import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/mock_models.dart';
import 'tap_area.dart';
import '../../core/utils/dose_text.dart';

class MedicineCard extends StatefulWidget {
  final Medicine medicine;
  final VoidCallback onTap;
  final String language;

  const MedicineCard({super.key,
    required this.medicine,
    required this.onTap,
    this.language = 'en',
  });

  static const Map<String, String> _bnStatus = {
    'taken': 'খাওয়া হয়েছে',
    'snoozed': 'পরে মনে করাবে',
    'skipped': 'বাদ দেওয়া',
    'missed': 'মিস হয়েছে',
    'pending': 'বাকি আছে',
    'not today': 'আজ নয়',
    'paused': 'বন্ধ আছে',
    'completed': 'শেষ হয়েছে',
  };

  static const Map<String, String> _bnMeal = {
    'Before Meal': 'খাবারের আগে',
    'After Meal': 'খাবারের পরে',
    'With Meal': 'খাবারের সাথে',
  };

  @override
  State<MedicineCard> createState() => _MedicineCardState();
}

class _MedicineCardState extends State<MedicineCard> with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.02,
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scale = 1.0 - _controller.value;

    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;

    final String displayStatus = widget.medicine.status;

    switch (displayStatus.toLowerCase()) {
      case 'taken':
        statusColor = AppColors.success;
        statusBgColor = const Color(0xFFDCFCE7); // extremely soft success green
        statusIcon = Icons.check_circle;
        break;
      case 'snoozed':
        statusColor = AppColors.warning;
        statusBgColor = const Color(0xFFFEF3C7); // extremely soft amber
        statusIcon = Icons.snooze;
        break;
      case 'skipped':
        statusColor = AppColors.textSecondary;
        statusBgColor = const Color(0xFFF3F4F6); // extremely soft gray
        statusIcon = Icons.block;
        break;
      case 'missed':
        statusColor = AppColors.error;
        statusBgColor = const Color(0xFFFEE2E2); // extremely soft red
        statusIcon = Icons.error_outline;
        break;
      default: // Pending
        statusColor = AppColors.accent;
        statusBgColor = const Color(0xFFDBEAFE); // extremely soft blue
        statusIcon = Icons.schedule;
    }

    // At large text sizes the badge would squeeze the medicine name to a few letters,
    // so it moves under the details instead of sitting beside them.
    final largeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.3;
    final statusBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: statusBgColor,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 18),
          const SizedBox(width: 4.0),
          Flexible(
            child: Text(
              widget.language == 'bn'
                  ? (MedicineCard._bnStatus[displayStatus.toLowerCase()] ?? displayStatus)
                  : displayStatus,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
            ),
          ),
        ],
      ),
    );

    return TapArea(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: Transform.scale(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8.0),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: AppColors.border, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            children: [
              // Icon representation of medicine form
              Container(
                padding: const EdgeInsets.all(9.0),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.medicine.form.icon,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12.0),
              // Medicine details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.medicine.name} ${widget.medicine.strength}'.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      [
                        doseLabel(widget.medicine, widget.language),
                        if (widget.medicine.mealRelation.isNotEmpty && widget.medicine.mealRelation != 'None')
                          widget.language == 'bn'
                              ? (MedicineCard._bnMeal[widget.medicine.mealRelation] ?? widget.medicine.mealRelation)
                              : widget.medicine.mealRelation,
                      ].where((e) => e.trim().isNotEmpty).join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 3.0),
                    Row(
                      children: [
                        const Icon(Icons.access_time_filled, size: 18, color: AppColors.primary),
                        const SizedBox(width: 4.0),
                        Expanded(
                          child: Text(
                            widget.medicine.times.join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (largeText) ...[
                      const SizedBox(height: 6.0),
                      statusBadge,
                    ],
                  ],
                ),
              ),
              if (!largeText) ...[
                const SizedBox(width: 8.0),
                statusBadge,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
