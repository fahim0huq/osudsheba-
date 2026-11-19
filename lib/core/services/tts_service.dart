import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
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

  static bool _ok(dynamic result) => result == 1 || result == true;

  /// Tries Bangla locales on the current speech engine: 'bn-BD' -> 'bn-IN' -> 'bn' -> any 'bn*'.
  Future<bool> _setBanglaOnCurrentEngine() async {
    for (final locale in const ['bn-BD', 'bn-IN', 'bn']) {
      if (_ok(await _tts.isLanguageAvailable(locale)) && _ok(await _tts.setLanguage(locale))) {
        dev.log('TtsService: Selected voice locale $locale');
        return true;
      }
    }
    final languages = await _tts.getLanguages;
    if (languages is List) {
      for (final l in languages) {
        final code = l?.toString() ?? '';
        if (code.toLowerCase().startsWith('bn') && _ok(await _tts.setLanguage(code))) {
          dev.log('TtsService: Selected voice locale from list: $code');
          return true;
        }
      }
    }
    return false;
  }

  /// Configures a Bangla voice. Returns false if none is installed (never falls back to English).
  ///
  /// The phone's default speech engine often has no Bangla (Samsung phones default to
  /// Samsung TTS), while Google's engine on the same phone does. So when the current engine
  /// has no Bangla, the other installed engines are tried, Google's first.
  Future<bool> _configureBanglaLanguage() async {
    try {
      if (await _setBanglaOnCurrentEngine()) return true;
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;

      final engines = ((await _tts.getEngines) as List?)?.map((e) => e.toString()).toList() ?? const [];
      final current = _engine ?? (await _tts.getDefaultEngine)?.toString();
      final others = engines.where((e) => e != current).toList()
        ..sort((a, b) => (b == _googleEngine ? 1 : 0) - (a == _googleEngine ? 1 : 0));
      for (final engine in others) {
        await _tts.setEngine(engine);
        _engine = engine;
        if (await _setBanglaOnCurrentEngine()) {
          dev.log('TtsService: Using engine $engine for Bangla');
          return true;
        }
      }
      if (current != null && _engine != current) {
        await _tts.setEngine(current);
        _engine = current;
      }
    } catch (e) {
      dev.log('TtsService: Error during Bangla locale configuration: $e');
    }

    dev.log('TtsService Warning: No Bangla TTS voice installed. Will NOT fallback to English.');
    return false;
  }

  static const _googleEngine = 'com.google.android.tts';
  String? _engine;

  Future<bool> _configureEnglishLanguage() async {
    try {
      for (final locale in const ['en-US', 'en-GB', 'en-IN', 'en']) {
        if (_ok(await _tts.setLanguage(locale))) return true;
      }
    } catch (e) {
      dev.log('TtsService: Error setting English voice: $e');
    }
    return false;
  }

  /// Speak arbitrary text with language configuration and overlap protection.
  /// If [lang] is 'bn', it guarantees it will NOT fall back to English if Bangla is missing.
  /// Returns false when nothing will be heard (no voice, or the engine refused the text),
  /// so the caller can tell the user instead of showing a "Stop" button for silence.
  Future<bool> speakText(String text, {String lang = 'bn'}) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return false;

    await init();
    // Stop any ongoing speech to prevent overlapping voices
    await stop();

    final hasVoice = lang == 'bn' ? await _configureBanglaLanguage() : await _configureEnglishLanguage();
    if (!hasVoice) {
      dev.log('TtsService: Skipping speech because no $lang voice is available on device.');
      return false;
    }

    try {
      _ttsState = TtsState.playing;
      _stateController.add(TtsState.playing);
      final result = await _tts.speak(cleanText);
      if (_ok(result)) return true;
      dev.log('TtsService: Engine refused to speak (result $result)');
    } catch (e) {
      dev.log('TtsService: Error speaking text: $e');
    }
    _ttsState = TtsState.stopped;
    _stateController.add(TtsState.stopped);
    return false;
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
    bool isTomorrow = false,
    String lang = 'bn',
  }) async {
    final text = MedicationVoiceService.buildHomeScheduleAnnouncement(
      medicines: medicines,
      scheduledTime: scheduledTime,
      isCurrentlyDue: isCurrentlyDue,
      isTomorrow: isTomorrow,
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
