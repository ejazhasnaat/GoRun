import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:vibration/vibration.dart';

import '../audio/audio_playback_engine.dart';
import '../data/z25k_data.dart';
import '../models/audio_settings_model.dart';
import '../models/run_data.dart';
import '../features/tracking/tracking_service.dart';

/// Centralized cue management system
class CueManager {
  final AudioPlaybackEngine audioEngine;

  // State tracking
  String? _lastAnnouncedSegmentKey;
  int _lastCountdownSecond = -1;
  bool _halfwayAnnouncementMade = false;
  bool _isPlayingAudio = false;

  // Timers
  Timer? _audioSequenceTimer;

  CueManager(this.audioEngine);

  /// Generate unique key for segment to prevent duplicate announcements
  String _generateSegmentKey(int index, WorkoutInterval segment) {
    return "${index}_${segment.type.name}_${segment.duration}";
  }

  /// Check if segment announcement is needed
  bool shouldAnnounceSegment(int currentIndex, WorkoutInterval segment) {
    final segmentKey = _generateSegmentKey(currentIndex, segment);
    return _lastAnnouncedSegmentKey != segmentKey && !_isPlayingAudio;
  }

  /// Announce segment change with proper sequencing
  Future<void> announceSegment(
    int currentIndex,
    WorkoutInterval segment,
    bool enableTTS,
  ) async {
    if (!enableTTS || _isPlayingAudio) return;

    final segmentKey = _generateSegmentKey(currentIndex, segment);
    _lastAnnouncedSegmentKey = segmentKey;
    _isPlayingAudio = true;

    try {
      // Step 1: Play cue
      final cueType = _mapIntervalToCue(segment.type);
      await audioEngine.speakCue(cueType);

      // Step 2: Wait for cue completion with timeout
      await _waitForSpeechCompletionWithTimeout(3000); // 3 second timeout

      // Step 3: Small buffer before duration announcement
      await Future.delayed(const Duration(milliseconds: 200));

      // Step 4: Announce duration
      final durationText = _formatDurationForSpeech(segment.duration);
      final announcement =
          "${segment.type.name.toLowerCase()} for $durationText";

      await audioEngine.speak(announcement);

      // Step 5: Wait for duration announcement completion
      await _waitForSpeechCompletionWithTimeout(5000); // 5 second timeout
    } catch (e) {
      // Force stop any ongoing speech
      await audioEngine.stop();
    } finally {
      _isPlayingAudio = false;
    }
  }

  /// Handle countdown cues (last 5 seconds)
  void handleCountdownCues(
    int remaining,
    bool enableCountdown,
    bool enableTTS,
  ) {
    if (!enableCountdown || !enableTTS) return;

    if (remaining <= 5 && remaining > 0 && remaining != _lastCountdownSecond) {
      _lastCountdownSecond = remaining;

      // Stop any ongoing speech to prioritize countdown
      if (_isPlayingAudio) {
        audioEngine.stop();
        _isPlayingAudio = false;
      }

      // Speak countdown immediately
      audioEngine.speakCountdown(remaining);
    }

    if (remaining > 5) {
      _lastCountdownSecond = -1;
    }
  }

  /// Handle halfway workout announcement
  void handleHalfwayCue(
    int elapsedSeconds,
    int totalDuration,
    bool enableHalfway,
    bool enableTTS,
  ) {
    if (!enableHalfway || !enableTTS) return;

    final halfwayPoint = totalDuration ~/ 2;
    if (elapsedSeconds >= halfwayPoint &&
        elapsedSeconds <= halfwayPoint + 1 &&
        !_halfwayAnnouncementMade) {
      _halfwayAnnouncementMade = true;

      // Stop any ongoing speech to prioritize halfway announcement
      if (_isPlayingAudio) {
        audioEngine.stop();
        _isPlayingAudio = false;
      }

      audioEngine.speakCue(AudioCueType.halfway);
    }
  }

  /// Map interval type to audio cue
  AudioCueType _mapIntervalToCue(IntervalType type) {
    switch (type) {
      case IntervalType.warmup:
        return AudioCueType.warmup;
      case IntervalType.run:
        return AudioCueType.run;
      case IntervalType.walk:
        return AudioCueType.walk;
      case IntervalType.cooldown:
        return AudioCueType.cooldown;
    }
  }

