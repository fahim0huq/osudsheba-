import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/app_secondary_button.dart';

import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/empty_state.dart';

class AdherenceDashboardScreen extends ConsumerWidget {
  const AdherenceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;
    final logs = ref.watch(doseLogsProvider);

    final stats = ref.watch(adherenceStatsProvider);
    final totalLogs = stats.totalLogs;

    final title = lang == 'bn' ? 'ওষুধ মেনে চলার রিপোর্ট' : 'Adherence Dashboard';

    if (totalLogs == 0) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: EmptyState(
          title: lang == 'bn' ? 'মেনে চলার হিস্টরি নেই' : 'No Adherence History',
          message: lang == 'bn'
              ? 'ওষুধ নেওয়া শুরু করুন এবং হিস্টরি ট্র্যাক করুন!'
              : 'You haven\'t logged any doses yet. Start marking doses to track your progress!',
          icon: Icons.analytics_outlined,
          primaryActionLabel: lang == 'bn' ? 'ওষুধের তালিকায় যান' : 'Go to Medicines',
          onPrimaryAction: () => context.go('/medicines'),
        ),
      );
    }
    final takenCount = stats.takenCount;
    final missedCount = stats.missedCount;
    final skippedCount = stats.skippedCount;
    final lateCount = stats.lateCount;
    final snoozedCount = stats.snoozedCount;

    final int adherencePercent = stats.percentage;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Adherence score card
              FadeSlideIn(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang == 'bn' ? 'মোট ওষুধ মেনে চলা' : 'Overall Adherence',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0, color: Colors.white),
                              ),
                              const SizedBox(height: 6.0),
                              Text(
                                lang == 'bn'
                                    ? 'আপনি সুস্থ থাকতে নিয়মিত ওষুধ খাচ্ছেন।'
                                    : 'Your general adherence score for the last 30 days.',
                                style: TextStyle(fontSize: 13.0, color: Colors.white.withValues(alpha: 0.85), height: 1.3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        Container(
                          width: 76,
                          height: 76,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$adherencePercent%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28.0),

              // Weekly adherence chart
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  lang == 'bn' ? 'সাপ্তাহিক অগ্রগতি' : 'Weekly Adherence Trend',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 12.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: Builder(
                  builder: (context) {
                    final now = DateTime.now();
                    final last7Days = List.generate(7, (index) {
                      return now.subtract(Duration(days: 6 - index));
                    });

                    String formatDayName(DateTime date) {
                      const bnDays = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহস্পতি', 'শুক্র', 'শনি', 'রবি'];
                      const enDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                      final idx = date.weekday - 1;
                      return lang == 'bn' ? bnDays[idx] : enDays[idx];
                    }

                    final List<BarChartGroupData> barGroups = [];
                    for (int i = 0; i < 7; i++) {
                      final day = last7Days[i];
                      final dayLogs = logs.where((l) {
                        if (l.actualTime == null) return false;
                        return l.actualTime!.day == day.day &&
                            l.actualTime!.month == day.month &&
                            l.actualTime!.year == day.year;
                      }).toList();

                      final dayTotal = dayLogs.length;
                      final dayTaken = dayLogs.where((l) => l.status == 'taken' || l.status == 'late').length;
                      final double dayAdherence = dayTotal > 0 ? (dayTaken / dayTotal * 100) : 0.0;
                      
                      barGroups.add(_makeGroupData(i, dayAdherence));
                    }

                    return SizedBox(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: 100,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  final int idx = value.toInt();
                                  if (idx >= 0 && idx < 7) {
                                    final date = last7Days[idx];
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        formatDayName(date),
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: barGroups,
                        ),
                      ),
                    );
                  }
                ),
              ),
              const SizedBox(height: 28.0),

              // Stats Grid
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  lang == 'bn' ? 'ওষুধ খাওয়ার সংক্ষিপ্ত তথ্য' : 'Dose Breakdown',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 12.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.1,
                  children: [
                    _buildStatTile(lang == 'bn' ? 'খাওয়া হয়েছে' : 'Taken', takenCount.toString(), AppColors.success),
                    _buildStatTile(lang == 'bn' ? 'মিস হয়েছে' : 'Missed', missedCount.toString(), AppColors.error),
                    _buildStatTile(lang == 'bn' ? 'বাদ দেওয়া' : 'Skipped', skippedCount.toString(), AppColors.textSecondary),
                    _buildStatTile(lang == 'bn' ? 'দেরি হবে' : 'Snoozed', snoozedCount.toString(), AppColors.warning),
                    _buildStatTile(lang == 'bn' ? 'দেরিতে খাওয়া' : 'Late', lateCount.toString(), Colors.purple),
                    _buildStatTile(lang == 'bn' ? 'মোট ডোজ' : 'Total Doses', totalLogs.toString(), AppColors.primary),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),

              // Actions
              FadeSlideIn(
                delay: const Duration(milliseconds: 350),
                child: AppPrimaryButton(
                  text: lang == 'bn' ? 'বিস্তারিত হিস্টরি দেখুন' : 'View History',
                  icon: Icons.history_rounded,
                  onPressed: () => context.push('/adherence-history'),
                ),
              ),
              const SizedBox(height: 12.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 400),
                child: AppSecondaryButton(
                  text: lang == 'bn' ? 'ওষুধ খাওয়ার পরামর্শ' : 'Medicine Tips',
                  icon: Icons.lightbulb_outline_rounded,
                  onPressed: () => context.push('/adherence-insights'),
                ),
              ),
              const SizedBox(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: y > 75 ? AppColors.primary : AppColors.warning,
          width: 14,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
