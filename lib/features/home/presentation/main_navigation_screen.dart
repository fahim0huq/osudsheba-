import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import 'home_screen.dart';
import '../../medicines/presentation/add_medicine_screen.dart';
import '../../prescription/presentation/upload_prescription_screen.dart';
import '../../adherence/presentation/adherence_dashboard_screen.dart';
import '../../caregiver/presentation/caregiver_dashboard_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const MainNavigationScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
  }

  @override
  void didUpdateWidget(MainNavigationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _currentIndex = widget.initialTab;
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    
    setState(() {
      _currentIndex = index;
    });

    // Update GoRouter to keep current route matched and back history logical
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/add-medicine');
        break;
      case 2:
        context.go('/upload-prescription');
        break;
      case 3:
        context.go('/adherence');
        break;
      case 4:
        context.go('/caregiver');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    final List<Widget> screens = [
      const HomeScreen(),
      const AddMedicineScreen(),
      const UploadPrescriptionScreen(),
      const AdherenceDashboardScreen(),
      const CaregiverDashboardScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildCustomNavBar(context, lang),
    );
  }

  Widget _buildCustomNavBar(BuildContext context, String lang) {
    final tabs = [
      {
        'icon': Icons.home_outlined,
        'selectedIcon': Icons.home_rounded,
        'label': lang == 'bn' ? 'হোম' : 'Home',
      },
      {
        'icon': Icons.add_circle_outline_rounded,
        'selectedIcon': Icons.add_circle_rounded,
        'label': lang == 'bn' ? 'যোগ করুন' : 'Add',
      },
      {
        'icon': Icons.document_scanner_outlined,
        'selectedIcon': Icons.document_scanner_rounded,
        'label': lang == 'bn' ? 'স্ক্যান' : 'Scan',
      },
      {
        'icon': Icons.analytics_outlined,
        'selectedIcon': Icons.analytics_rounded,
        'label': lang == 'bn' ? 'রিপোর্ট' : 'Report',
      },
      {
        'icon': Icons.people_outline_rounded,
        'selectedIcon': Icons.people_rounded,
        'label': lang == 'bn' ? 'তত্ত্বাবধায়ক' : 'Family',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 20.0,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.03),
            blurRadius: 10.0,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (index) {
              final isSelected = _currentIndex == index;
              final tab = tabs[index];

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: isSelected,
                  label: tab['label'] as String,
                  excludeSemantics: true,
                  child: GestureDetector(
                  onTap: () => _onTabTapped(index),
                  behavior: HitTestBehavior.opaque,
                  // At least 64 high, grows with larger text instead of clipping the label.
                  // (Not Container(alignment:): that expands to all the height the bottom
                  // bar is offered, i.e. the whole screen, leaving no room for the page.)
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64.0),
                    child: Center(
                    heightFactor: 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOutCubic,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSelected ? 12.0 : 8.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.10)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16.0),
                        border: isSelected
                            ? Border.all(
                                color: AppColors.primary.withValues(alpha: 0.18),
                                width: 1.0,
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: isSelected ? 1.08 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutBack,
                            child: Icon(
                              isSelected
                                  ? (tab['selectedIcon'] as IconData)
                                  : (tab['icon'] as IconData),
                              color: isSelected
                                  ? AppColors.primaryDark
                                  : AppColors.textSecondary,
                              size: 26.0,
                            ),
                          ),
                          const SizedBox(height: 3.0),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primaryDark
                                  : AppColors.textSecondary,
                              letterSpacing: isSelected ? -0.2 : -0.1,
                            ),
                            child: Text(
                              tab['label'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                  ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
