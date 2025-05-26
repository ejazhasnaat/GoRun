import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/audio_settings_model.dart';

enum AudioCueType {
  warmup,
  run,
  walk,
  cooldown,
  halfway,
  complete,
  start,
  pause,
  resume,
  intervalChange,
}

class AudioPlaybackEngine {
  final FlutterTts _tts = FlutterTts();
  AudioSettingsModel _settings;
  bool _isSpeaking = false;
  List<dynamic> _availableVoices = [];

  AudioPlaybackEngine(this._settings) {
    _initializeTTS();
  }

  Future<void> _initializeTTS() async {
    if (!_settings.enableTTS) return;

    try {
      _availableVoices = await _tts.getVoices;

      // Configure TTS parameters
      await _tts.setSpeechRate(_getSpeechRate());
      await _tts.setPitch(_getPitch());
      await _tts.setVolume(_settings.cueVolume);

      await _setLanguageForVoice();
      await _setVoiceForSelection();

      // Wait for speaking completion before continuing
      await _tts.awaitSpeakCompletion(true);

      // Set handlers for completion and error
      _tts.setCompletionHandler(() => _isSpeaking = false);

      _tts.setErrorHandler((message) {
        _isSpeaking = false;
        debugPrint("TTS Error: $message");
      });
    } catch (e) {
      debugPrint("TTS initialization error: $e");
    }
  }

  Future<void> _setLanguageForVoice() async {
    String language = "en-US"; // Default

    if (_settings.voice.contains('UK')) {
      language = "en-GB";
    } else if (_settings.voice.contains('IN')) {
      language = "en-IN";
    } else if (_settings.voice.contains('US')) {
      language = "en-US";
    }

    await _tts.setLanguage(language);
  }

  Future<void> _setVoiceForSelection() async {
    if (_availableVoices.isEmpty) return;

    Map<String, String>? selectedVoice;

    final voiceLower = _settings.voice.toLowerCase();

    // First pass: exact match by gender and locale
    for (var voice in _availableVoices) {
      final name = voice['name'].toString().toLowerCase();
      final locale = voice['locale'].toString().toLowerCase();

      final isGenderMatch =
          (voiceLower.contains('female') &&
              (name.contains('female') ||
                  name.contains('woman') ||
                  name.contains('girl'))) ||
          (voiceLower.contains('male') &&
              (name.contains('male') ||
                  name.contains('man') ||
                  name.contains('boy')));

      final isLocaleMatch =
          (_settings.voice.contains('US') &&
              (locale.contains('us') || locale.contains('en-us'))) ||
          (_settings.voice.contains('UK') &&
              (locale.contains('gb') || locale.contains('en-gb'))) ||
          (_settings.voice.contains('IN') &&
              (locale.contains('in') || locale.contains('en-in')));

      if (isGenderMatch && isLocaleMatch) {
        selectedVoice = voice;
        break;
      }
    }

    // Second pass: broader gender-only match if no exact found
    if (selectedVoice == null) {
      for (var voice in _availableVoices) {
        final name = voice['name'].toString().toLowerCase();

        if (voiceLower.contains('female') &&
            (name.contains('female') || name.contains('woman'))) {
          selectedVoice = voice;
          break;
        } else if (voiceLower.contains('male') &&
            (name.contains('male') || name.contains('man'))) {
          selectedVoice = voice;
          break;
        }
      }
    }

    // Set the voice if found
    if (selectedVoice != null) {
      try {
        await _tts.setVoice(selectedVoice);
        debugPrint(
          "Selected voice: ${selectedVoice['name']} (${selectedVoice['locale']})",
        );
      } catch (e) {
        debugPrint("Failed to set voice: $e");
      }
    } else {
      debugPrint("No matching voice found for: ${_settings.voice}");
      debugPrint(
        "Available voices: ${_availableVoices.map((v) => "${v['name']} (${v['locale']})").join(', ')}",
      );
    }
  }

  double _getSpeechRate() {
    switch (_settings.style.toLowerCase()) {
      case 'calm':
        return 0.8;
      case 'energetic':
        return 1.0;
      case 'neutral':
      default:
        return 0.9;
    }
  }

  double _getPitch() {
    switch (_settings.style.toLowerCase()) {
      case 'calm':
        return 0.8;
      case 'energetic':
        return 1.2;
      case 'neutral':
      default:
        return 1.0;
    }
  }

  String _applyStyleToText(String text) {
    switch (_settings.style.toLowerCase()) {
      case 'calm':
        return text.replaceAll('!', '.').replaceAll('.', '... ');
      case 'energetic':
        return text.endsWith('!') ? text : text.replaceAll('.', '!');
      case 'neutral':
      default:
        return text;
    }
  }

  Future<void> reloadSettings(AudioSettingsModel newSettings) async {
    _settings = newSettings;
    await stop();
    if (_settings.enableTTS) {
      await _initializeTTS();
    }
  }

