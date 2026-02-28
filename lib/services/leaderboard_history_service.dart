import 'package:hive/hive.dart';
import '../models/run_data.dart';

class LeaderboardHistoryService {
  final String _boxName = 'run_history';

  /// Fetch all saved runs from Hive
  Future<List<RunData>> fetchAllRuns() async {
    final box = await Hive.openBox<RunData>(_boxName);
    return box.values.toList();
  }

  /// Get top runs sorted by distance (you can change this to 'duration' or 'pace' if needed)
  Future<List<RunData>> getTopRunsByDistance({int limit = 10}) async {
    final allRuns = await fetchAllRuns();

    allRuns.sort((a, b) => b.distanceMeters.compareTo(a.distanceMeters)); // Descending by distance
    return allRuns.take(limit).toList();
  }

  /// Get top runs sorted by duration
  Future<List<RunData>> getTopRunsByDuration({int limit = 10}) async {
    final allRuns = await fetchAllRuns();

    allRuns.sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds)); // Descending by duration
    return allRuns.take(limit).toList();
  }

  /// Get top runs sorted by average pace (faster is better)
  Future<List<RunData>> getTopRunsByPace({int limit = 10}) async {
    final allRuns = await fetchAllRuns();

    allRuns.removeWhere((run) => run.paceSecondsPerKm == 0); // Avoid division-by-zero edge case
    allRuns.sort((a, b) => a.paceSecondsPerKm.compareTo(b.paceSecondsPerKm)); // Ascending by pace (lower = better)
    return allRuns.take(limit).toList();
  }
}
