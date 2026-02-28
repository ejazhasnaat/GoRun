import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';

import '../data/z25k_data.dart';
import '../data/models/run_program.dart';
import '../utils/workout_formatter.dart';
import '../core/theme/app_colors.dart';
import '../services/program_progress_service.dart';
import 'run_session_screen.dart';
import 'settings_screen.dart';
import 'leaderboard_history_screen.dart';

class MainRunScreen extends StatefulWidget {
  final RunProgram program;

  const MainRunScreen({super.key, required this.program});

  @override
  State<MainRunScreen> createState() => _MainRunScreenState();
}

class _MainRunScreenState extends State<MainRunScreen> {
  final GlobalKey _menuKey = GlobalKey();
  late Workout selectedWorkout;
  late int selectedWeekIndex;
  late int selectedDayIndex;
  late ConfettiController _confettiController;
  late ScrollController _scrollController;

  final double cardWidth = 90.0;
  final double cardHeight = 90.0;
  final PageController _pageController = PageController(viewportFraction: 0.28);
  final AudioPlayer audioPlayer = AudioPlayer();

  int lastCompletedDayIndex = -1;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _scrollController = ScrollController();
    _loadProgress();

    // Jump to initial page in center
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isLoading) {
        final initialPage = selectedWeekIndex * widget.program.daysPerWeek + selectedDayIndex;
        _pageController.jumpToPage(initialPage);
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  void _loadProgress() async {
    final progress = await ProgramProgressService.getProgress(widget.program.id);
    if (!mounted) return;
    setState(() {
      lastCompletedDayIndex = progress.lastCompletedDayIndex;
      selectedWeekIndex = progress.selectedWeekIndex;
      selectedDayIndex = progress.selectedDayIndex;
      selectedWorkout = widget.program.getWorkout(selectedWeekIndex, selectedDayIndex);
      isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialPage = selectedWeekIndex * widget.program.daysPerWeek + selectedDayIndex;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(initialPage);
      }
    });
  }

  void _saveProgress() async {
    final progress = ProgramProgress(
      programId: widget.program.id,
      lastCompletedDayIndex: lastCompletedDayIndex,
      selectedWeekIndex: selectedWeekIndex,
      selectedDayIndex: selectedDayIndex,
    );
    await ProgramProgressService.saveProgress(progress);
  }

  void _onWorkoutCompleted() {
    setState(() {
      final currentIndex = selectedWeekIndex * widget.program.daysPerWeek + selectedDayIndex;
      if (currentIndex > lastCompletedDayIndex) {
        lastCompletedDayIndex = currentIndex;
        _confettiController.play();
        _saveProgress();
      }
    });
  }

  Future<void> _playSwipeSound() async {
    try {
      await audioPlayer.play(AssetSource('audio/swipe.mp3'));
    } catch (_) {
      // Ignore errors silently
    }
  }

  void _onDayPageChanged(int index) {
    _playSwipeSound();
    final daysPerWeek = widget.program.daysPerWeek;
    setState(() {
      selectedWeekIndex = index ~/ daysPerWeek;
      selectedDayIndex = index % daysPerWeek;
      selectedWorkout = widget.program.getWorkout(selectedWeekIndex, selectedDayIndex);
    });
  }

  void _showOptionsMenu() {
    final RenderBox button = _menuKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: const [
              Icon(Icons.settings, color: AppColors.calmGreen),
              SizedBox(width: 8),
              Text("Settings"),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'leaderboard',
          child: Row(
            children: const [
              Icon(Icons.leaderboard, color: AppColors.calmGreen),
              SizedBox(width: 8),
              Text("View Leaderboard"),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'settings') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
      } else if (value == 'leaderboard') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardHistoryScreen()));
      }
    });
  }

  void _onStartRunning() {
    final currentIndex = selectedWeekIndex * widget.program.daysPerWeek + selectedDayIndex;
    if (currentIndex > lastCompletedDayIndex + 1) {
      _showSkipStartDialog();
    } else {
      _navigateToRunSession();
    }
  }

  void _navigateToRunSession() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RunSessionScreen(
          workout: selectedWorkout,
          onComplete: _onWorkoutCompleted,
        ),
      ),
    );
  }

  void _showSkipStartDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Start Skipped Workout?"),
          content: const Text(
            "You are skipping scheduled days. Do you still want to start this session?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text("Cancel", style: TextStyle(color: colorScheme.primary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (mounted) _navigateToRunSession();
              },
              child: Text("Start Anyway", style: TextStyle(color: colorScheme.secondary)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final dayLabels = <String>[];
    final workouts = <Workout>[];
    final daysPerWeek = widget.program.daysPerWeek;

    for (int week = 0; week < widget.program.totalWeeks; week++) {
      for (int day = 0; day < widget.program.weeks[week].length; day++) {
        dayLabels.add('WEEK ${week + 1}\nDAY ${day + 1}');
        workouts.add(widget.program.weeks[week][day]);
      }
    }

    final totalDays = workouts.length;
    final completedDays = (lastCompletedDayIndex + 1).clamp(0, totalDays);
    final progress = completedDays / totalDays;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.program.displayName),
        centerTitle: true,
        backgroundColor: AppColors.calmGreen,
        elevation: 0,
        actions: [
          IconButton(
            key: _menuKey,
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: _showOptionsMenu,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Workout Summary Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Card(
                  color: theme.cardColor,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.timer, color: AppColors.calmGreen),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                "Duration: ${getTotalWorkoutTime(selectedWorkout)} min",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.directions_run, color: AppColors.warmOrange),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                formatWorkoutDescription(selectedWorkout),
                                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Big Stretched Image Banner
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      widget.program.imagePath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),

              // Progress Bar & Start Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      color: colorScheme.primary,
                      minHeight: 10,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _onStartRunning,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warmOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          "Start Workout",
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimary,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Day Selector with Navigation Arrows
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: AppColors.calmGreen),
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: cardHeight,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: dayLabels.length,
                          onPageChanged: _onDayPageChanged,
                          itemBuilder: (context, index) {
                            final isSelected = index == selectedWeekIndex * daysPerWeek + selectedDayIndex;
                            final isCompleted = index <= lastCompletedDayIndex;

                            final cardColor = isSelected
                                ? AppColors.calmGreen
                                : isCompleted
                                    ? colorScheme.secondary
                                    : theme.cardColor;

                            final textColor = isSelected || isCompleted
                                ? colorScheme.onPrimary
                                : theme.textTheme.bodyMedium?.color;

                            return GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                width: cardWidth,
                                height: cardWidth,
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  border: Border.all(color: AppColors.calmGreen, width: 2),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.calmGreen.withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : [],
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Center(
                                  child: Text(
                                    dayLabels[index],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: AppColors.calmGreen),
                      onPressed: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Confetti Animation
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: [colorScheme.secondary, colorScheme.primary, Colors.white],
              numberOfParticles: 30,
              maxBlastForce: 30,
              minBlastForce: 10,
              emissionFrequency: 0.05,
              gravity: 0.1,
              particleDrag: 0.05,
            ),
          ),
        ],
      ),
    );
  }
}
