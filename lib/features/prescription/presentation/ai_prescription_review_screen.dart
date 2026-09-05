import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/app_secondary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class AiPrescriptionReviewScreen extends ConsumerStatefulWidget {
  final String? ocrText;
  final List<Medicine>? draftMedicines;
  final bool isFallback;

  const AiPrescriptionReviewScreen({
    super.key,
    this.ocrText,
    this.draftMedicines,
    this.isFallback = false,
  });

  @override
  ConsumerState<AiPrescriptionReviewScreen> createState() => _AiPrescriptionReviewScreenState();
}

class _AiPrescriptionReviewScreenState extends ConsumerState<AiPrescriptionReviewScreen> {
  late List<Medicine> _extractedMedicines;
  bool _showOcrText = false;

  @override
  void initState() {
    super.initState();
    _extractedMedicines = widget.draftMedicines != null
        ? List.from(widget.draftMedicines!)
        : [];
  }

  void _editMedicine(int index) async {
    final med = _extractedMedicines[index];
    final nameController = TextEditingController(text: med.name);
    final strengthController = TextEditingController(text: med.strength);
    final doseController = TextEditingController(text: med.dose);
    final timesController = TextEditingController(text: med.times.join(', '));
    String selectedMealRelation = med.mealRelation;
    MedicineForm selectedForm = med.form;

    final durationDays = med.endDate != null && med.startDate != null
        ? med.endDate!.difference(med.startDate!).inDays
        : 7;
    final durationController = TextEditingController(text: durationDays.toString());

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Extracted Medicine'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
               children: [
                 TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                 const SizedBox(height: 8),
                 TextField(controller: strengthController, decoration: const InputDecoration(labelText: 'Strength')),
                 const SizedBox(height: 8),
                 DropdownButtonFormField<MedicineForm>(
                   initialValue: selectedForm,
                   decoration: const InputDecoration(labelText: 'Form'),
                   items: MedicineForm.values
                       .map((val) => DropdownMenuItem(
                           value: val,
                           child: Text(val.name[0].toUpperCase() + val.name.substring(1))))
                       .toList(),
                   onChanged: (val) {
                     if (val != null) {
                       setDialogState(() {
                         selectedForm = val;
                       });
                     }
                   },
                 ),
                 const SizedBox(height: 8),
                 TextField(controller: doseController, decoration: const InputDecoration(labelText: 'Dose Amount')),
                 const SizedBox(height: 8),
                 TextField(
                   controller: timesController,
                   decoration: const InputDecoration(labelText: 'Reminder Times (comma separated)'),
                 ),
                 const SizedBox(height: 8),
                 TextField(
                   controller: durationController,
                   decoration: const InputDecoration(labelText: 'Duration (days)'),
                   keyboardType: TextInputType.number,
                 ),
                 const SizedBox(height: 12),
                 DropdownButtonFormField<String>(
                   initialValue: ['Before Meal', 'After Meal', 'With Meal', 'None'].contains(selectedMealRelation)
                       ? selectedMealRelation
                       : 'After Meal',
                   decoration: const InputDecoration(labelText: 'Meal Relation'),
                   items: ['Before Meal', 'After Meal', 'With Meal', 'None']
                       .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                       .toList(),
                   onChanged: (val) {
                     if (val != null) {
                       setDialogState(() {
                         selectedMealRelation = val;
                       });
                     }
                   },
                 ),
               ],
             ),
           ),
           actions: [
             TextButton(
                 onPressed: () => Navigator.pop(context),
                 child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
             TextButton(
               onPressed: () {
                 final List<String> parsedTimes = timesController.text
                     .split(',')
                     .map((e) => e.trim())
                     .where((e) => e.isNotEmpty)
                     .toList();
                 final days = int.tryParse(durationController.text) ?? 7;
                 final now = DateTime.now();
                 final start = med.startDate ?? now;
                 final end = start.add(Duration(days: days));

                 setState(() {
                   _extractedMedicines[index] = med.copyWith(
                     name: nameController.text,
                     strength: strengthController.text,
                     form: selectedForm,
                     dose: doseController.text,
                     times: parsedTimes.isNotEmpty ? parsedTimes : med.times,
                     mealRelation: selectedMealRelation,
                     startDate: start,
                     endDate: end,
                   );
                 });
                 Navigator.pop(context);
               },
               child: const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
             ),
           ],
         ),
       ),
     );
   }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    final title = lang == 'bn' ? 'এআই পর্যালোচনা' : 'AI Review';

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
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(
                child: Text(
                  lang == 'bn' ? 'প্রেসক্রিপশন এআই পর্যালোচনা' : 'AI Prescription Review',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 20.0,
                      ),
                ),
              ),
              const SizedBox(height: 6.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  lang == 'bn'
                      ? 'শনাক্ত করা ওষুধগুলো পর্যালোচনা করুন। সংরক্ষণ করার পূর্বে প্রয়োজনে তথ্য সংশোধন করুন।'
                      : 'Please review the extracted medicines below. You can modify any drafts before saving.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14.5, height: 1.3),
                ),
              ),
              const SizedBox(height: 12.0),
              if (widget.isFallback)
                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: Container(
                    padding: const EdgeInsets.all(14.0),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.2), width: 1.0),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22.0),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: Text(
                            lang == 'bn'
                                ? 'ডেমো ডাটা প্রদর্শিত হচ্ছে: প্রেসক্রিপশন স্ক্যানটি অস্পষ্ট ছিল। নিচে ওষুধগুলোর তথ্য খুব সতর্কতার সাথে যাচাই করে সেভ করুন।'
                                : 'Showing Demo Fallback Data: The prescription scan was unsuccessful or incomplete. Please review and edit the medicines below carefully before saving.',
                            style: const TextStyle(
                              fontSize: 13.0,
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16.0),

              // Expanding Raw OCR Text Card
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.0),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.description_rounded, color: AppColors.primary),
                        title: Text(
                          lang == 'bn' ? 'প্রেসক্রিপশনের মূল লেখা দেখুন' : 'View Extracted Text',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: Icon(
                          _showOcrText ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.primary,
                        ),
                        onTap: () {
                          setState(() {
                            _showOcrText = !_showOcrText;
                          });
                        },
                      ),
                      if (_showOcrText)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              widget.ocrText ??
                                  (lang == 'bn'
                                      ? 'কোন ওসিআর টেক্সট উপলব্ধ নেই। ডেমো ডাটা প্রদর্শিত হচ্ছে।'
                                      : 'No OCR text available. Demo data is being shown.'),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12.0,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12.0),

              // Safety Warning Panel
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(14.0),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2.0),
                        child: Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20.0),
                      ),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang == 'bn'
                                  ? 'এআই ভুল করতে পারে। ওষুধ খাওয়ার মাত্রা এবং সময় পুনরায় নিশ্চিত হয়ে নিন।'
                                  : 'AI can make mistakes. Please verify medicine name, dose, frequency, timing, and duration before saving.',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              lang == 'bn'
                                  ? 'এটি শুধুমাত্র একটি রিমাইন্ডার টুল এবং কোনো চিকিৎসা পরামর্শ প্রদান করে না। কোনো বিষয় নিয়ে দ্বিমত থাকলে চিকিৎসকের পরামর্শ নিন।'
                                  : 'This app is a medication reminder tool and does not provide medical advice. If unsure, consult your doctor or pharmacist.',
                              style: TextStyle(
                                fontSize: 11.0,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),

              // Extracted list
              Expanded(
                child: _extractedMedicines.isEmpty
                    ? FadeSlideIn(
                        delay: const Duration(milliseconds: 250),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off_rounded, size: 48, color: AppColors.border),
                              const SizedBox(height: 12.0),
                              Text(
                                lang == 'bn'
                                    ? 'কোনো ওষুধ শনাক্ত করা যায়নি।'
                                    : 'No medicines to review.',
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : FadeSlideIn(
                        delay: const Duration(milliseconds: 250),
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _extractedMedicines.length,
                          itemBuilder: (context, index) {
                            final med = _extractedMedicines[index];
                            // Calculate duration in days
                            final durationDays = med.endDate != null && med.startDate != null
                                ? med.endDate!.difference(med.startDate!).inDays
                                : 7;

                            final isLowConfidence = med.name.toLowerCase() == 'unclear' ||
                                med.instruction.contains('[Low confidence');

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10.0),
                              padding: const EdgeInsets.all(14.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(
                                  color: isLowConfidence ? AppColors.warning : AppColors.border,
                                  width: isLowConfidence ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(med.form.icon, color: AppColors.primary, size: 20.0),
                                  ),
                                  const SizedBox(width: 14.0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${med.name} ${med.strength}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 2.0),
                                        Text(
                                          'Dose: ${med.dose} • ${med.mealRelation} • $durationDays days',
                                          style: const TextStyle(fontSize: 12.0, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 2.0),
                                        Text(
                                          'Times: ${med.times.join(", ")}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0, color: AppColors.primaryDark),
                                        ),
                                        if (med.instruction.isNotEmpty) ...[
                                          const SizedBox(height: 2.0),
                                          Text(
                                            'Original: ${med.instruction}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 11.0, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
                                          ),
                                        ],
                                        if (isLowConfidence) ...[
                                          const SizedBox(height: 6.0),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                            decoration: BoxDecoration(
                                              color: AppColors.warning.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(6.0),
                                              border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 14.0),
                                                const SizedBox(width: 4.0),
                                                Text(
                                                  lang == 'bn'
                                                      ? '⚠ তথ্যটি নিশ্চিত করুন'
                                                      : '⚠ Please verify this information',
                                                  style: const TextStyle(
                                                    color: AppColors.warning,
                                                    fontSize: 11.0,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20.0),
                                    onPressed: () => _editMedicine(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20.0),
                                    onPressed: () {
                                      setState(() {
                                        _extractedMedicines.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),

              const SizedBox(height: 12.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: Row(
                  children: [
                    Expanded(
                      child: AppSecondaryButton(
                        text: lang == 'bn' ? 'ম্যানুয়ালি লিখুন' : 'Enter Manually',
                        icon: Icons.edit_note_rounded,
                        onPressed: () => context.push('/add-medicine'),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: AppPrimaryButton(
                        text: lang == 'bn' ? 'নিশ্চিত ও সংরক্ষণ' : 'Confirm Schedule',
                        icon: Icons.check_circle_outline_rounded,
                        onPressed: _extractedMedicines.isNotEmpty
                            ? () {
                                try {
                                  for (final med in _extractedMedicines) {
                                    final savedMed = med.copyWith(
                                      id: const Uuid().v4(),
                                      status: 'active',
                                      createdAt: DateTime.now(),
                                    );
                                    ref.read(medicinesProvider.notifier).addMedicine(savedMed);
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(lang == 'bn' ? 'ওষুধ সূচি তৈরি করা হয়েছে' : 'Schedule created successfully!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                  context.go('/home');
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(lang == 'bn' ? 'সংরক্ষণ ব্যর্থ হয়েছে' : 'Failed to save medicine schedule.'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10.0),
            ],
          ),
        ),
      ),
    );
  }
}
