import 'models/run_program.dart';
import 'z25k_data.dart';
import 'programs/free_run_program.dart';

class ProgramRegistry {
  static final List<RunProgram> _programs = [
    FiveKProgram.instance,
    FreeRunProgram.instance,
  ];

  static List<RunProgram> get all => List.unmodifiable(_programs);

  static RunProgram? byId(String id) {
    for (final program in _programs) {
      if (program.id == id) return program;
    }
    return null;
  }
}
