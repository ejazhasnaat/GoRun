// lib/data/z25k_data.dart

import 'models/run_category.dart';
import 'models/run_program.dart';

// Define types for intervals
enum IntervalType { warmup, run, walk, cooldown }

class WorkoutInterval {
  final IntervalType type;
  final int duration; // in seconds

  const WorkoutInterval(this.type, this.duration);
}

class Workout {
  final String name;
  final int warmup;
  final int runDuration;
  final int walkDuration;
  final int intervals;
  final int cooldown;
  final int? alternateRunDuration;
  final int? alternateWalkDuration;
  final int? alternateIntervals;

  const Workout({
    required this.name,
    required this.warmup,
    required this.runDuration,
    required this.walkDuration,
    required this.intervals,
    required this.cooldown,
    this.alternateRunDuration,
    this.alternateWalkDuration,
    this.alternateIntervals,
  });

  List<WorkoutInterval> getIntervals() {
    final List<WorkoutInterval> result = [];

    // Warmup
    result.add(WorkoutInterval(IntervalType.warmup, warmup));

    // Main run/walk intervals
    for (int i = 0; i < intervals; i++) {
      result.add(WorkoutInterval(IntervalType.run, runDuration));
      if (walkDuration > 0) {
        result.add(WorkoutInterval(IntervalType.walk, walkDuration));
      }
    }

    // Alternate intervals if defined
    if (alternateIntervals != null &&
        alternateRunDuration != null &&
        alternateWalkDuration != null) {
      for (int i = 0; i < alternateIntervals!; i++) {
        result.add(WorkoutInterval(IntervalType.run, alternateRunDuration!));
        if (alternateWalkDuration! > 0) {
          result.add(WorkoutInterval(IntervalType.walk, alternateWalkDuration!));
        }
      }
    }

    // Cooldown
    result.add(WorkoutInterval(IntervalType.cooldown, cooldown));

    return result;
  }
}

class FiveKProgram extends RunProgram {
  static final instance = FiveKProgram._();

  FiveKProgram._();

  @override
  String get id => 'z25k_v1';

  @override
  String get displayName => 'Zero to 5K';

  @override
  String get subtitle => '9-week beginner running program';

  @override
  RunCategory get category => RunCategory.fiveK;

  @override
  int get totalWeeks => _weeks.length;

  @override
  int get daysPerWeek => 3;

  @override
  bool get isFree => true;

  @override
  String? get prerequisiteId => null;

  @override
  String get imagePath => 'assets/images/start.jpg';

  @override
  List<List<Workout>> get weeks => _weeks;

