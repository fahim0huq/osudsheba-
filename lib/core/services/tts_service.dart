import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_tts/flutter_tts.dart';
import '../models/mock_models.dart';
import 'medication_voice_service.dart';

enum TtsState { playing, stopped, paused }

class TtsService {
  static final TtsService instance = TtsService._();
  TtsService._();

  FlutterTts? _flutterTts;
  FlutterTts get _tts => _flutterTts ??= FlutterTts();

  bool _isInitialized = false;
  TtsState _ttsState = TtsState.stopped;

  final StreamController<TtsState> _stateController = StreamController<TtsState>.broadcast();
  Stream<TtsState> get stateStream => _stateController.stream;
  TtsState get currentState => _ttsState;
  bool get isPlaying => _ttsState == TtsState.playing;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _tts.setStartHandler(() {
        _ttsState = TtsState.playing;
        _stateController.add(TtsState.playing);
      });

      _tts.setCompletionHandler(() {
        _ttsState = TtsState.stopped;
        _stateController.add(TtsState.stopped);
      });

      _tts.setCancelHandler(() {
        _ttsState = TtsState.stopped;
        _stateController.add(TtsState.stopped);
      });

      _tts.setErrorHandler((msg) {
        dev.log('TtsService Error: $msg');
        _ttsState = TtsState.stopped;
        _stateController.add(TtsState.stopped);
      });

      // Default voice settings
      await _tts.setSpeechRate(0.46);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _isInitialized = true;
      dev.log('TtsService: Initialized successfully');
    } catch (e) {
      dev.log('TtsService: Init error: $e');
    }
  }

  /// Stop any currently ongoing speech immediately
  Future<void> stop() async {
    try {
      if (_flutterTts != null) {
        await _tts.stop();
      }
    } catch (e) {
      dev.log('TtsService: Error stopping speech: $e');
    } finally {
      _ttsState = TtsState.stopped;
      _stateController.add(TtsState.stopped);
    }
  }

  /// Checks whether a Bangla TTS voice is available on this Android device.
  Future<bool> isBanglaAvailable() async {
    try {
      await init();
      final isBd = await _tts.isLanguageAvailable("bn-BD");
      if (isBd == true || isBd == 1) return true;

      final isBnIn = await _tts.isLanguageAvailable("bn-IN");
      if (isBnIn == true || isBnIn == 1) return true;

      final isBn = await _tts.isLanguageAvailable("bn");
      if (isBn == true || isBn == 1) return true;

      final languages = await _tts.getLanguages;
      if (languages is List) {
        for (final l in languages) {
          if (l != null && l.toString().toLowerCase().startsWith('bn')) {
            return true;
          }
        }
      }
    } catch (e) {
      dev.log('TtsService: Error detecting Bangla availability: $e');
    }
    return false;
  }

  /// Configures the best available Bangla locale ('bn-BD' -> 'bn-IN' -> 'bn')
  /// Returns false if no Bangla voice is supported. Never silently falls back to English.
  Future<bool> _configureBanglaLanguage() async {
    try {
      // 1. Try Bangladesh Bangla
      final isBd = await _tts.isLanguageAvailable("bn-BD");
      if (isBd == true || isBd == 1) {
        await _tts.setLanguage("bn-BD");
        dev.log('TtsService: Selected voice locale bn-BD');
        return true;
      }

      // 2. Try India Bangla
      final isBnIn = await _tts.isLanguageAvailable("bn-IN");
      if (isBnIn == true || isBnIn == 1) {
        await _tts.setLanguage("bn-IN");
        dev.log('TtsService: Selected voice locale bn-IN');
        return true;
      }

      // 3. Try generic Bangla
      final isBn = await _tts.isLanguageAvailable("bn");
      if (isBn == true || isBn == 1) {
        await _tts.setLanguage("bn");
        dev.log('TtsService: Selected voice locale bn');
        return true;
      }

      // 4. Check installed language list
      final languages = await _tts.getLanguages;
      if (languages is List) {
        for (final l in languages) {
          final langStr = l?.toString().toLowerCase() ?? '';
          if (langStr.startsWith('bn')) {
            await _tts.setLanguage(l.toString());
            dev.log('TtsService: Selected voice locale from list: $l');
            return true;
          }
        }
      }

      // Attempt direct setLanguage("bn-BD") in case query is restricted
      final result = await _tts.setLanguage("bn-BD");
      if (result == 1 || result == true) {
        return true;
      }
    } catch (e) {
      dev.log('TtsService: Error during Bangla locale configuration: $e');
    }

    dev.log('TtsService Warning: No Bangla TTS voice installed. Will NOT fallback to English.');
    return false;
  }

  /// Speak arbitrary text with language configuration and overlap protection.
  /// If [lang] is 'bn', it guarantees it will NOT fall back to English if Bangla is missing.
  Future<bool> speakText(String text, {String lang = 'bn'}) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return false;

    await init();
    // Stop any ongoing speech to prevent overlapping voices
    await stop();

    if (lang == 'bn') {
      final hasBangla = await _configureBanglaLanguage();
      if (!hasBangla) {
        dev.log('TtsService: Skipping speech because Bangla voice is unavailable on device.');
        return false;
      }
    } else {
      try {
        await _tts.setLanguage('en-US');
      } catch (_) {}
    }

    try {
      _ttsState = TtsState.playing;
      _stateController.add(TtsState.playing);
      await _tts.speak(cleanText);
      return true;
    } catch (e) {
      dev.log('TtsService: Error speaking text: $e');
      _ttsState = TtsState.stopped;
      _stateController.add(TtsState.stopped);
      return false;
    }
  }

  /// Speaks the automatic overview announcement when medication alert triggers
  Future<bool> speakOverview(List<Medicine> medicines, {String lang = 'bn'}) async {
    if (medicines.isEmpty) return false;
    final text = MedicationVoiceService.buildOverviewAnnouncement(medicines, lang: lang);
    return await speakText(text, lang: lang);
  }

  /// Speaks detailed instructions when user taps [ 🔊 শুনুন ]
  Future<bool> speakDetailedInstructions(List<Medicine> medicines, {String lang = 'bn'}) async {
    if (medicines.isEmpty) return false;
    final text = MedicationVoiceService.buildDetailedInstructions(medicines, lang: lang);
    return await speakText(text, lang: lang);
  }

  /// Speaks Home screen schedule announcement when user taps audio button
  Future<bool> speakHomeSchedule({
    required List<Medicine> medicines,
    required String? scheduledTime,
    bool isCurrentlyDue = false,
    String lang = 'bn',
  }) async {
    final text = MedicationVoiceService.buildHomeScheduleAnnouncement(
      medicines: medicines,
      scheduledTime: scheduledTime,
      isCurrentlyDue: isCurrentlyDue,
      lang: lang,
    );
    return await speakText(text, lang: lang);
  }

  /// Backward-compatible wrapper delegating to detailed instructions
  Future<bool> speakMedications(List<Medicine> medicines, {String lang = 'bn'}) async {
    return await speakDetailedInstructions(medicines, lang: lang);
  }

  /// Helper forwarding to MedicationVoiceService for text generation
  String buildMedicationSpeechText(List<Medicine> medicines, {String lang = 'bn'}) {
    return MedicationVoiceService.buildDetailedInstructions(medicines, lang: lang);
  }

  void dispose() {
    _stateController.close();
  }
}
