class OcrService {
  Future<String> extractTextFromImage(String imagePath) async {
    throw Exception('Direct client-side Gemini calls are disabled. Web OCR must be routed through the backend.');
  }
}
