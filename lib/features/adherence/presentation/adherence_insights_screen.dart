import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/ai_suggestion_service.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class AdherenceInsightsScreen extends ConsumerWidget {
  const AdherenceInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    final medicines = ref.watch(medicinesProvider);
    final doseLogs = ref.watch(doseLogsProvider);
    final patientProfile = ref.watch(patientProfileProvider);

    final suggestionEngine = AiSuggestionService();
    final suggestions = suggestionEngine.generateSuggestions(
      medicines: medicines,
      doseLogs: doseLogs,
      settings: settings,
      patientProfile: patientProfile,
    );

    final title = lang == 'bn' ? 'ব্যবহার বিশ্লেষণ ও এআই টিপস' : 'AI Behavioral Insights';

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
              FadeSlideIn(
                child: Text(
                  lang == 'bn' ? 'এআই আচরণগত টিপস' : 'AI Suggestions',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                ),
              ),
              const SizedBox(height: 6.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  lang == 'bn'
                      ? 'আপনার ওষুধ খাওয়ার আচরণ বিশ্লেষণ করে এআই নিচের পরামর্শগুলো প্রদান করছে।'
                      : 'Based on your local adherence behavior, the AI suggests the following changes.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14.5, height: 1.3),
                ),
              ),
              const SizedBox(height: 24.0),

              if (suggestions.isEmpty)
                FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Text(
                        lang == 'bn' ? 'কোনো নতুন এআই পরামর্শ নেই।' : 'No AI suggestions currently available.',
                        style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return FadeSlideIn(
                      delay: Duration(milliseconds: 150 + (index * 50)),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        padding: const EdgeInsets.all(18.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.01),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.psychology_rounded,
                                color: AppColors.primary,
                                size: 26.0,
                              ),
                            ),
                            const SizedBox(width: 16.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang == 'bn' ? 'এআই পরামর্শ #${index + 1}' : 'AI Suggestion #${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 6.0),
                                  Text(
                                    suggestion,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      height: 1.4,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }
}
