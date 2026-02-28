import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../core/theme/app_colors.dart';
import '../features/tracking/tracking_service.dart';
import '../models/run_data.dart';
import '../services/local_storage_service.dart';
import 'run_summary_screen.dart';

class FreeRunScreen extends StatefulWidget {
  const FreeRunScreen({super.key});

  @override
  State<FreeRunScreen> createState() => _FreeRunScreenState();
}

class _FreeRunScreenState extends State<FreeRunScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  DateTime? _startTime;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _startTime ??= DateTime.now();
    _isRunning = true;
    _isPaused = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSeconds++;
      });
    });

    setState(() {});
  }

  void _pause() {
    _timer?.cancel();
    _isPaused = true;
    setState(() {});
  }

  void _resume() {
    _isPaused = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSeconds++;
      });
    });
    setState(() {});
  }

  void _handlePauseResume() {
    if (_isPaused) {
      _resume();
    } else {
      _pause();
    }
  }

  Future<void> _stopAndSave() async {
    _timer?.cancel();
    _isRunning = false;
    _isPaused = false;

    final endTime = DateTime.now();
    final routePoints = await TrackingService.instance.getRoute() ?? [];
    final distanceMeters = TrackingService.instance.calculateDistance(routePoints);
    final pace = distanceMeters > 0
        ? _elapsedSeconds / (distanceMeters / 1000)
        : 0;
    final calories = 65.0 * (_elapsedSeconds / 60.0) * 0.1;
    final speeds = TrackingService.instance.estimateSpeeds(
      routePoints,
      _elapsedSeconds,
    );
    final elevation = TrackingService.instance.estimateElevation(routePoints);

    final runData = RunData(
      startTime: _startTime ?? DateTime.now(),
      endTime: endTime,
      durationSeconds: _elapsedSeconds,
      distanceMeters: distanceMeters,
      paceSecondsPerKm: pace.toDouble(),
      caloriesBurned: calories,
      route: routePoints,
      averageSpeedKmh: speeds['avg'],
      maxSpeedKmh: speeds['max'],
      elevationGainMeters: elevation['gain'],
      elevationLossMeters: elevation['loss'],
    );

    if (runData.durationSeconds >= 60) {
      runData.endTime = endTime;
      await LocalStorageService.saveRun(runData);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RunSummaryScreen(run: runData)),
        );
      }

      _triggerCompletionHaptic();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Run too short to save.")),
      );
      Navigator.pop(context);
    }
  }

  void _triggerCompletionHaptic() {
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 300);
      } else {
        HapticFeedback.heavyImpact();
      }
    });
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Free Run'),
        backgroundColor: AppColors.warmOrange,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Timer display
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatDuration(_elapsedSeconds),
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 72,
                        letterSpacing: -2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Free Run',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.warmOrange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 48),

                // Control buttons
                if (!_isRunning) ...[
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _start,
                          icon: const Icon(Icons.play_arrow_rounded, size: 28),
                          label: const Text('Start', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.calmGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _handlePauseResume,
                            icon: Icon(
                              _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                              size: 24,
                            ),
                            label: Text(
                              _isPaused ? 'Resume' : 'Pause',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.calmGreen,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 52),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _stopAndSave,
                            icon: const Icon(Icons.stop_rounded, size: 24),
                            label: const Text(
                              'Stop & Save',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warmOrange,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 52),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
