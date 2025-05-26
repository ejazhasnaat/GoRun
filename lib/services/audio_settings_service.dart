import 'package:flutter/foundation.dart'; // For ChangeNotifier
import '../models/audio_settings_model.dart';
import '../helpers/settings_helper.dart';

class AudioSettingsService extends ChangeNotifier {
  // Keys for persistent storage
  static const _keyEnableTTS = 'enableTTS';
  static const _keyVoice = 'voice';
  static const _keyStyle = 'style';
  static const _keyStartCue = 'startCue';
  static const _keyPauseCue = 'pauseCue';
  static const _keyResumeCue = 'resumeCue';
  static const _keyIntervalChangeCue = 'intervalChangeCue';
  static const _keyHalfwayCue = 'halfwayCue';
  static const _keyCountdownCue = 'countdownCue';
  static const _keyCueVolume = 'cueVolume';

  late AudioSettingsModel _settings;
  AudioSettingsModel get settings => _settings;

  /// Optional listener (e.g., for AudioPlaybackEngine) to react on changes
  void Function(AudioSettingsModel)? onSettingsChanged;

  AudioSettingsService() {
    // Initialize with default settings before loading persisted values
    _settings = const AudioSettingsModel();
  }

  /// Call after SettingsHelper.init() to load saved settings
  Future<void> init() async {
    await _loadSettings();
  }

  /// Reload settings from persistent storage
  Future<void> reload() async {
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    _settings = AudioSettingsModel(
      enableTTS: SettingsHelper.getBool(_keyEnableTTS, defaultValue: true),
      voice: SettingsHelper.getString(_keyVoice, defaultValue: 'US Female'),
      style: SettingsHelper.getString(_keyStyle, defaultValue: 'Energetic'),
      enableStartCue: SettingsHelper.getBool(_keyStartCue, defaultValue: true),
      enablePauseCue: SettingsHelper.getBool(_keyPauseCue, defaultValue: true),
      enableResumeCue: SettingsHelper.getBool(_keyResumeCue, defaultValue: true),
      enableIntervalChangeCue: SettingsHelper.getBool(_keyIntervalChangeCue, defaultValue: true),
      enableHalfwayCue: SettingsHelper.getBool(_keyHalfwayCue, defaultValue: true),
      enableCountdownCue: SettingsHelper.getBool(_keyCountdownCue, defaultValue: true),
      cueVolume: SettingsHelper.getDouble(_keyCueVolume, defaultValue: 1.0),
    );

    onSettingsChanged?.call(_settings);
    notifyListeners();
  }

  /// Update partial settings non-destructively and persist
  Future<void> update({
    bool? enableTTS,
    String? voice,
    String? style,
    bool? enableStartCue,
    bool? enablePauseCue,
    bool? enableResumeCue,
    bool? enableIntervalChangeCue,
    bool? enableHalfwayCue,
    bool? enableCountdownCue,
    double? cueVolume,
  }) async {
    _settings = _settings.copyWith(
      enableTTS: enableTTS,
      voice: voice,
      style: style,
      enableStartCue: enableStartCue,
      enablePauseCue: enablePauseCue,
      enableResumeCue: enableResumeCue,
      enableIntervalChangeCue: enableIntervalChangeCue,
      enableHalfwayCue: enableHalfwayCue,
      enableCountdownCue: enableCountdownCue,
      cueVolume: cueVolume,
    );

    try {
      // Persist each setting individually, only after updating the model
      await SettingsHelper.setBool(_keyEnableTTS, _settings.enableTTS);
      await SettingsHelper.setString(_keyVoice, _settings.voice);
      await SettingsHelper.setString(_keyStyle, _settings.style);
      await SettingsHelper.setBool(_keyStartCue, _settings.enableStartCue);
      await SettingsHelper.setBool(_keyPauseCue, _settings.enablePauseCue);
      await SettingsHelper.setBool(_keyResumeCue, _settings.enableResumeCue);
      await SettingsHelper.setBool(_keyIntervalChangeCue, _settings.enableIntervalChangeCue);
      await SettingsHelper.setBool(_keyHalfwayCue, _settings.enableHalfwayCue);
      await SettingsHelper.setBool(_keyCountdownCue, _settings.enableCountdownCue);
      await SettingsHelper.setDouble(_keyCueVolume, _settings.cueVolume);
    } catch (e) {
      // Optionally log errors here without crashing
      // debugPrint('Failed to persist audio settings: $e');
    }

    onSettingsChanged?.call(_settings);
    notifyListeners();
  }
}

