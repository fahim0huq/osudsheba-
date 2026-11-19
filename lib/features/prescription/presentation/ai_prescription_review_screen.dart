import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/scan/prescription_text_parser.dart';
import '../../../core/utils/time_utils.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/app_secondary_button.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import 'widgets/scan_draft_card.dart';
import 'widgets/scan_draft_editor.dart';

/// Shows the medicines found on a scanned prescription. Nothing is saved until the
/// person has checked them against the paper and confirmed.
class AiPrescriptionReviewScreen extends ConsumerStatefulWidget {
  final String? ocrText;
  final List<ScanDraft>? drafts;

  /// 'scan' (read from a prescription), 'packets' (read from medicine packets) or
  /// 'typed' (entered by the person while looking at the photo).
  final String source;

  const AiPrescriptionReviewScreen({super.key, this.ocrText, this.drafts, this.source = 'scan'});

  @override
  ConsumerState<AiPrescriptionReviewScreen> createState() => _AiPrescriptionReviewScreenState();
}

class _AiPrescriptionReviewScreenState extends ConsumerState<AiPrescriptionReviewScreen> {
  late final List<ScanDraft> _drafts = List.of(widget.drafts ?? const []);

  Future<void> _edit(int index, bool bn) async {
    final updated = await editScanDraft(context, _drafts[index], bn);
    if (updated != null && mounted) setState(() => _drafts[index] = updated);
  }

  Future<void> _confirm(bool bn) async {
    final unreadable = _drafts
        .where((d) => d.medicine.times.isEmpty || invalidTimes(d.medicine.times).isNotEmpty)
        .map((d) => d.medicine.name)
        .toList();
    if (unreadable.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bn
                ? 'এই ওষুধগুলোর সময় ঠিক করুন: ${unreadable.join(', ')}'
                : 'Please fix the reminder times for: ${unreadable.join(', ')}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final ok = await showConfirmDialog(
      context,
      title: bn ? 'সব তথ্য মিলিয়ে দেখেছেন?' : 'Have you checked everything?',
      message: bn
          ? 'ফোন ভুল পড়তে পারে, বিশেষ করে হাতের লেখা। প্রতিটি ওষুধের নাম, মাত্রা ও সময় কাগজের প্রেসক্রিপশনের সাথে মিলিয়ে দেখুন। সন্দেহ থাকলে ডাক্তার বা ফার্মাসিস্টকে জিজ্ঞেস করুন।'
          : 'The phone can misread prescriptions, especially handwriting. Check each medicine name, strength, dose and time against the paper prescription. If unsure, ask your doctor or pharmacist.',
      confirmLabel: bn ? 'হ্যাঁ, মিলিয়ে দেখেছি — সংরক্ষণ' : 'Yes, I checked — save',
      cancelLabel: bn ? 'আবার দেখি' : 'Let me check again',
      destructive: false,
      icon: Icons.fact_check_rounded,
    );
    if (!ok || !mounted) return;
    for (final d in _drafts) {
      ref
          .read(medicinesProvider.notifier)
          .addMedicine(d.medicine.copyWith(id: const Uuid().v4(), status: 'active', createdAt: DateTime.now()));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(bn ? 'ওষুধ সূচি তৈরি করা হয়েছে' : 'Schedule created successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
    context.go('/home');
  }

  void _showText(bool bn) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SelectableText(
            (widget.ocrText ?? '').trim().isEmpty
                ? (bn ? 'কোনো লেখা পড়া যায়নি।' : 'No text was read.')
                : widget.ocrText!,
            style: TextStyle(fontFamily: 'monospace', fontSize: 13.0, color: Colors.grey.shade800),
          ),
        ),
      ),
    );
  }

  String _notice(bool bn, int needCheck) {
    final more = needCheck == 0
        ? ''
        : (bn ? ' হলুদ চিহ্নিত $needCheckটি অবশ্যই দেখুন।' : ' Check the $needCheck marked in yellow.');
    switch (widget.source) {
      case 'typed':
        return bn
            ? 'সংরক্ষণের আগে প্রতিটি ওষুধ আরেকবার কাগজের প্রেসক্রিপশনের সাথে মিলিয়ে নিন।'
            : 'Before saving, check each medicine once more against the paper prescription.';
      case 'packets':
        return bn
            ? 'প্যাকেট থেকে ওষুধের নাম পাওয়া গেছে। প্যাকেটে কখন খাবেন লেখা থাকে না: প্রতিটিতে ✎ চেপে প্রেসক্রিপশন অনুযায়ী সময় ও দিন দিন।'
            : 'Medicine names were found on the packets. Packets do not say when to take them: tap ✎ on each and set the times and days from the prescription.';
      default:
        return bn
            ? 'ফোন প্রেসক্রিপশন পড়ে বাংলাদেশের ওষুধের তালিকার সাথে মিলিয়েছে। ভুল হতে পারে: প্রতিটি ওষুধ কাগজের সাথে মিলিয়ে নিন।$more'
            : 'The phone read the prescription and matched it to a list of Bangladeshi medicines. It can be wrong: check each one against the paper.$more';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bn = ref.watch(appSettingsProvider).language == 'bn';
    final needCheck = _drafts.where((d) => d.needsCheck).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(bn ? 'স্ক্যান মিলিয়ে দেখুন' : 'Check the scan'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (widget.ocrText != null)
            TextButton.icon(
              onPressed: () => _showText(bn),
              icon: const Icon(Icons.description_rounded, size: 18),
              label: Text(bn ? 'পড়া লেখা' : 'Read text'),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20.0),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        _notice(bn, needCheck),
                        style: TextStyle(fontSize: 13.0, color: Colors.red.shade900, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10.0),
              Expanded(
                child: _drafts.isEmpty
                    ? Center(
                        child: Text(
                          bn
                              ? 'কোনো ওষুধ চেনা যায়নি। আরও স্পষ্ট ছবি তুলুন বা নিজে লিখুন।'
                              : 'No medicines recognised. Try a clearer photo or enter them yourself.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _drafts.length,
                        itemBuilder: (context, i) => ScanDraftCard(
                          draft: _drafts[i],
                          bn: bn,
                          onEdit: () => _edit(i, bn),
                          onDelete: () => setState(() => _drafts.removeAt(i)),
                        ),
                      ),
              ),
              Text(
                bn
                    ? 'ওষুধের তালিকা: Rahman ও Khan (2024), Mendeley Data, CC BY 4.0'
                    : 'Medicine list: Rahman & Khan (2024), Mendeley Data, CC BY 4.0',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.0, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  Expanded(
                    child: AppSecondaryButton(
                      text: bn ? 'নিজে লিখুন' : 'Add manually',
                      icon: Icons.edit_note_rounded,
                      onPressed: () => context.push('/add-medicine'),
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: AppPrimaryButton(
                      text: bn ? 'নিশ্চিত ও সংরক্ষণ' : 'Confirm & save',
                      icon: Icons.check_circle_outline_rounded,
                      onPressed: _drafts.isNotEmpty ? () => _confirm(bn) : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
