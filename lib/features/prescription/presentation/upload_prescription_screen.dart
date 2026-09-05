import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/prescription_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/app_secondary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class UploadPrescriptionScreen extends ConsumerStatefulWidget {
  const UploadPrescriptionScreen({super.key});

  @override
  ConsumerState<UploadPrescriptionScreen> createState() => _UploadPrescriptionScreenState();
}

class _UploadPrescriptionScreenState extends ConsumerState<UploadPrescriptionScreen> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final PrescriptionService _prescriptionService = PrescriptionService();

  bool _isLoading = false;
  String _loadingMessage = '';

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    final title = lang == 'bn' ? 'প্রেসক্রিপশন আপলোড' : 'Upload Prescription';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 20.0),
                    Text(
                      _loadingMessage,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeSlideIn(
                      child: Text(
                        lang == 'bn' ? 'প্রেসক্রিপশন স্ক্যান করুন' : 'Scan Your Prescription',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 22.0,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 100),
                      child: Text(
                        lang == 'bn'
                            ? 'আপনার প্রেসক্রিপশনের ছবি তুলুন অথবা আপলোড করুন। আমাদের কৃত্রিম বুদ্ধিমত্তা (AI) স্বয়ংক্রিয়ভাবে ওষুধ এবং সময় শনাক্ত করবে।'
                            : 'Take a picture of your doctor\'s prescription. Our AI will extract the medicine schedules for you.',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12.0),

                    // Image Display or Placeholder
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: Center(
                        child: Container(
                          width: double.infinity,
                          height: 140.0,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(color: AppColors.border, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.01),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: _imageFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14.0),
                                  child: Image.file(_imageFile!, fit: BoxFit.cover),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.document_scanner_rounded, size: 32, color: AppColors.primary),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Text(
                                      lang == 'bn' ? 'কোনো ছবি নির্বাচন করা হয়নি' : 'No prescription selected',
                                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10.0),

                    // Camera and Gallery buttons
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 300),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.camera_alt_rounded, size: 18),
                              label: Text(lang == 'bn' ? 'ছবি তুলুন' : 'Take Photo', style: const TextStyle(fontSize: 13.0)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10.0),
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                              ),
                              onPressed: () => _pickImage(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.photo_library_rounded, size: 18),
                              label: Text(lang == 'bn' ? 'গ্যালারি থেকে নিন' : 'Choose Gallery', style: const TextStyle(fontSize: 13.0)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10.0),
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                              ),
                              onPressed: () => _pickImage(ImageSource.gallery),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12.0),

                    // Image Quality Tips
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 400),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang == 'bn' ? '📸 স্পষ্ট স্ক্যানের জন্য টিপস:' : '📸 Tips for a clear scan:',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark, fontSize: 13.5),
                            ),
                            const SizedBox(height: 6.0),
                            _buildTipRow(Icons.wb_sunny_rounded, lang == 'bn' ? 'পর্যাপ্ত আলো ব্যবহার করুন' : 'Use good lighting'),
                            _buildTipRow(Icons.crop_free_rounded, lang == 'bn' ? 'প্রেসক্রিপশন সমানভাবে সমতলে রাখুন' : 'Keep prescription flat'),
                            _buildTipRow(Icons.fullscreen_rounded, lang == 'bn' ? 'পুরো পাতাটি ফ্রেমের মধ্যে রাখুন' : 'Capture the full page'),
                            _buildTipRow(Icons.blur_off_rounded, lang == 'bn' ? 'ঝাপসা ছবি পরিহার করুন' : 'Avoid blurry photos'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12.0),

                    // Action buttons
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 500),
                      child: AppPrimaryButton(
                        text: lang == 'bn' ? 'প্রেসক্রিপশন বিশ্লেষণ করুন' : 'Analyze Prescription',
                        icon: Icons.analytics_rounded,
                        onPressed: _imageFile != null
                            ? () async {
                                setState(() {
                                  _isLoading = true;
                                  _loadingMessage = lang == 'bn'
                                      ? 'প্রেসক্রিপশন বিশ্লেষণ করা হচ্ছে...'
                                      : 'Analyzing prescription...';
                                });
                                try {
                                  final idToken = await ref.read(authServiceProvider).getIdToken();
                                  final result = await _prescriptionService.analyzePrescription(_imageFile!, idToken);
                                  if (!context.mounted) return;
                                  if (result.medicines.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(lang == 'bn'
                                            ? 'কোনো ওষুধ শনাক্ত করা যায়নি। অনুগ্রহ করে ম্যানুয়ালি যোগ করুন।'
                                            : 'No medicines detected. Please enter them manually.'),
                                        backgroundColor: AppColors.warning,
                                      ),
                                    );
                                  }
                                  context.push('/ai-prescription-review', extra: {
                                    'ocrText': result.rawText,
                                    'draftMedicines': result.medicines,
                                    'isFallback': false,
                                  });
                                } catch (e) {
                                  if (!context.mounted) return;
                                  _showAnalysisErrorOptions(context, e.toString(), lang);
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isLoading = false;
                                    });
                                  }
                                }
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    AppSecondaryButton(
                      text: lang == 'bn' ? 'নিজে নিজে লিখুন' : 'Enter Manually Instead',
                      icon: Icons.edit_note,
                      onPressed: () => context.push('/add-medicine'),
                    ),
                    const SizedBox(height: 10.0),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTipRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 16.0, color: AppColors.primary),
          const SizedBox(width: 8.0),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.0))),
        ],
      ),
    );
  }

  void _showAnalysisErrorOptions(BuildContext context, String errorMessage, String lang) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 24),
              const SizedBox(width: 8),
              Text(lang == 'bn' ? 'বিশ্লেষণ সম্পন্ন হয়নি' : 'Analysis Unsuccessful'),
            ],
          ),
          content: Text(lang == 'bn'
              ? 'আমরা প্রেসক্রিপশনটি বিশ্লেষণ করতে পারিনি।\n\nত্রুটি: $errorMessage\n\nদয়া করে আবার চেষ্টা করুন অথবা ম্যানুয়ালি ওষুধ যুক্ত করুন।'
              : 'We could not analyze the prescription.\n\nDetails: $errorMessage\n\nPlease retry or enter the medicines manually.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(lang == 'bn' ? 'আবার চেষ্টা করুন' : 'Retry'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/add-medicine');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(lang == 'bn' ? 'ম্যানুয়ালি লিখুন' : 'Enter Manually'),
            ),
          ],
        );
      },
    );
  }
}
