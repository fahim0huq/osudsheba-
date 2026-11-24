import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';

/// Optional photo of the medicine (pack or pill), shown on the alarm so the right one is taken.
/// Sits at the end of the medicine-name field (so the form still fits on one screen): a camera
/// icon, or the photo once there is one. Tapping offers Take photo / From gallery / Remove.
/// The photo is copied into the app's own folder, so it stays when the camera roll is cleaned.
class MedicinePhotoButton extends StatelessWidget {
  final String? path;
  final ValueChanged<String?> onChanged;
  final bool bn;

  /// Size of the square. Large ones (the Add Medicine header) also say "Add photo".
  final double size;
  const MedicinePhotoButton({super.key, required this.path, required this.onChanged, required this.bn, this.size = 40});

  bool get _has => path != null && path!.isNotEmpty;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source, maxWidth: 1200, imageQuality: 75);
      if (picked == null) return;
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/medicine_photos');
      await dir.create(recursive: true);
      final saved = await File(picked.path).copy('${dir.path}/${const Uuid().v4()}.jpg');
      onChanged(saved.path);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(bn
            ? 'ছবি নেওয়া যায়নি। ক্যামেরার অনুমতি দেওয়া আছে কিনা দেখুন।'
            : 'Could not get the photo. Check the camera permission.'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _menu(BuildContext context) async {
    ListTile item(IconData icon, String text, VoidCallback onTap, {Color color = AppColors.textPrimary}) => ListTile(
          minTileHeight: 58,
          leading: Icon(icon, color: color, size: 28),
          title: Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color)),
          onTap: () {
            Navigator.of(context).pop();
            onTap();
          },
        );
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              bn ? 'ওষুধের ছবি অ্যালার্মে দেখাবে, যাতে ঠিক ওষুধটি খান।' : 'The photo is shown on the alarm, so you take the right medicine.',
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ),
          item(Icons.photo_camera_rounded, bn ? 'ছবি তুলুন' : 'Take a photo', () => _pick(context, ImageSource.camera)),
          item(Icons.photo_library_rounded, bn ? 'গ্যালারি থেকে নিন' : 'Choose from gallery',
              () => _pick(context, ImageSource.gallery)),
          if (_has)
            item(Icons.delete_outline_rounded, bn ? 'ছবি সরান' : 'Remove photo', () => onChanged(null),
                color: AppColors.error),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && size <= 60) return const SizedBox.shrink();
    return Tooltip(
      message: bn ? 'ওষুধের ছবি' : 'Medicine photo',
      child: InkWell(
        onTap: () => _menu(context),
        borderRadius: BorderRadius.circular(size > 60 ? 20 : 10),
        child: Padding(
          padding: EdgeInsets.all(size > 60 ? 0 : 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size > 60 ? 18 : 8),
            child: SizedBox(
              width: size,
              height: size,
              child: _has
                  ? Image.file(File(path!), fit: BoxFit.cover, errorBuilder: (_, _, _) => _camera())
                  : _camera(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _camera() {
    const icon = Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 24);
    if (size <= 60) return Container(color: AppColors.primaryLight, child: icon);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.5),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 30),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(bn ? 'ছবি দিন' : 'Add photo',
                style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