  /// Format duration for speech
  String _formatDurationForSpeech(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    if (minutes == 0) {
      return remainingSeconds == 1 ? "1 second" : "$remainingSeconds seconds";
    } else if (remainingSeconds == 0) {
      return minutes == 1 ? "1 minute" : "$minutes minutes";
    } else {
      final minuteText = minutes == 1 ? "1 minute" : "$minutes minutes";
      final secondText =
          remainingSeconds == 1 ? "1 second" : "$remainingSeconds seconds";
      return "$minuteText and $secondText";
    }
  }

  /// Wait for speech completion with timeout
  Future<void> _waitForSpeechCompletionWithTimeout(int timeoutMs) async {
    final completer = Completer<void>();
    final timeout = Timer(Duration(milliseconds: timeoutMs), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    // Poll for speech completion
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!audioEngine.isSpeaking || completer.isCompleted) {
        timer.cancel();
        timeout.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    await completer.future;
  }

  /// Wait for speech completion (legacy method for backward compatibility)
  Future<void> _waitForSpeechCompletion() async {
    await _waitForSpeechCompletionWithTimeout(5000);
  }

  /// Reset state for new workout or segment jumps
  void reset() {
    _lastAnnouncedSegmentKey = null;
    _lastCountdownSecond = -1;
    _halfwayAnnouncementMade = false;
    _isPlayingAudio = false;
  }

  /// Stop all audio and reset
  Future<void> stop() async {
    _audioSequenceTimer?.cancel();
    await audioEngine.stop();
    _isPlayingAudio = false;
  }

  void dispose() {
    _audioSequenceTimer?.cancel();
  }
}

/// Enhanced TimerController with centralized cue management
class TimerController extends ChangeNotifier {
  final Workout workout;
  final AudioPlaybackEngine audioEngine;
  late final CueManager _cueManager;

  // Workout state
  late final List<WorkoutInterval> intervals;
  Timer? _timer;

  int currentIndex = 0;
  int currentSegmentRemaining = 0;
  int totalElapsedSeconds = 0;

  bool isRunning = false;
  bool isPaused = false;
  bool _isCompleted = false;
  bool _isDisposed = false;

  DateTime? _startTime;
  int _lastSegmentIndex = -1;

  // Audio settings - will be injected from UI
  bool _enableTTS = true;
  bool _enableCountdownCue = true;
  bool _enableHalfwayCue = true;

  TimerController({required this.workout, required this.audioEngine}) {
    _cueManager = CueManager(audioEngine);
    _initializeWorkout();
  }

  // Getters
  WorkoutInterval get currentSegment => intervals[currentIndex];
  int get totalDuration => intervals.fold(0, (sum, i) => sum + i.duration);
  int get elapsedSeconds => totalElapsedSeconds;
  int get remainingSeconds => totalDuration - totalElapsedSeconds;
  int get currentSegmentIndex => currentIndex;
  double get progress => (totalElapsedSeconds / totalDuration).clamp(0.0, 1.0);
  bool get isCompleted => _isCompleted;
  List<WorkoutInterval> get segments => intervals;

  double get currentSegmentProgress {
    final total = currentSegment.duration;
    if (total == 0) return 0.0;
    final elapsed = total - currentSegmentRemaining;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// Update audio settings from UI
  void updateAudioSettings({
    required bool enableTTS,
    required bool enableCountdownCue,
    required bool enableHalfwayCue,
  }) {
    _enableTTS = enableTTS;
    _enableCountdownCue = enableCountdownCue;
    _enableHalfwayCue = enableHalfwayCue;
  }

  void _initializeWorkout() {
    intervals = workout.getIntervals();
    currentIndex = 0;
    currentSegmentRemaining = intervals.first.duration;
    totalElapsedSeconds = 0;
    _isCompleted = false;
    _lastSegmentIndex = -1;
    _cueManager.reset();
  }

  void start() {
    if (isRunning && !isPaused) return;

    isRunning = true;
    isPaused = false;
    _startTime ??= DateTime.now();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    // Announce initial segment after a short delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (_cueManager.shouldAnnounceSegment(currentIndex, currentSegment)) {
        _cueManager.announceSegment(currentIndex, currentSegment, _enableTTS);
        _lastSegmentIndex = currentIndex;
      }
    });

