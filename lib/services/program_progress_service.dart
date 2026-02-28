import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'program_progress_service.g.dart';

@HiveType(typeId: 10)
class ProgramProgress extends HiveObject {
  @HiveField(0)
  String programId;

  @HiveField(1)
  int lastCompletedDayIndex;

  @HiveField(2)
  int selectedWeekIndex;

  @HiveField(3)
  int selectedDayIndex;

  @HiveField(4)
  bool isCompleted;

  @HiveField(5)
  DateTime? completedAt;

  ProgramProgress({
    required this.programId,
    this.lastCompletedDayIndex = -1,
    this.selectedWeekIndex = 0,
    this.selectedDayIndex = 0,
    this.isCompleted = false,
    this.completedAt,
  });
}

class ProgramProgressService {
  static const String _boxPrefix = 'progress_';

  static Future<Box<ProgramProgress>> _openBox(String programId) async {
    final boxName = '$_boxPrefix$programId';
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<ProgramProgress>(boxName);
    }
    return Hive.openBox<ProgramProgress>(boxName);
  }

  static Future<ProgramProgress> getProgress(String programId) async {
    final box = await _openBox(programId);

    if (box.isEmpty) {
      // Migration: check for legacy SharedPreferences keys for z25k_v1
      if (programId == 'z25k_v1') {
        final migrated = await _migrateFromSharedPreferences(programId);
        if (migrated != null) {
          await box.put('progress', migrated);
          return migrated;
        }
      }

      // Return default progress
      final defaultProgress = ProgramProgress(programId: programId);
      await box.put('progress', defaultProgress);
      return defaultProgress;
    }

    return box.get('progress')!;
  }

  static Future<void> saveProgress(ProgramProgress progress) async {
    final box = await _openBox(progress.programId);
    await box.put('progress', progress);
  }

  static Future<void> markCompleted(String programId) async {
    final progress = await getProgress(programId);
    progress.isCompleted = true;
    progress.completedAt = DateTime.now();
    await saveProgress(progress);
  }

  static Future<void> resetProgress(String programId) async {
    final box = await _openBox(programId);
    final defaultProgress = ProgramProgress(programId: programId);
    await box.put('progress', defaultProgress);
  }

  /// Migrate legacy SharedPreferences data for z25k_v1
  static Future<ProgramProgress?> _migrateFromSharedPreferences(
    String programId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCompleted = prefs.getInt('lastCompletedDayIndex');

      if (lastCompleted == null) return null; // No legacy data

      return ProgramProgress(
        programId: programId,
        lastCompletedDayIndex: lastCompleted,
        selectedWeekIndex: prefs.getInt('selectedWeekIndex') ?? 0,
        selectedDayIndex: prefs.getInt('selectedDayIndex') ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
