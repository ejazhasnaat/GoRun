import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../audio/audio_playback_engine.dart';
import '../data/z25k_data.dart';
import '../models/audio_settings_model.dart';
import '../models/run_data.dart';
import '../features/tracking/tracking_service.dart';
import '../features/audio/audio_coach_engine.dart';

/// Enhanced TimerController with AudioCoachEngine integration.
class TimerController extends ChangeNotifier {
  final Workout workout;
  final AudioPlaybackEngine audioEngine;
  late AudioCoachEngine _audioCoach;

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

  TimerController({
    required this.workout,
    required this.audioEngine,
    required AudioSettingsModel audioSettings,
  }) {
    _audioCoach = AudioCoachEngine(
      engine: audioEngine,
      audioSettings: audioSettings,
    );
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

  void _initializeWorkout() {
    intervals = workout.getIntervals();
    currentIndex = 0;
    currentSegmentRemaining = intervals.first.duration;
    totalElapsedSeconds = 0;
    _isCompleted = false;
  }

  void start() {
    if (isRunning && !isPaused) return;

    isRunning = true;
    isPaused = false;
    _startTime ??= DateTime.now();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    // Fire initial segment announcement
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isDisposed) return;
      _audioCoach.onTick(
        segmentElapsed: 0,
        segmentRemaining: currentSegmentRemaining,
        segmentDuration: currentSegment.duration,
        segmentIndex: currentIndex,
        totalSegments: intervals.length,
        segmentType: currentSegment.type,
        totalElapsed: totalElapsedSeconds,
        totalDuration: totalDuration,
      );
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
      _audioCoach.onWorkoutComplete(workout.name);
    }

    _audioCoach.stop();
    _safeNotify();
  }

  Future<void> _tick() async {
    if (!isRunning || isPaused || _isDisposed) return;

    // Advance timer
    if (currentSegmentRemaining > 0) {
      currentSegmentRemaining--;
      totalElapsedSeconds++;
    } else {
      // Move to next segment or complete
      if (currentIndex < intervals.length - 1) {
        currentIndex++;
        currentSegmentRemaining = intervals[currentIndex].duration;
        _triggerHapticFeedback();
      } else {
        await stop(completed: true);
        return;
      }
    }

    // Calculate segment elapsed for audio coach
    final segmentElapsed = currentSegment.duration - currentSegmentRemaining;

    // Single entry point for all audio cues
    _audioCoach.onTick(
      segmentElapsed: segmentElapsed,
      segmentRemaining: currentSegmentRemaining,
      segmentDuration: currentSegment.duration,
      segmentIndex: currentIndex,
      totalSegments: intervals.length,
      segmentType: currentSegment.type,
      totalElapsed: totalElapsedSeconds,
      totalDuration: totalDuration,
    );

    _safeNotify();
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

      _audioCoach.onSegmentJump(currentIndex);
      _safeNotify();
    }
  }

  void nextSegment() {
    if (currentIndex < intervals.length - 1) {
      totalElapsedSeconds += currentSegmentRemaining;
      currentIndex++;
      currentSegmentRemaining = intervals[currentIndex].duration;

      _audioCoach.onSegmentJump(currentIndex);
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

    _audioCoach.onSegmentJump(index);

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
    _audioCoach.dispose();
    super.dispose();
  }
}
