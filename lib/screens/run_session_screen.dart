import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

import '../data/z25k_data.dart';
import '../controllers/intervals_controller.dart';
import '../audio/audio_playback_engine.dart';
import '../services/audio_settings_service.dart';
import '../services/local_storage_service.dart';
import '../models/run_data.dart';
import '../screens/run_summary_screen.dart';
import '../core/theme/app_colors.dart';

class RunSessionScreen extends StatefulWidget {
  final Workout workout;
  final VoidCallback? onComplete;

  const RunSessionScreen({super.key, required this.workout, this.onComplete});

  @override
  State<RunSessionScreen> createState() => _RunSessionScreenState();
}

class _RunSessionScreenState extends State<RunSessionScreen>
    with TickerProviderStateMixin {
  // Controllers and Services
  late TimerController _timerController;
  late AudioPlaybackEngine _audioEngine;
  late ConfettiController _confettiController;
  late AudioSettingsService _audioSettingsService;

  // UI Controllers
  final PageController _intervalPageController = PageController(
    viewportFraction: 0.25,
  );
  final AudioPlayer _tickPlayer = AudioPlayer();

  // State flags
  bool _summaryShown = false;
  bool _isLocked = false;
  bool _isAnimatingPage = false;
  bool _isInitialized = false;

  // Timers
  Timer? _tickingTimer;

  // Animations
  late AnimationController _pauseResumeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeComponents();
    _setupListeners();
    _scheduleInitialSetup();
  }

  void _initializeComponents() {
    // Initialize audio settings service
    _audioSettingsService = Provider.of<AudioSettingsService>(
      context,
      listen: false,
    );
    _audioEngine = AudioPlaybackEngine(_audioSettingsService.settings);

    // Listen for settings changes
    _audioSettingsService.onSettingsChanged = (newSettings) {
      _audioEngine.reloadSettings(newSettings);
      // Update timer controller audio settings
      _timerController.updateAudioSettings(
        enableTTS: newSettings.enableTTS,
        enableCountdownCue: newSettings.enableCountdownCue,
        enableHalfwayCue: newSettings.enableHalfwayCue,
      );
    };

    // Initialize timer controller
    _timerController = TimerController(
      workout: widget.workout,
      audioEngine: _audioEngine,
    );

    // Set initial audio settings
    _timerController.updateAudioSettings(
      enableTTS: _audioSettingsService.settings.enableTTS,
      enableCountdownCue: _audioSettingsService.settings.enableCountdownCue,
      enableHalfwayCue: _audioSettingsService.settings.enableHalfwayCue,
    );

    // Initialize confetti controller
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Initialize animations
    _pauseResumeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _pauseResumeController,
      curve: Curves.easeInOut,
    );
  }

  void _setupListeners() {
    _timerController.addListener(_onTimerUpdate);
  }

  void _scheduleInitialSetup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timerController.start();
      Future.delayed(const Duration(milliseconds: 500), () {
        setState(() => _isInitialized = true);
      });
    });
  }

  void _onTimerUpdate() {
    // Handle ticking sound for last 5 seconds
    _handleTickingSound(_timerController.currentSegmentRemaining);

    // Handle page animation to current segment
    _animateToCurrentSegment();

    // Handle workout completion
    if (_timerController.isCompleted && !_summaryShown) {
      _handleWorkoutCompletion();
    }

    setState(() {});
  }

  void _handleTickingSound(int remaining) {
    if (remaining <= 5 && remaining > 0) {
      _playTickingSound();
    } else {
      _tickingTimer?.cancel();
    }
  }

  void _handleWorkoutCompletion() {
    _summaryShown = true;
    _confettiController.play();
    widget.onComplete?.call();
    _stopAndSaveRun(context, autoComplete: true);
  }

  void _animateToCurrentSegment() {
    final int index = _timerController.currentIndex;
    final int maxIndex = _timerController.intervals.length - 1;

    if (_intervalPageController.hasClients &&
        !_isAnimatingPage &&
        index >= 0 &&
        index <= maxIndex &&
        _intervalPageController.page?.round() != index) {
      _isAnimatingPage = true;
      _intervalPageController
          .animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
          )
          .whenComplete(() => _isAnimatingPage = false)
          .catchError((e) => _isAnimatingPage = false);
    }
  }

  void _playTickingSound() {
    _tickingTimer?.cancel();
    int tickCount = 0;

    _tickingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (tickCount >= 5) {
        timer.cancel();
        return;
      }
      _tickPlayer.stop();
      _tickPlayer.play(AssetSource('assets/audio/tick.mp3'), volume: 0.5);
      tickCount++;
    });
  }

  @override
  void dispose() {
    _timerController.removeListener(_onTimerUpdate);
    _timerController.dispose();
    _audioEngine.dispose();
    _confettiController.dispose();
    _intervalPageController.dispose();
    _tickingTimer?.cancel();
    _tickPlayer.dispose();
    _pauseResumeController.dispose();
    super.dispose();
  }

  Future<void> _stopAndSaveRun(
    BuildContext ctx, {
    bool autoComplete = false,
  }) async {
    await _timerController.stop();
    final runData = await _timerController.generateRunData();

    if (runData.durationSeconds >= 60) {
      runData.endTime = DateTime.now();
      await LocalStorageService.saveRun(runData);

      if (ctx.mounted) {
        Navigator.pushReplacement(
          ctx,
          MaterialPageRoute(builder: (_) => RunSummaryScreen(run: runData)),
        );
      }

      _triggerCompletionHaptic();
    } else if (!autoComplete && ctx.mounted) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text("Run too short to save.")));
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
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  void _onSwipeLeft() {
    if (_isLocked) return;
    _timerController.nextSegment();
  }

  void _onSwipeRight() {
    if (_isLocked) return;
    _timerController.previousSegment();
  }

  String _getImageForSegment(String name) {
    switch (name.toLowerCase()) {
      case 'walk':
        return 'assets/images/walk.jpg';
      case 'run':
        return 'assets/images/run.jpg';
      case 'warmup':
        return 'assets/images/warmup.jpg';
      case 'cooldown':
        return 'assets/images/cooldown.jpg';
      default:
        return 'assets/images/running.jpg';
    }
  }

  void _handlePauseResume() {
    if (_timerController.isRunning) {
      setState(() {
        _pauseResumeController.reverse(from: 1);
        _timerController.pause();
      });
    } else {
      setState(() {
        _pauseResumeController.forward(from: 0);
        _timerController.resume();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChangeNotifierProvider.value(
      value: _timerController,
      child: Consumer2<TimerController, AudioSettingsService>(
        builder: (ctx, timer, audioSettings, __) {
          final current = timer.currentSegment;
          final totalDuration = timer.totalDuration;
          final elapsed = timer.elapsedSeconds;
          final progress = (elapsed / totalDuration).clamp(0.0, 1.0);
          final currentSegmentRemaining = timer.currentSegmentRemaining;
          final isPaused = timer.isPaused;

          return GestureDetector(
            onHorizontalDragEnd: (details) {
              if (_isLocked) return;
              const velocityThreshold = 300;
              if (details.primaryVelocity! < -velocityThreshold) {
                _onSwipeLeft();
              } else if (details.primaryVelocity! > velocityThreshold) {
                _onSwipeRight();
              }
            },
            child: Scaffold(
              appBar: AppBar(
                title: const Text("Zero to 5K"),
                backgroundColor: AppColors.calmGreen,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Icon(_isLocked ? Icons.lock : Icons.lock_open),
                    onPressed: () => setState(() => _isLocked = !_isLocked),
                  ),
                ],
              ),
              body: Stack(
                children: [
                  Column(
                    children: [
                      // Background image section
                      _buildBackgroundImage(current),

                      const SizedBox(height: 8),

                      // Progress indicator
                      _buildProgressIndicator(theme, progress),

                      const SizedBox(height: 12),

                      // Interval navigation section
                      _buildIntervalNavigation(theme, timer),

                      const SizedBox(height: 14),

                      // Circular timer
                      _buildCircularTimer(
                        current,
                        currentSegmentRemaining,
                        theme,
                      ),

                      const SizedBox(height: 12),

                      // Time display section
                      _buildTimeDisplay(theme, elapsed, totalDuration),

                      const SizedBox(height: 12),

                      // Control buttons
                      _buildControlButtons(theme, isPaused),

                      const SizedBox(height: 20),
                    ],
                  ),

                  // Confetti overlay
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      numberOfParticles: 30,
                      gravity: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackgroundImage(WorkoutInterval current) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.45,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              _getImageForSegment(current.type.name),
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
              child: Container(color: Colors.black.withOpacity(0.15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(ThemeData theme, double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 8,
        color: AppColors.warmOrange,
        backgroundColor: theme.colorScheme.surface.withOpacity(0.3),
      ),
    );
  }

  Widget _buildIntervalNavigation(ThemeData theme, TimerController timer) {
    return SizedBox(
      height: 96,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _isLocked ? null : _onSwipeRight,
            icon: const Icon(Icons.skip_previous_rounded),
            iconSize: 32,
            tooltip: "Previous Interval",
            color: _isLocked ? AppColors.mediumGray : theme.colorScheme.primary,
          ),
          const SizedBox(width: 2),
          Expanded(child: _buildIntervalCards(theme, timer)),
          const SizedBox(width: 2),
          IconButton(
            onPressed: _isLocked ? null : _onSwipeLeft,
            icon: const Icon(Icons.skip_next_rounded),
            iconSize: 32,
            tooltip: "Next Interval",
            color: _isLocked ? AppColors.mediumGray : theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalCards(ThemeData theme, TimerController timer) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: ListView.separated(
        key: ValueKey<int>(timer.currentIndex),
        scrollDirection: Axis.horizontal,
        controller: _intervalPageController,
        physics: _isLocked
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: timer.intervals.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final segment = timer.intervals[idx];
          final isCurrent = idx == timer.currentIndex;
          final isCompleted = idx < timer.currentIndex;
          return AspectRatio(
            aspectRatio: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: isCompleted
                    ? theme.colorScheme.surfaceVariant
                    : theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent ? AppColors.warmOrange : Colors.transparent,
                  width: 2,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: AppColors.warmOrange.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        segment.type.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isCurrent
                              ? AppColors.warmOrange
                              : theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDuration(segment.duration),
                      style: TextStyle(
                        fontSize: 13,
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCircularTimer(
    WorkoutInterval current,
    int currentSegmentRemaining,
    ThemeData theme,
  ) {
    return CircularPercentIndicator(
      radius: 54,
      lineWidth: 10,
      percent: (1.0 - (currentSegmentRemaining / current.duration)).clamp(
        0.0,
        1.0,
      ),
      center: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatDuration(currentSegmentRemaining),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.warmOrange,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            current.type.name.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
      progressColor: AppColors.warmOrange,
      backgroundColor: AppColors.lightGray,
      circularStrokeCap: CircularStrokeCap.round,
    );
  }

  Widget _buildTimeDisplay(ThemeData theme, int elapsed, int totalDuration) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.cardColor, theme.cardColor.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Elapsed Timer
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.calmGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.timer_outlined,
                      size: 28,
                      color: AppColors.calmGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Elapsed",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.calmGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDuration(elapsed),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Vertical Divider
            Container(
              width: 1,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.outline.withOpacity(0.0),
                    theme.colorScheme.outline.withOpacity(0.3),
                    theme.colorScheme.outline.withOpacity(0.0),
                  ],
                ),
              ),
            ),

            // Remaining Timer
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warmOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.hourglass_bottom_outlined,
                      size: 28,
                      color: AppColors.warmOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Remaining",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warmOrange,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDuration(
                          (totalDuration - elapsed).clamp(0, totalDuration),
                        ),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons(ThemeData theme, bool isPaused) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: _isLocked ? null : _handlePauseResume,
          icon: Icon(
            isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            size: 24,
          ),
          label: Text(
            isPaused ? "Resume" : "Pause",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.calmGreen,
            foregroundColor: theme.colorScheme.onPrimary,
            minimumSize: const Size(140, 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 3,
          ),
        ),

        ElevatedButton.icon(
          onPressed: _isLocked
              ? null
              : () async {
                  await _stopAndSaveRun(context);
                },
          icon: const Icon(Icons.stop_rounded, size: 24),
          label: const Text(
            "Stop & Save",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warmOrange,
            foregroundColor: theme.colorScheme.onError,
            minimumSize: const Size(140, 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 3,
          ),
        ),
      ],
    );
  }
}
