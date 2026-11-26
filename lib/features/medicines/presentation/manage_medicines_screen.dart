import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import 'widgets/all_medicines_tab.dart';

/// The "Medicines" bottom tab: every saved medicine in one place. Search, add, and tap one
/// to see it, edit it, pause it or delete it.
class ManageMedicinesScreen extends ConsumerWidget {
  const ManageMedicinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bn = ref.watch(appSettingsProvider).language == 'bn';
    return Scaffold(
      appBar: AppBar(
        title: Text(bn ? 'আমার ওষুধ' : 'My medicines',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: const AllMedicinesTab(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'manage-medicines-add',
        onPressed: () => context.go('/add-medicine'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_circle_outline_rounded, size: 26),
        label: Text(bn ? 'ওষুধ যোগ করুন' : 'Add medicine',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
