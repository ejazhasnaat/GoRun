import 'package:hive/hive.dart';

part 'workout_model.g.dart';

@HiveType(typeId: 0)
class CustomWorkout extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<CustomInterval> intervals;

  CustomWorkout({required this.name, required this.intervals});
}

@HiveType(typeId: 1)
class CustomInterval {
  @HiveField(0)
  int runDuration; // seconds

  @HiveField(1)
  int walkDuration; // seconds

  CustomInterval({required this.runDuration, required this.walkDuration});
}