  Future<void> speak(String text) async {
    if (!_settings.enableTTS || text.trim().isEmpty) return;

    try {
      if (_isSpeaking) {
        await _tts.stop();
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final styledText = _applyStyleToText(text);

      await _tts.setVolume(_settings.cueVolume);
      await _tts.setSpeechRate(_getSpeechRate());
      await _tts.setPitch(_getPitch());

      _isSpeaking = true;
      await _tts.speak(styledText);
    } catch (e) {
      _isSpeaking = false;
      debugPrint('TTS Speak Error: $e');
    }
  }

  Future<void> speakCue(AudioCueType type) async {
    if (!_settings.enableTTS || !_shouldSpeak(type)) return;

    await _tts.stop();

    final phrase = _getCuePhrase(type);
    final styledPhrase = _applyStyleToText(phrase);

    try {
      await _tts.setVolume(_settings.cueVolume);
      await _tts.setSpeechRate(_getSpeechRate());
      await _tts.setPitch(_getPitch());

      _isSpeaking = true;
      await _tts.speak(styledPhrase);
    } catch (e) {
      _isSpeaking = false;
      debugPrint("TTS speakCue error: $e");
    }
  }

  String _getCuePhrase(AudioCueType type) {
    final Map<String, List<String>> stylePhrases = {
      'calm': _getCalmPhrases(),
      'energetic': _getEnergeticPhrases(),
      'neutral': _getNeutralPhrases(),
    };

    final phrases =
        stylePhrases[_settings.style.toLowerCase()] ?? stylePhrases['neutral']!;

    switch (type) {
      case AudioCueType.warmup:
        return phrases[0];
      case AudioCueType.run:
        return phrases[1];
      case AudioCueType.walk:
        return phrases[2];
      case AudioCueType.cooldown:
        return phrases[3];
      case AudioCueType.halfway:
        return phrases[4];
      case AudioCueType.complete:
        return phrases[5];
      case AudioCueType.start:
        return phrases[6];
      case AudioCueType.pause:
        return phrases[7];
      case AudioCueType.resume:
        return phrases[8];
      case AudioCueType.intervalChange:
        return phrases[9];
    }
  }

  List<String> _getCalmPhrases() => [
    "Time to begin your gentle warm-up",
    "Let's start running at your own pace",
    "Time for a relaxing walk",
    "Begin your cool-down routine",
    "You're halfway through, keep going",
    "Workout complete. Well done",
    "Let's begin this journey together",
    "Take a moment to pause",
    "Ready to continue when you are",
    "Moving to the next phase",
  ];

  List<String> _getEnergeticPhrases() => [
    "Let's fire up that warm-up!",
    "Time to run! Give it everything you've got!",
    "Power walk time! Keep that energy high!",
    "Cool down time! You crushed it!",
    "Halfway there! You're absolutely crushing this!",
    "Workout completed! You're a superstar!",
    "Let's go! Time to dominate this workout!",
    "Workout paused! Catch your breath, champion!",
    "Back in action! Let's finish strong!",
    "Next interval! Keep that fire burning!",
  ];

  List<String> _getNeutralPhrases() => [
    "Start your warm-up now",
    "Start running",
    "Start walking",
    "Start your cooldown",
    "Halfway there",
    "Workout completed. Good job",
    "Let's get started",
    "Workout paused",
    "Resuming workout",
    "Interval change",
  ];

  Future<void> speakCountdown(int seconds) async {
    if (!_settings.enableCountdownCue || !_settings.enableTTS) return;

    if (seconds > 0 && seconds <= 5) {
      try {
        await _tts.setVolume(_settings.cueVolume);
        await _tts.setSpeechRate(_getSpeechRate());
        await _tts.setPitch(_getPitch());

        _isSpeaking = true;
        await _tts.speak(seconds.toString());
      } catch (e) {
        _isSpeaking = false;
        debugPrint("TTS countdown error: $e");
      }
    }
  }

  String formatDurationReadable(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    if (minutes > 0 && seconds > 0) {
      return "$minutes minute${minutes > 1 ? 's' : ''} and $seconds second${seconds > 1 ? 's' : ''}";
    } else if (minutes > 0) {
      return "$minutes minute${minutes > 1 ? 's' : ''}";
    } else {
      return "$seconds second${seconds > 1 ? 's' : ''}";
    }
  }

  bool _shouldSpeak(AudioCueType type) {
    switch (type) {
      case AudioCueType.halfway:
        return _settings.enableHalfwayCue;
      case AudioCueType.start:
        return _settings.enableStartCue;
      case AudioCueType.pause:
        return _settings.enablePauseCue;
      case AudioCueType.resume:
        return _settings.enableResumeCue;
      case AudioCueType.intervalChange:
        return _settings.enableIntervalChangeCue;
      default:
        return true;
    }
  }

  Future<void> stop() async {
    try {
      _isSpeaking = false;
      await _tts.stop();
    } catch (e) {
      debugPrint("TTS stop error: $e");
    }
  }

  Future<void> dispose() async {
    await stop();
  }

  bool get isSpeaking => _isSpeaking;
  List<dynamic> get availableVoices => _availableVoices;

  Future<void> debugPrintAvailableVoices() async {
    try {
      final voices = await _tts.getVoices;
      debugPrint("==== Available TTS Voices ====");
      for (var voice in voices) {
        debugPrint("Voice: ${voice.toString()}");
      }
      debugPrint("=============================");
    } catch (e) {
      debugPrint("Error fetching voices: $e");
    }
  }
}
