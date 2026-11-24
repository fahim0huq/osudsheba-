import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import 'widgets/all_medicines_tab.dart';
import 'widgets/today_doses_tab.dart';

/// Opened from the Home button. Two tabs:
/// Today = every dose today by time, tick a circle to record it;
/// All medicines = search, add, and Edit / Pause / Delete from a sheet.
class TodaysMedicinesScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const TodaysMedicinesScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<TodaysMedicinesScreen> createState() => _TodaysMedicinesScreenState();
}

class _TodaysMedicinesScreenState extends ConsumerState<TodaysMedicinesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bn = ref.watch(appSettingsProvider).language == 'bn';
    return Scaffold(
      appBar: AppBar(
        title: Text(bn ? 'আজকের ওষুধ' : "Today's medicines",
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(14)),
            child: TabBar(
              controller: _tabs,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 2, offset: Offset(0, 1))],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.primaryDark,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              tabs: [
                Tab(height: 44, text: bn ? 'আজ' : 'Today'),
                Tab(height: 44, text: bn ? 'সব ওষুধ' : 'All medicines'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(controller: _tabs, children: const [TodayDosesTab(), AllMedicinesTab()]),
      floatingActionButton: _tabs.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/add-medicine'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 26),
              label: Text(bn ? 'ওষুধ যোগ করুন' : 'Add medicine',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}
