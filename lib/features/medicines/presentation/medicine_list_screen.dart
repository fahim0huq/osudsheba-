import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/medicine_card.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class MedicineListScreen extends ConsumerStatefulWidget {
  const MedicineListScreen({super.key});

  @override
  ConsumerState<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends ConsumerState<MedicineListScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All' | 'Morning' | 'Afternoon' | 'Night' | 'Missed'

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;
    final medicines = ref.watch(medicinesProvider);
    final logs = ref.watch(doseLogsProvider);

    final now = DateTime.now();
    final todayLogs = logs.where((l) =>
        l.actualTime != null &&
        l.actualTime!.day == now.day &&
        l.actualTime!.month == now.month &&
        l.actualTime!.year == now.year).toList();

    // Apply filtering and search
    final filteredMedicines = medicines.where((med) {
      // Search check
      final matchesSearch = med.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          med.strength.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      // Filter chip check
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Missed') return med.status == 'Missed';

      // Time filters: Morning, Afternoon, Night
      bool matchesTime = false;
      for (final time in med.times) {
        if (_selectedFilter == 'Morning') {
          // Typically AM times
          if (time.toUpperCase().contains('AM')) matchesTime = true;
        } else if (_selectedFilter == 'Afternoon') {
          // E.g., 12:00 PM to 04:59 PM
          if (time.toUpperCase().contains('PM')) {
            final hour = int.tryParse(time.split(':').first) ?? 0;
            if (hour == 12 || (hour >= 1 && hour < 5)) matchesTime = true;
          }
        } else if (_selectedFilter == 'Night') {
          // E.g., 05:00 PM onwards
          if (time.toUpperCase().contains('PM')) {
            final hour = int.tryParse(time.split(':').first) ?? 0;
            if (hour != 12 && hour >= 5) matchesTime = true;
          }
        }
      }
      return matchesTime;
    }).toList();

    final title = lang == 'bn' ? 'ওষুধের তালিকা' : 'Medicines';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 12.0),
            // Search Bar
            FadeSlideIn(
              child: TextField(
                decoration: InputDecoration(
                  hintText: lang == 'bn' ? 'ওষুধ খুঁজুন...' : 'Search medicine...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.0),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.0),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.0),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 14.0),
            
            // Filter chips
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip('All', lang == 'bn' ? 'সব' : 'All'),
                    const SizedBox(width: 8.0),
                    _buildFilterChip('Morning', lang == 'bn' ? 'সকাল' : 'Morning'),
                    const SizedBox(width: 8.0),
                    _buildFilterChip('Afternoon', lang == 'bn' ? 'দুপুর' : 'Afternoon'),
                    const SizedBox(width: 8.0),
                    _buildFilterChip('Night', lang == 'bn' ? 'রাত' : 'Night'),
                    const SizedBox(width: 8.0),
                    _buildFilterChip('Missed', lang == 'bn' ? 'মিস হয়েছে' : 'Missed'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20.0),
            
            // Medicines list
            Expanded(
              child: filteredMedicines.isEmpty
                  ? FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20.0),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.search_off_rounded, size: 40, color: AppColors.primary),
                            ),
                            const SizedBox(height: 16.0),
                            Text(
                              lang == 'bn' ? 'কোন ওষুধ পাওয়া যায়নি' : 'No medicines found matching filters.',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15.0, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    )
                  : FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredMedicines.length,
                        itemBuilder: (context, index) {
                          final med = filteredMedicines[index];
                          final todayMedLogs = todayLogs.where((l) => l.medicineId == med.id).toList();
                          String displayStatus = 'Pending';
                          if (todayMedLogs.any((l) => l.status == 'taken')) {
                            displayStatus = 'Taken';
                          } else if (todayMedLogs.any((l) => l.status == 'skipped')) {
                            displayStatus = 'Skipped';
                          } else if (todayMedLogs.any((l) => l.status == 'snoozed')) {
                            displayStatus = 'Snoozed';
                          } else if (todayMedLogs.any((l) => l.status == 'missed')) {
                            displayStatus = 'Missed';
                          } else {
                            displayStatus = med.status == 'active' ? 'Pending' : med.status;
                          }
                          final displayMed = med.copyWith(status: displayStatus);

                          return MedicineCard(
                            medicine: displayMed,
                            onTap: () {
                              ref.read(selectedMedicineProvider.notifier).state = med;
                              context.push('/medicine-detail', extra: med);
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: GestureDetector(
        onTap: () => context.push('/add-medicine'),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF0D9488)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}
