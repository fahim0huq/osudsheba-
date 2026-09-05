import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends ConsumerState<LanguageSettingsScreen> {
  late String _tempLanguage;

  @override
  void initState() {
    super.initState();
    _tempLanguage = ref.read(appSettingsProvider).language;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    final title = lang == 'bn' ? 'ভাষা নির্ধারণ' : 'Language Settings';

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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(
                child: Text(
                  lang == 'bn' ? 'অ্যাপের ভাষা পরিবর্তন করুন' : 'App Language',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                ),
              ),
              const SizedBox(height: 8.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  lang == 'bn'
                      ? 'আপনার পছন্দের ভাষা নির্বাচন করুন।'
                      : 'Choose your preferred language for menus, alerts, and instructions.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14.5, height: 1.3),
                ),
              ),
              const SizedBox(height: 28.0),

              // Selection list
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: RadioGroup<String>(
                    groupValue: _tempLanguage,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _tempLanguage = val;
                        });
                      }
                    },
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          title: Text('বাংলা (Bengali)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          value: 'bn',
                          activeColor: AppColors.primary,
                        ),
                        Divider(height: 1, color: AppColors.border),
                        RadioListTile<String>(
                          title: Text('English', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          value: 'en',
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: AppPrimaryButton(
                  text: lang == 'bn' ? 'সংরক্ষণ করুন' : 'Save',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () {
                    ref.read(appSettingsProvider.notifier).setLanguage(_tempLanguage);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_tempLanguage == 'bn' ? 'ভাষা পরিবর্তন করা হয়েছে!' : 'Language updated successfully!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    context.pop();
                  },
                ),
              ),
              const SizedBox(height: 16.0),
            ],
          ),
        ),
      ),
    );
  }
}
