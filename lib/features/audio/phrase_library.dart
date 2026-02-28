enum CoachStyle { calm, energetic, neutral }

enum CueType {
  segmentStart,
  countdown,
  nextUpPrep,
  timeWarning,
  segmentHalfway,
  workoutMilestone,
  workoutComplete,
}

class PhraseLibrary {
  // Rotation indices per cue type to avoid consecutive repeats
  final Map<CueType, int> _rotationIndex = {};

  /// Get the next phrase for a cue type and style, rotating through variants.
  String getPhrase(CueType type, CoachStyle style, {Map<String, String>? vars}) {
    final phrases = _phraseBank[type]?[style] ?? _phraseBank[type]?[CoachStyle.neutral] ?? [''];
    final index = _rotationIndex[type] ?? 0;
    final phrase = phrases[index % phrases.length];
    _rotationIndex[type] = index + 1;

    return _resolveTemplate(phrase, vars ?? {});
  }

  /// Convert seconds to spoken duration string.
  static String spokenDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    final parts = <String>[];

    if (minutes > 0) parts.add('$minutes minute${minutes != 1 ? 's' : ''}');
    if (secs > 0) parts.add('$secs second${secs != 1 ? 's' : ''}');
    if (parts.isEmpty) return '0 seconds';

    return parts.join(' and ');
  }

  String _resolveTemplate(String template, Map<String, String> vars) {
    var result = template;
    for (final entry in vars.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  void resetRotation() {
    _rotationIndex.clear();
  }

  // Full phrase bank: 7 cue types x 3 styles
  static const Map<CueType, Map<CoachStyle, List<String>>> _phraseBank = {
    CueType.segmentStart: {
      CoachStyle.calm: [
        'Time to {name}. {duration} ahead.',
        'Let\'s ease into {name}. {duration} to go.',
        '{name} now. Take it steady for {duration}.',
      ],
      CoachStyle.energetic: [
        'Let\'s go! {name} time! {duration}!',
        'Here we go! {name} for {duration}! You got this!',
        '{name}! Push it for {duration}!',
      ],
      CoachStyle.neutral: [
        '{name}. {duration}.',
        'Starting {name}. {duration} remaining.',
        'Begin {name} for {duration}.',
      ],
    },
    CueType.countdown: {
      CoachStyle.calm: ['{n}'],
      CoachStyle.energetic: ['{n}'],
      CoachStyle.neutral: ['{n}'],
    },
    CueType.nextUpPrep: {
      CoachStyle.calm: [
        'Coming up next, {name}.',
        'Get ready. {name} is next.',
      ],
      CoachStyle.energetic: [
        'Almost there! {name} coming up!',
        'Get ready! {name} is next!',
      ],
      CoachStyle.neutral: [
        'Next up, {name}.',
        'Prepare for {name}.',
      ],
    },
    CueType.timeWarning: {
      CoachStyle.calm: [
        '{duration} remaining. You\'re doing great.',
        'Just {duration} left. Keep it up.',
      ],
      CoachStyle.energetic: [
        '{duration} to go! Keep pushing!',
        'Only {duration} left! Stay strong!',
      ],
      CoachStyle.neutral: [
        '{duration} remaining.',
        '{duration} left in this segment.',
      ],
    },
    CueType.segmentHalfway: {
      CoachStyle.calm: [
        'Halfway through this segment. Nice and steady.',
        'You\'re at the halfway point. Keep going.',
      ],
      CoachStyle.energetic: [
        'Halfway there! Keep that energy up!',
        'Half done! You\'re crushing it!',
      ],
      CoachStyle.neutral: [
        'Halfway through this segment.',
        'You\'re at the midpoint.',
      ],
    },
    CueType.workoutMilestone: {
      CoachStyle.calm: [
        'You\'ve completed {n} percent of your workout.',
        '{n} percent done. Well done.',
      ],
      CoachStyle.energetic: [
        '{n} percent done! Amazing work!',
        'You\'re {n} percent through! Keep it up!',
      ],
      CoachStyle.neutral: [
        '{n} percent complete.',
        'Workout is {n} percent done.',
      ],
    },
    CueType.workoutComplete: {
      CoachStyle.calm: [
        'Workout complete. Great job today.',
        'You did it. Well done on finishing {name}.',
      ],
      CoachStyle.energetic: [
        'Workout complete! Amazing effort!',
        'You crushed it! {name} is done!',
      ],
      CoachStyle.neutral: [
        'Workout complete. {name} finished.',
        '{name} is done. Good work.',
      ],
    },
  };
}
