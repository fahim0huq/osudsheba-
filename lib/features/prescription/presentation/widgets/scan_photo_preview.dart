import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// The chosen photo(s): one large preview, or a row of thumbnails for several packets.
class ScanPhotoPreview extends StatelessWidget {
  const ScanPhotoPreview({super.key, required this.photos, required this.onRemove, required this.bn});

  final List<File> photos;
  final ValueChanged<File> onRemove;
  final bool bn;

  @override
  Widget build(BuildContext context) {
    final box = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14.0),
      border: Border.all(color: AppColors.border, width: 1.2),
    );
    if (photos.isEmpty) {
      return Container(
        height: 130,
        decoration: box,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.document_scanner_rounded, size: 36, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              bn ? 'কোনো ছবি নেই' : 'No photo yet',
              style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    if (photos.length == 1) {
      return SizedBox(height: 180, child: _thumb(photos.first, box, double.infinity));
    }
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _thumb(photos[i], box, 110),
      ),
    );
  }

  Widget _thumb(File f, BoxDecoration box, double width) => Stack(
    children: [
      Container(
        width: width,
        decoration: box,
        clipBehavior: Clip.antiAlias,
        child: Image.file(f, fit: BoxFit.cover, width: width, height: double.infinity),
      ),
      Positioned(
        top: 4,
        right: 4,
        child: Material(
          color: Colors.black54,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onRemove(f),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close_rounded, size: 18, color: Colors.white, semanticLabel: bn ? 'সরান' : 'Remove'),
            ),
          ),
        ),
      ),
    ],
  );
}
