import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'scan/ocr_layout.dart';

/// Reads the text on a photo with Google ML Kit, on the phone (free, works offline).
/// ML Kit reads Latin script only: Bangla words are skipped or misread.
class OcrService {
  Future<String> extractTextFromImage(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
      final lines = [
        for (final block in result.blocks)
          for (final line in block.lines)
            OcrLine(line.text, line.boundingBox.left, line.boundingBox.top,
                line.boundingBox.right, line.boundingBox.bottom),
      ];
      return rowsFromLines(lines);
    } finally {
      await recognizer.close();
    }
  }
}