  static const List<List<Workout>> _weeks = [
    // Week 1
    [
      Workout(name: "Week 1, Run 1", warmup: 300, intervals: 8, runDuration: 60, walkDuration: 90, cooldown: 300),
      Workout(name: "Week 1, Run 2", warmup: 300, intervals: 8, runDuration: 60, walkDuration: 90, cooldown: 300),
      Workout(name: "Week 1, Run 3", warmup: 300, intervals: 8, runDuration: 60, walkDuration: 90, cooldown: 300),
    ],
    // Week 2
    [
      Workout(name: "Week 2, Run 1", warmup: 300, intervals: 6, runDuration: 90, walkDuration: 120, cooldown: 300),
      Workout(name: "Week 2, Run 2", warmup: 300, intervals: 6, runDuration: 90, walkDuration: 120, cooldown: 300),
      Workout(name: "Week 2, Run 3", warmup: 300, intervals: 6, runDuration: 90, walkDuration: 120, cooldown: 300),
    ],
    // Week 3
    [
      Workout(name: "Week 3, Run 1", warmup: 300, intervals: 4, runDuration: 90, walkDuration: 90, cooldown: 300, alternateIntervals: 2, alternateRunDuration: 180, alternateWalkDuration: 180),
      Workout(name: "Week 3, Run 2", warmup: 300, intervals: 4, runDuration: 90, walkDuration: 90, cooldown: 300, alternateIntervals: 2, alternateRunDuration: 180, alternateWalkDuration: 180),
      Workout(name: "Week 3, Run 3", warmup: 300, intervals: 4, runDuration: 90, walkDuration: 90, cooldown: 300, alternateIntervals: 2, alternateRunDuration: 180, alternateWalkDuration: 180),
    ],
    // Week 4
    [
      Workout(name: "Week 4, Run 1", warmup: 300, intervals: 3, runDuration: 180, walkDuration: 90, cooldown: 300, alternateIntervals: 2, alternateRunDuration: 300, alternateWalkDuration: 150),
      Workout(name: "Week 4, Run 2", warmup: 300, intervals: 3, runDuration: 180, walkDuration: 90, cooldown: 300, alternateIntervals: 2, alternateRunDuration: 300, alternateWalkDuration: 150),
      Workout(name: "Week 4, Run 3", warmup: 300, intervals: 3, runDuration: 180, walkDuration: 90, cooldown: 300, alternateIntervals: 2, alternateRunDuration: 300, alternateWalkDuration: 150),
    ],
    // Week 5
    [
      Workout(name: "Week 5, Run 1", warmup: 300, intervals: 3, runDuration: 300, walkDuration: 180, cooldown: 300),
      Workout(name: "Week 5, Run 2", warmup: 300, intervals: 1, runDuration: 480, walkDuration: 300, cooldown: 300, alternateIntervals: 1, alternateRunDuration: 480, alternateWalkDuration: 0),
      Workout(name: "Week 5, Run 3", warmup: 300, intervals: 1, runDuration: 1200, walkDuration: 0, cooldown: 300),
    ],
    // Week 6
    [
      Workout(name: "Week 6, Run 1", warmup: 300, intervals: 1, runDuration: 300, walkDuration: 180, cooldown: 300, alternateIntervals: 1, alternateRunDuration: 480, alternateWalkDuration: 180),
      Workout(name: "Week 6, Run 2", warmup: 300, intervals: 1, runDuration: 600, walkDuration: 180, cooldown: 300, alternateIntervals: 1, alternateRunDuration: 600, alternateWalkDuration: 0),
      Workout(name: "Week 6, Run 3", warmup: 300, intervals: 1, runDuration: 1350, walkDuration: 0, cooldown: 300),
    ],
    // Week 7
    [
      Workout(name: "Week 7, Run 1", warmup: 300, intervals: 1, runDuration: 1500, walkDuration: 0, cooldown: 300),
      Workout(name: "Week 7, Run 2", warmup: 300, intervals: 1, runDuration: 1500, walkDuration: 0, cooldown: 300),
      Workout(name: "Week 7, Run 3", warmup: 300, intervals: 1, runDuration: 1500, walkDuration: 0, cooldown: 300),
    ],
    // Week 8
    [
      Workout(name: "Week 8, Run 1", warmup: 300, intervals: 1, runDuration: 1680, walkDuration: 0, cooldown: 300),
      Workout(name: "Week 8, Run 2", warmup: 300, intervals: 1, runDuration: 1680, walkDuration: 0, cooldown: 300),
      Workout(name: "Week 8, Run 3", warmup: 300, intervals: 1, runDuration: 1680, walkDuration: 0, cooldown: 300),
    ],
    // Week 9
    [
      Workout(name: "Week 9, Run 1", warmup: 300, intervals: 1, runDuration: 1800, walkDuration: 0, cooldown: 300),
      Workout(name: "Week 9, Run 2", warmup: 300, intervals: 1, runDuration: 1800, walkDuration: 0, cooldown: 300),
      Workout(name: "Week 9, Run 3", warmup: 300, intervals: 1, runDuration: 1800, walkDuration: 0, cooldown: 300),
    ],
  ];

  // Backward-compatible static accessors
  static List<List<Workout>> get staticWeeks => instance.weeks;
  static Workout getStaticWorkout(int week, int day) => instance.getWorkout(week, day);
  static List<Workout> get allWorkouts => instance.weeks.expand((week) => week).toList();
}

// Backward-compatibility alias
typedef Z25KProgram = FiveKProgram;
