import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  Future<String> extractTextFromImage(String imagePath) async {
    final InputImage inputImage = InputImage.fromFilePath(imagePath);
    final TextRecognizer textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final String text = recognizedText.text;
      if (text.trim().isEmpty) {
        throw Exception('Extracted text is empty');
      }
      return text;
    } catch (e) {
      debugPrint('OCR Error: $e');
      rethrow;
    } finally {
      await textRecognizer.close();
    }
  }
}
