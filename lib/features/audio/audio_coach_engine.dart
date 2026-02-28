import '../../audio/audio_playback_engine.dart';
import '../../data/z25k_data.dart';
import '../../models/audio_settings_model.dart';
import 'phrase_library.dart';
import 'speech_queue.dart';

class AudioCoachEngine {
  final SpeechQueue _queue;
  final PhraseLibrary _phrases;
  final AudioSettingsModel _audioSettings;

  // Tracking state
  final Set<int> _firedMilestones = {};
  int _lastCountdownSecond = -1;
  int _lastAnnouncedSegmentIndex = -1;
  bool _segmentHalfwayFired = false;

  AudioCoachEngine({
    required AudioPlaybackEngine engine,
    required AudioSettingsModel audioSettings,
  })  : _queue = SpeechQueue(engine),
        _phrases = PhraseLibrary(),
        _audioSettings = audioSettings;

  CoachStyle get _style {
    switch (_audioSettings.style.toLowerCase()) {
      case 'calm':
        return CoachStyle.calm;
      case 'energetic':
        return CoachStyle.energetic;
      default:
        return CoachStyle.neutral;
    }
  }

  /// Single entry point called every tick.
  void onTick({
    required int segmentElapsed,
    required int segmentRemaining,
    required int segmentDuration,
    required int segmentIndex,
    required int totalSegments,
    required IntervalType segmentType,
    required int totalElapsed,
    required int totalDuration,
  }) {
    if (!_audioSettings.enableTTS) return;

    final segmentName = segmentType.name;

    // COUNTDOWN: P0, highest priority, return early
    if (_audioSettings.enableCountdownCue &&
        segmentRemaining <= 5 &&
        segmentRemaining > 0) {
      if (segmentRemaining != _lastCountdownSecond) {
        _lastCountdownSecond = segmentRemaining;
        _queue.enqueue(
          _phrases.getPhrase(CueType.countdown, _style,
              vars: {'n': segmentRemaining.toString()}),
          SpeechPriority.p0,
        );
      }
      return; // Nothing else during countdown
    }

    // Reset countdown tracking when not in countdown zone
    if (segmentRemaining > 5) {
      _lastCountdownSecond = -1;
    }

    // SEGMENT_START: P0
    if (segmentElapsed == 0 && segmentIndex != _lastAnnouncedSegmentIndex) {
      _lastAnnouncedSegmentIndex = segmentIndex;
      _segmentHalfwayFired = false;

      _queue.enqueue(
        _phrases.getPhrase(CueType.segmentStart, _style, vars: {
          'name': segmentName,
          'duration': PhraseLibrary.spokenDuration(segmentDuration),
          'n': (segmentIndex + 1).toString(),
          'total': totalSegments.toString(),
        }),
        SpeechPriority.p0,
      );
      return;
    }

    // NEXT_UP_PREP: P1 - 10 seconds before end of segments > 90s
    if (segmentRemaining == 10 && segmentDuration > 90) {
      // Determine what's next
      if (segmentIndex < totalSegments - 1) {
        // We don't know the next segment's type here, so use generic phrasing
        _queue.enqueue(
          _phrases.getPhrase(CueType.nextUpPrep, _style, vars: {
            'name': 'the next interval',
          }),
          SpeechPriority.p1,
        );
      }
    }

    // TIME_WARNING: P1 - 60s remaining for segments > 180s
    if (segmentRemaining == 60 && segmentDuration > 180) {
      _queue.enqueue(
        _phrases.getPhrase(CueType.timeWarning, _style, vars: {
          'duration': PhraseLibrary.spokenDuration(60),
        }),
        SpeechPriority.p1,
      );
    }

    // TIME_WARNING: P1 - 30s remaining for segments > 120s
    if (segmentRemaining == 30 && segmentDuration > 120) {
      _queue.enqueue(
        _phrases.getPhrase(CueType.timeWarning, _style, vars: {
          'duration': PhraseLibrary.spokenDuration(30),
        }),
        SpeechPriority.p1,
      );
    }

    // SEGMENT_HALFWAY: P2 - for segments > 120s
    if (!_segmentHalfwayFired &&
        _audioSettings.enableHalfwayCue &&
        segmentDuration > 120 &&
        segmentElapsed == segmentDuration ~/ 2) {
      _segmentHalfwayFired = true;
      _queue.enqueue(
        _phrases.getPhrase(CueType.segmentHalfway, _style),
        SpeechPriority.p2,
      );
    }

    // WORKOUT_MILESTONE: P2 - at 25/50/75%
    if (totalDuration > 0) {
      final pct = (totalElapsed * 100) ~/ totalDuration;
      for (final milestone in [25, 50, 75]) {
        if (pct == milestone && !_firedMilestones.contains(milestone)) {
          _firedMilestones.add(milestone);
          _queue.enqueue(
            _phrases.getPhrase(CueType.workoutMilestone, _style, vars: {
              'n': milestone.toString(),
            }),
            SpeechPriority.p2,
          );
        }
      }
    }
  }

  /// Called when the workout is fully complete.
  void onWorkoutComplete(String workoutName) {
    if (!_audioSettings.enableTTS) return;
    _queue.enqueue(
      _phrases.getPhrase(CueType.workoutComplete, _style, vars: {
        'name': workoutName,
      }),
      SpeechPriority.p0,
    );
  }

  /// Called when the user manually jumps to a segment.
  void onSegmentJump(int newIndex) {
    _lastAnnouncedSegmentIndex = -1;
    _lastCountdownSecond = -1;
    _segmentHalfwayFired = false;
    _firedMilestones.clear();
    _queue.clear();
  }

  void stop() {
    _queue.clear();
  }

  void dispose() {
    _queue.dispose();
    _phrases.resetRotation();
  }
}
