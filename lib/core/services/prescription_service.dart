import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:uuid/uuid.dart';
import '../models/mock_models.dart';

class PrescriptionAnalysisResult {
  final String? patientName;
  final String? doctorName;
  final String? date;
  final String rawText;
  final List<Medicine> medicines;

  PrescriptionAnalysisResult({
    this.patientName,
    this.doctorName,
    this.date,
    required this.rawText,
    required this.medicines,
  });
}

class PrescriptionService {
  /// Base URL of the backend prescription analysis server
  static String get baseUrl {
    const customUrl = String.fromEnvironment('BACKEND_BASE_URL');
    if (customUrl.isNotEmpty) {
      return customUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    try {
      if (Platform.isAndroid) {
        // Points to host localhost from Android emulator
        return 'http://10.0.2.2:3000';
      }
    } catch (_) {}
    return 'http://localhost:3000';
  }

  Future<PrescriptionAnalysisResult> analyzePrescription(File imageFile, String? idToken) async {
    // 1. Validate file exists
    if (!await imageFile.exists()) {
      throw const OSError('Prescription file not found on device.');
    }

    // 2. Validate file size (limit: 5MB)
    final int sizeInBytes = await imageFile.length();
    final double sizeInMb = sizeInBytes / (1024 * 1024);
    if (sizeInMb > 5.0) {
      throw const FormatException('Image file exceeds the 5MB size limit.');
    }

    // 3. Validate image type based on file extension
    final String extension = imageFile.path.split('.').last.toLowerCase();
    final allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'];
    if (!allowedExtensions.contains(extension)) {
      throw FormatException('Unsupported image type: .$extension. Only JPEG, PNG, WEBP, and HEIC are supported.');
    }

    // 4. Determine MIME type
    MediaType mediaType;
    if (extension == 'png') {
      mediaType = MediaType('image', 'png');
    } else if (extension == 'webp') {
      mediaType = MediaType('image', 'webp');
    } else if (extension == 'heic') {
      mediaType = MediaType('image', 'heic');
    } else if (extension == 'heif') {
      mediaType = MediaType('image', 'heif');
    } else {
      mediaType = MediaType('image', 'jpeg');
    }

    // 5. Send Multipart Request
    final uri = Uri.parse('$baseUrl/analyze-prescription');
    final request = http.MultipartRequest('POST', uri);
    if (idToken != null) {
      request.headers['Authorization'] = 'Bearer $idToken';
    }

    final multipartFile = await http.MultipartFile.fromPath(
      'image',
      imageFile.path,
      contentType: mediaType,
    );
    request.files.add(multipartFile);

    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Server returned error status code: ${response.statusCode}');
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      if (responseData['success'] != true) {
        throw Exception(responseData['error'] ?? 'Prescription analysis was unsuccessful.');
      }

      final prescriptionData = responseData['prescription'] as Map<String, dynamic>;
      
      final String? patientName = prescriptionData['patientName'];
      final String? doctorName = prescriptionData['doctorName'];
      final String? date = prescriptionData['date'];
      final String rawText = prescriptionData['rawText'] ?? '';
      
      final List<dynamic> medicinesJson = prescriptionData['medicines'] ?? [];
      final List<Medicine> medicinesList = [];
      final DateTime now = DateTime.now();

      for (final item in medicinesJson) {
        final Map<String, dynamic> medMap = item as Map<String, dynamic>;

        final String name = medMap['name'] ?? 'unclear';
        final String? genericName = medMap['genericName'];
        final String strength = medMap['strength'] ?? '';
        final String formStr = (medMap['form'] as String? ?? 'tablet').toLowerCase();
        final String dose = medMap['dose'] ?? '1 Tablet';
        final List<dynamic> timesList = medMap['times'] ?? ['08:00 AM'];
        final int? durationDays = medMap['durationDays'];
        final String mealRelation = medMap['mealRelation'] ?? 'None';
        final String? instructionText = medMap['instruction'];
        final double confidence = (medMap['confidence'] as num? ?? 0.5).toDouble();

        // Map form string to enum
        MedicineForm form = MedicineForm.tablet;
        if (formStr == 'capsule') {
          form = MedicineForm.capsule;
        } else if (formStr == 'syrup') {
          form = MedicineForm.syrup;
        } else if (formStr == 'injection') {
          form = MedicineForm.injection;
        }

        // Build composite instruction to preserve generic and low confidence indicators
        final List<String> instructionParts = [];
        if (genericName != null && genericName.isNotEmpty) {
          instructionParts.add('Generic: $genericName');
        }
        if (instructionText != null && instructionText.isNotEmpty) {
          instructionParts.add(instructionText);
        }
        if (confidence < 0.8) {
          instructionParts.add('[Low confidence extraction - please verify]');
        }
        
        final String finalInstruction = instructionParts.join('. ');

        // Add to result
        medicinesList.add(Medicine(
          id: const Uuid().v4(),
          name: name,
          strength: strength,
          form: form,
          dose: dose,
          times: List<String>.from(timesList),
          mealRelation: mealRelation,
          instruction: finalInstruction,
          startDate: now,
          endDate: now.add(Duration(days: durationDays ?? 7)),
          status: 'active',
          createdAt: now,
        ));
      }

      return PrescriptionAnalysisResult(
        patientName: patientName,
        doctorName: doctorName,
        date: date,
        rawText: rawText,
        medicines: medicinesList,
      );

    } on SocketException {
      throw const SocketException('Cannot connect to prescription service. Check server connection.');
    } catch (e) {
      debugPrint('PrescriptionService Error: $e');
      rethrow;
    }
  }
}