    _safeNotify();
  }

  void pause() {
    if (!isRunning || isPaused) return;
    _timer?.cancel();
    isPaused = true;
    _safeNotify();
  }

  void resume() {
    if (isRunning && isPaused) {
      isPaused = false;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      _safeNotify();
    }
  }

  Future<void> stop({bool completed = false}) async {
    _timer?.cancel();
    _timer = null;
    isRunning = false;
    isPaused = false;

    if (completed) {
      _isCompleted = true;
      await _cueManager.audioEngine.speakCue(AudioCueType.complete);
    }

    await _cueManager.stop();
    _safeNotify();
  }

  Future<void> _tick() async {
    if (!isRunning || isPaused || _isDisposed) return;

    // Handle countdown cues first (highest priority)
    _cueManager.handleCountdownCues(
      currentSegmentRemaining,
      _enableCountdownCue,
      _enableTTS,
    );

    // Handle halfway cue
    _cueManager.handleHalfwayCue(
      totalElapsedSeconds,
      totalDuration,
      _enableHalfwayCue,
      _enableTTS,
    );

    // Handle segment change
    if (currentIndex != _lastSegmentIndex) {
      _handleSegmentChange();
      _lastSegmentIndex = currentIndex;
    }

    // Advance timer
    if (currentSegmentRemaining > 0) {
      currentSegmentRemaining--;
      totalElapsedSeconds++;
    } else {
      // Move to next segment or complete
      if (currentIndex < intervals.length - 1) {
        currentIndex++;
        currentSegmentRemaining = intervals[currentIndex].duration;
        // Segment change will be handled in next tick
      } else {
        await stop(completed: true);
        return;
      }
    }

    _safeNotify();
  }

  void _handleSegmentChange() {
    if (_cueManager.shouldAnnounceSegment(currentIndex, currentSegment)) {
      // Use Future.microtask to avoid blocking the timer tick
      Future.microtask(() {
        _cueManager.announceSegment(currentIndex, currentSegment, _enableTTS);
      });

      // Trigger haptic feedback
      _triggerHapticFeedback();
    }
  }

  void _triggerHapticFeedback() {
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 100);
      }
    });
  }

  void previousSegment() {
    if (currentIndex > 0) {
      currentIndex--;
      currentSegmentRemaining = intervals[currentIndex].duration;
      totalElapsedSeconds = intervals
          .sublist(0, currentIndex)
          .fold(0, (sum, i) => sum + i.duration);

      _cueManager.reset(); // Reset to allow re-announcement
      _handleSegmentChange();
      _safeNotify();
    }
  }

  void nextSegment() {
    if (currentIndex < intervals.length - 1) {
      totalElapsedSeconds += currentSegmentRemaining;
      currentIndex++;
      currentSegmentRemaining = intervals[currentIndex].duration;

      _cueManager.reset(); // Reset to allow re-announcement
      _handleSegmentChange();
      _safeNotify();
    }
  }

  Future<void> jumpToSegment(int index) async {
    if (index < 0 || index >= intervals.length) return;

    final wasRunning = isRunning && !isPaused;
    if (wasRunning) pause();

    currentIndex = index;
    currentSegmentRemaining = intervals[index].duration;
    totalElapsedSeconds = intervals
        .sublist(0, index)
        .fold(0, (sum, i) => sum + i.duration);

    _cueManager.reset(); // Reset to allow re-announcement
    _handleSegmentChange();

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 150);
    }

    _safeNotify();
    if (wasRunning) resume();
  }

  Future<RunData> generateRunData() async {
    final endTime = DateTime.now();
    final durationSeconds = totalElapsedSeconds;

    final routePoints = await TrackingService.instance.getRoute() ?? [];
    final distanceMeters = TrackingService.instance.calculateDistance(
      routePoints,
    );
    final pace =
        distanceMeters > 0 ? durationSeconds / (distanceMeters / 1000) : 0;
    final calories = 65.0 * (durationSeconds / 60.0) * 0.1;
    final speeds = TrackingService.instance.estimateSpeeds(
      routePoints,
      durationSeconds,
    );
    final elevation = TrackingService.instance.estimateElevation(routePoints);

    return RunData(
      startTime: _startTime ?? DateTime.now(),
      endTime: endTime,
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      paceSecondsPerKm: pace.toDouble(),
      caloriesBurned: calories,
      route: routePoints,
      averageSpeedKmh: speeds['avg'],
      maxSpeedKmh: speeds['max'],
      elevationGainMeters: elevation['gain'],
      elevationLossMeters: elevation['loss'],
    );
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _cueManager.dispose();
    super.dispose();
  }
}
