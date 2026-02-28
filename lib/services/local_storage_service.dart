import 'package:hive_flutter/hive_flutter.dart';
import '../features/workouts/workout_model.dart';
import '../models/run_data.dart';
import 'program_progress_service.dart';

class LocalStorageService {
  static const String workoutBoxName = 'workouts';
  static const String runDataBoxName = 'run_sessions';

  static Future<void> init() async {
    await Hive.initFlutter();

    Hive.registerAdapter(CustomWorkoutAdapter());
    Hive.registerAdapter(CustomIntervalAdapter());
    Hive.registerAdapter(RunDataAdapter());
    Hive.registerAdapter(RoutePointAdapter());
    Hive.registerAdapter(ProgramProgressAdapter());

    await Hive.openBox<CustomWorkout>(workoutBoxName);
    await Hive.openBox<RunData>(runDataBoxName);
  }

  // ---- Workout Persistence ----
  static Future<void> saveWorkout(CustomWorkout workout) async {
    final box = Hive.box<CustomWorkout>(workoutBoxName);
    await box.add(workout);
  }

  static List<CustomWorkout> getWorkouts() {
    final box = Hive.box<CustomWorkout>(workoutBoxName);
    return box.values.toList();
  }

  // ---- Run Session Persistence ----
  static Future<void> saveRun(RunData run) async {
    final box = Hive.box<RunData>(runDataBoxName);
    await box.add(run);
  }

  static List<RunData> getRunHistory() {
    final box = Hive.box<RunData>(runDataBoxName);
    return box.values.toList().reversed.toList(); // Most recent first
  }
}
