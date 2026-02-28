import '../z25k_data.dart';
import 'run_category.dart';

abstract class RunProgram {
  String get id;
  String get displayName;
  String get subtitle;
  RunCategory get category;
  int get totalWeeks;
  int get daysPerWeek;
  bool get isFree;
  String? get prerequisiteId;
  List<List<Workout>> get weeks;
  String get imagePath;

  Workout getWorkout(int week, int day) => weeks[week][day];

  int get totalWorkouts =>
      weeks.fold(0, (sum, week) => sum + week.length);

  Duration get estimatedDuration {
    int totalSeconds = 0;
    for (final week in weeks) {
      for (final workout in week) {
        final intervals = workout.getIntervals();
        totalSeconds += intervals.fold(0, (sum, i) => sum + i.duration);
      }
    }
    return Duration(seconds: totalSeconds);
  }
}
