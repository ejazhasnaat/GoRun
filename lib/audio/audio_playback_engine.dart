import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/audio_settings_model.dart';

enum AudioCueType { warmup, run, walk, cooldown, halfway, complete }

class AudioPlaybackEngine {
  final FlutterTts _tts;
  AudioSettingsModel _settings;
  bool _isSpeaking = false;
  List<dynamic> _availableVoices = [];
  bool _speakCompletionSet = false;
  Completer<void>? _speechCompleter;

  // Cache for optimized voice selection
  Map<String, String>? _cachedVoice;
  String? _lastVoiceQuery;

  // Cache for TTS parameters to avoid redundant calls
  double? _cachedSpeechRate;
  double? _cachedPitch;
  double? _cachedVolume;

  // Pre-computed phrase mappings for better performance
  static const Map<AudioCueType, String> _phraseMappings = {
    AudioCueType.warmup: "Start your warm-up now",
    AudioCueType.run: "Start running",
    AudioCueType.walk: "Start walking",
    AudioCueType.cooldown: "Start your cooldown",
    AudioCueType.halfway: "You're halfway there. Keep going!",
    AudioCueType.complete: "Workout completed. Good job",
  };

  // Pre-computed locale mappings
  static const Map<String, String> _localeMappings = {
    'UK': 'en-GB',
    'IN': 'en-IN',
    'US': 'en-US',
  };

  // Constructor with optional FlutterTts injection for testing
  AudioPlaybackEngine(this._settings, {FlutterTts? tts})
    : _tts = tts ?? FlutterTts();

