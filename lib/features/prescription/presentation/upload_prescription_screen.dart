import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/prescription_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/app_secondary_button.dart';
import 'widgets/scan_photo_preview.dart';

/// Scan: photograph a prescription (printed: read automatically; handwritten: type the
/// names while looking at the photo) or the medicine packets. All on the phone, free.
class UploadPrescriptionScreen extends ConsumerStatefulWidget {
  const UploadPrescriptionScreen({super.key});

  @override
  ConsumerState<UploadPrescriptionScreen> createState() => _UploadPrescriptionScreenState();
}

class _UploadPrescriptionScreenState extends ConsumerState<UploadPrescriptionScreen> {
  final ImagePicker _picker = ImagePicker();
  final PrescriptionService _service = PrescriptionService();
  bool _packets = false;
  final List<File> _photos = [];
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    try {
      if (_packets && source == ImageSource.gallery) {
        final files = await _picker.pickMultiImage(maxWidth: 2400, maxHeight: 2400);
        setState(() => _photos.addAll(files.map((f) => File(f.path))));
        return;
      }
      final f = await _picker.pickImage(source: source, maxWidth: 2400, maxHeight: 2400);
      if (f == null) return;
      setState(() {
        if (!_packets) _photos.clear();
        _photos.add(File(f.path));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _read(bool bn) async {
    setState(() => _busy = true);
    try {
      final result = _packets
          ? await _service.analyzePackets([for (final f in _photos) f.path])
          : await _service.analyzePrescription(_photos.first.path);
      if (!mounted) return;
      context.push(
        '/ai-prescription-review',
        extra: {'ocrText': result.rawText, 'drafts': result.drafts, 'source': _packets ? 'packets' : 'scan'},
      );
    } catch (e) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(bn ? 'পড়া যায়নি' : 'Could not read the photo'),
          content: Text(
            bn
                ? 'ছবি থেকে লেখা পড়া যায়নি। আরও আলোতে, সোজা করে আবার ছবি তুলুন, অথবা নিজে লিখুন।\n\n($e)'
                : 'The text on the photo could not be read. Try again in better light, holding the phone straight, or type the medicines yourself.\n\n($e)',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(bn ? 'ঠিক আছে' : 'OK'))],
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bn = ref.watch(appSettingsProvider).language == 'bn';
    final has = _photos.isNotEmpty;

    if (_busy) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(bn ? 'পড়া হচ্ছে...' : 'Reading...', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(bn ? 'স্ক্যান' : 'Scan'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.description_rounded),
                    label: Text(bn ? 'প্রেসক্রিপশন' : 'Prescription'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.medication_rounded),
                    label: Text(bn ? 'ওষুধের প্যাকেট' : 'Medicine packets'),
                  ),
                ],
                selected: {_packets},
                onSelectionChanged: (s) => setState(() {
                  _packets = s.first;
                  _photos.clear();
                }),
              ),
              const SizedBox(height: 8),
              Text(
                _packets
                    ? (bn
                          ? 'কেনা ওষুধের পাতা বা বাক্সের ছবি তুলুন (একাধিক দেওয়া যায়)। প্যাকেটের ছাপা নাম ও শক্তি ফোন পড়বে, সময় আপনি দেবেন।'
                          : 'Photograph the strips or boxes you bought (several is fine). The phone reads the printed name and strength; you add the times.')
                    : (bn
                          ? 'ছাপা প্রেসক্রিপশন ফোন নিজেই পড়বে। হাতে লেখা হলে ছবি দেখে নাম লিখুন, ফোন নাম খুঁজে দেবে। ইন্টারনেট লাগে না।'
                          : 'A printed prescription is read automatically. If it is handwritten, type the names while looking at the photo and the phone finds them. No internet needed.'),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.3),
              ),
              const SizedBox(height: 10),
              ScanPhotoPreview(photos: _photos, bn: bn, onRemove: (f) => setState(() => _photos.remove(f))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: Text(_packets && has ? (bn ? 'আরও ছবি' : 'Add photo') : (bn ? 'ছবি তুলুন' : 'Take photo')),
                      onPressed: () => _pick(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: Text(bn ? 'গ্যালারি' : 'Gallery'),
                      onPressed: () => _pick(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                bn
                    ? '💡 ভালো আলো, কাগজ সমান রাখুন, পুরো লেখা ফ্রেমে রাখুন।'
                    : '💡 Good light, paper flat, all the text in the frame.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              AppPrimaryButton(
                text: _packets
                    ? (bn ? 'প্যাকেট থেকে ওষুধ খুঁজুন' : 'Find medicines on packets')
                    : (bn ? 'ছাপা প্রেসক্রিপশন পড়ুন' : 'Read printed prescription'),
                icon: Icons.document_scanner_rounded,
                onPressed: has ? () => _read(bn) : null,
              ),
              if (!_packets) ...[
                const SizedBox(height: 8),
                AppSecondaryButton(
                  text: bn ? 'হাতে লেখা? ছবি দেখে লিখুন' : 'Handwritten? Type from the photo',
                  icon: Icons.keyboard_rounded,
                  onPressed: has ? () => context.push('/prescription-photo-entry', extra: _photos.first.path) : null,
                ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.edit_note_rounded),
                label: Text(bn ? 'ছবি ছাড়া নিজে লিখুন' : 'Enter without a photo'),
                onPressed: () => context.go('/add-medicine'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
