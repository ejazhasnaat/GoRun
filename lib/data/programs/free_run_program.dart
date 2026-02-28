import '../models/run_category.dart';
import '../models/run_program.dart';
import '../z25k_data.dart';

class FreeRunProgram extends RunProgram {
  static final instance = FreeRunProgram._();

  FreeRunProgram._();

  @override
  String get id => 'free_run';

  @override
  String get displayName => 'Free Run';

  @override
  String get subtitle => 'Run at your own pace, no intervals';

  @override
  RunCategory get category => RunCategory.freeRun;

  @override
  int get totalWeeks => 0;

  @override
  int get daysPerWeek => 0;

  @override
  bool get isFree => true;

  @override
  String? get prerequisiteId => null;

  @override
  String get imagePath => 'assets/images/run.jpg';

  @override
  List<List<Workout>> get weeks => [];

  @override
  int get totalWorkouts => 0;

  @override
  Duration get estimatedDuration => Duration.zero;
}