  Future<void> init() async {
    if (!_settings.enableTTS) return;

    try {
      if (_availableVoices.isEmpty) {
        _availableVoices = await _tts.getVoices;
      }

      await _updateTTSParameters();
      await _setLanguageForVoice();
      await _setVoiceForSelection();

      if (!_speakCompletionSet) {
        await _tts.awaitSpeakCompletion(true);
        _speakCompletionSet = true;
      }

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
          _speechCompleter!.complete();
        }
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
        if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
          _speechCompleter!.complete();
        }
      });

      _tts.setErrorHandler((message) {
        _isSpeaking = false;
        if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
          _speechCompleter!.complete();
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('TTS init error: $e');
    }
  }

  Future<void> _updateTTSParameters() async {
    final speechRate = _getSpeechRate();
    final pitch = _getPitch();
    final volume = _settings.cueVolume;

    if (_cachedSpeechRate != speechRate) {
      await _tts.setSpeechRate(speechRate);
      _cachedSpeechRate = speechRate;
    }
    if (_cachedPitch != pitch) {
      await _tts.setPitch(pitch);
      _cachedPitch = pitch;
    }
    if (_cachedVolume != volume) {
      await _tts.setVolume(volume);
      _cachedVolume = volume;
    }
  }

  Future<void> _setLanguageForVoice() async {
    String language = "en-US";
    for (final entry in _localeMappings.entries) {
      if (_settings.voice.contains(entry.key)) {
        language = entry.value;
        break;
      }
    }
    await _tts.setLanguage(language);
  }

  Future<void> _setVoiceForSelection() async {
    if (_availableVoices.isEmpty) return;

    final currentQuery = _settings.voice.toLowerCase();
    if (_lastVoiceQuery == currentQuery && _cachedVoice != null) return;

    final selectedVoice = _findMatchingVoice(currentQuery);

    if (selectedVoice != null) {
      try {
        await _tts.setVoice(selectedVoice);
        _cachedVoice = selectedVoice;
        _lastVoiceQuery = currentQuery;
      } catch (e) {
        _cachedVoice = null;
        _lastVoiceQuery = null;
      }
    }
  }

  Map<String, String>? _findMatchingVoice(String voiceLower) {
    final genderKeywords = _getGenderKeywords(voiceLower);
    final localeKeywords = _getLocaleKeywords();

    for (final voice in _availableVoices) {
      final name = voice['name']?.toString().toLowerCase() ?? '';
      final locale = voice['locale']?.toString().toLowerCase() ?? '';

      if (_matchesGender(name, genderKeywords) &&
          _matchesLocale(locale, localeKeywords)) {
        return Map<String, String>.from(voice as Map);
      }
    }

    for (final voice in _availableVoices) {
      final name = voice['name']?.toString().toLowerCase() ?? '';
      if (_matchesGender(name, genderKeywords)) {
        return Map<String, String>.from(voice as Map);
      }
    }

    return null;
  }

  List<String> _getGenderKeywords(String voiceLower) {
    if (voiceLower.contains('female')) return ['female', 'woman', 'girl'];
    if (voiceLower.contains('male')) return ['male', 'man', 'boy'];
    return [];
  }

  List<String> _getLocaleKeywords() {
    for (final entry in _localeMappings.entries) {
      if (_settings.voice.contains(entry.key)) {
        final locale = entry.value.toLowerCase();
        return [entry.key.toLowerCase(), locale, locale.replaceAll('-', '')];
      }
    }
    return [];
  }

  bool _matchesGender(String name, List<String> keywords) {
    return keywords.any(name.contains);
  }

  bool _matchesLocale(String locale, List<String> localeKeywords) {
    return localeKeywords.any(locale.contains);
  }

  double _getSpeechRate() {
    const rates = {'calm': 0.8, 'energetic': 1.0, 'neutral': 0.9};
    return rates[_settings.style.toLowerCase()] ?? 0.9;
  }

  double _getPitch() {
    const pitches = {'calm': 0.8, 'energetic': 1.2, 'neutral': 1.0};
    return pitches[_settings.style.toLowerCase()] ?? 1.0;
  }

  /// Speaks text and waits for completion via Completer.
  /// Returns a Future that completes when TTS finishes speaking,
  /// with a 10-second timeout safety net.
  Future<void> speakAndWait(String text) async {
    if (!_settings.enableTTS || text.trim().isEmpty) return;

    try {
      await _tts.stop();
      // Complete any pending completer
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }

      _speechCompleter = Completer<void>();
      await _updateTTSParameters();

      _isSpeaking = true;
      await _tts.speak(text);

      // Await the completer with a 10s timeout
      await _speechCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _isSpeaking = false;
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('TTS speakAndWait error: $e');
      _isSpeaking = false;
    }
  }

  Future<void> speak(String text) async {
    if (!_settings.enableTTS || text.trim().isEmpty) return;

    try {
      await _tts.stop();
      await _updateTTSParameters();

      _isSpeaking = true;
      await _tts.speak(text);
    } catch (e) {
      if (kDebugMode) debugPrint('TTS speak error: $e');
      _isSpeaking = false;
    }
  }

  Future<void> speakCue(AudioCueType type) async {
    if (!_settings.enableTTS || !_shouldSpeak(type)) return;

    try {
      await _tts.stop();
      final phrase = _phraseMappings[type] ?? "Unknown cue";
      await _updateTTSParameters();

      _isSpeaking = true;
      await _tts.speak(phrase);
    } catch (e) {
      if (kDebugMode) debugPrint('TTS cue error: $e');
      _isSpeaking = false;
    }
  }

  Future<void> speakCountdown(int seconds) async {
    const maxCountdown = 5;
    if (!_settings.enableCountdownCue || !_settings.enableTTS) return;
    if (_isSpeaking || seconds <= 0 || seconds > maxCountdown) return;

    try {
      await _updateTTSParameters();
      _isSpeaking = true;
      await _tts.speak(seconds.toString());
    } catch (e) {
      if (kDebugMode) debugPrint('TTS countdown error: $e');
      _isSpeaking = false;
    }
  }

  String formatDurationReadable(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final parts = <String>[];

    if (minutes > 0) parts.add("$minutes minute${minutes > 1 ? 's' : ''}");
    if (seconds > 0) parts.add("$seconds second${seconds > 1 ? 's' : ''}");

    return parts.join(' and ');
  }

  bool _shouldSpeak(AudioCueType type) {
    return type != AudioCueType.halfway || _settings.enableHalfwayCue;
  }

  Future<void> reloadSettings(AudioSettingsModel newSettings) async {
    final settingsChanged = _settings != newSettings;
    _settings = newSettings;

    if (settingsChanged) {
      _clearCaches();
      await stop();
      if (_settings.enableTTS) {
        await init();
      }
    }
  }

  Future<void> stop() async {
    try {
      _isSpeaking = false;
      // Complete any pending completer
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
      await _tts.stop();
    } catch (e) {
      if (kDebugMode) debugPrint('TTS stop error: $e');
    }
  }

  Future<void> dispose() async {
    await stop();
    _clearCaches();
  }

  void _clearCaches() {
    _cachedVoice = null;
    _lastVoiceQuery = null;
    _cachedSpeechRate = null;
    _cachedPitch = null;
    _cachedVolume = null;
  }

  bool get isSpeaking => _isSpeaking;
  List<dynamic> get availableVoices => _availableVoices;
  bool get hasVoiceCached => _cachedVoice != null && _lastVoiceQuery != null;
}
