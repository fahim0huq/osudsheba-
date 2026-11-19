import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/tap_area.dart';

class AdherenceHistoryScreen extends ConsumerStatefulWidget {
  const AdherenceHistoryScreen({super.key});

  @override
  ConsumerState<AdherenceHistoryScreen> createState() => _AdherenceHistoryScreenState();
}

class _AdherenceHistoryScreenState extends ConsumerState<AdherenceHistoryScreen> {
  String _selectedFilter = 'All'; // 'All' | 'Taken' | 'Missed' | 'Skipped' | 'Late'

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;
    final logs = ref.watch(doseLogsProvider);

    // Apply filtering
    final filteredLogs = logs.where((log) {
      if (_selectedFilter == 'All') return true;
      return log.status.toLowerCase() == _selectedFilter.toLowerCase();
    }).toList();

    final title = lang == 'bn' ? 'ওষুধ খাওয়ার ইতিহাস' : 'Dose History';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 12.0),
              // Filter chips
              FadeSlideIn(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterChip('All', lang == 'bn' ? 'সব' : 'All'),
                      const SizedBox(width: 8.0),
                      _buildFilterChip('Taken', lang == 'bn' ? 'খাওয়া হয়েছে' : 'Taken'),
                      const SizedBox(width: 8.0),
                      _buildFilterChip('Missed', lang == 'bn' ? 'মিস হয়েছে' : 'Missed'),
                      const SizedBox(width: 8.0),
                      _buildFilterChip('Skipped', lang == 'bn' ? 'বাদ দেওয়া' : 'Skipped'),
                      const SizedBox(width: 8.0),
                      _buildFilterChip('Late', lang == 'bn' ? 'দেরি হয়েছে' : 'Late'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20.0),

              // Logs List
              Expanded(
                child: filteredLogs.isEmpty
                    ? FadeSlideIn(
                        delay: const Duration(milliseconds: 100),
                        child: Center(
                          child: Text(
                            lang == 'bn' ? 'কোন ইতিহাস পাওয়া যায়নি' : 'No history logs found.',
                            style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    : FadeSlideIn(
                        delay: const Duration(milliseconds: 100),
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredLogs.length,
                          itemBuilder: (context, index) {
                            final log = filteredLogs[index];
                            Color statusColor;
                            IconData statusIcon;

                            switch (log.status.toLowerCase()) {
                              case 'taken':
                                statusColor = AppColors.success;
                                statusIcon = Icons.check_circle_rounded;
                                break;
                              case 'missed':
                                statusColor = AppColors.error;
                                statusIcon = Icons.cancel_rounded;
                                break;
                              case 'skipped':
                                statusColor = AppColors.textSecondary;
                                statusIcon = Icons.block_rounded;
                                break;
                              case 'snoozed':
                                statusColor = AppColors.warning;
                                statusIcon = Icons.snooze_rounded;
                                break;
                              case 'late':
                                statusColor = AppColors.warning;
                                statusIcon = Icons.watch_later_rounded;
                                break;
                              default:
                                statusColor = AppColors.primary;
                                statusIcon = Icons.circle;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              padding: const EdgeInsets.all(14.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10.0),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(statusIcon, color: statusColor, size: 22),
                                  ),
                                  const SizedBox(width: 14.0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          log.medicineName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 4.0),
                                        Text(
                                          '${lang == 'bn' ? 'নির্ধারিত সময়' : 'Scheduled'}: ${log.scheduledTime}',
                                          style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                        ),
                                        if (log.takenTime != null) ...[
                                          const SizedBox(height: 2.0),
                                          Text(
                                            '${lang == 'bn' ? 'খেয়েছেন' : 'Taken at'}: ${log.takenTime!.hour}:${log.takenTime!.minute.toString().padLeft(2, '0')}',
                                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13.5),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    child: Text(
                                      log.status,
                                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13.5),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return TapArea(
      onTap: () {
        setState(() {
          _selectedFilter = filterKey;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 13.0,
          ),
        ),
      ),
    );
  }
}
