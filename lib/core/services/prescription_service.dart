import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ocr_service.dart';
import 'scan/medicine_catalog.dart';
import 'scan/prescription_text_parser.dart';

class PrescriptionAnalysisResult {
  final String rawText;
  final List<ScanDraft> drafts;

  const PrescriptionAnalysisResult({required this.rawText, required this.drafts});
}

/// Scans a prescription entirely on the phone: ML Kit OCR, then the bundled Bangladesh
/// medicine list and dose rules. No server and no paid AI service.
class PrescriptionService {
  static const catalogAsset = 'assets/data/bd_medicines.tsv';
  final OcrService _ocr;

  PrescriptionService({OcrService? ocr}) : _ocr = ocr ?? OcrService();

  static Future<String>? _catalogText;

  Future<PrescriptionAnalysisResult> analyzePrescription(String imagePath) async {
    final text = await _ocr.extractTextFromImage(imagePath);
    final tsv = await (_catalogText ??= rootBundle.loadString(catalogAsset));
    final drafts = await compute(_parseInIsolate, (tsv, text, DateTime.now(), false));
    return PrescriptionAnalysisResult(rawText: text, drafts: drafts);
  }

  /// Finds the medicines on photos of medicine packets (strips, boxes, bottles).
  Future<PrescriptionAnalysisResult> analyzePackets(List<String> imagePaths) async {
    final texts = [for (final p in imagePaths) await _ocr.extractTextFromImage(p)];
    final tsv = await (_catalogText ??= rootBundle.loadString(catalogAsset));
    final drafts = <ScanDraft>[];
    final seen = <String>{};
    for (final text in texts) {
      // One photo at a time, so a strength on one packet is not given to another.
      for (final d in await compute(_parseInIsolate, (tsv, text, DateTime.now(), true))) {
        if (seen.add('${d.medicine.name}|${d.medicine.strength}')) drafts.add(d);
      }
    }
    return PrescriptionAnalysisResult(rawText: texts.join('\n\n---\n\n'), drafts: drafts);
  }

  /// The medicine list, for suggestions while typing a name.
  static Future<MedicineCatalog> loadCatalog() async =>
      compute(MedicineCatalog.parse, await (_catalogText ??= rootBundle.loadString(catalogAsset)));
}

final medicineCatalogProvider = FutureProvider<MedicineCatalog>((ref) => PrescriptionService.loadCatalog());

List<ScanDraft> _parseInIsolate((String, String, DateTime, bool) args) =>
    parsePrescription(args.$2, MedicineCatalog.parse(args.$1), now: args.$3, packets: args.$4);
