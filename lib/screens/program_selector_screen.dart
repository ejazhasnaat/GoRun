import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/models/run_category.dart';
import '../data/models/run_program.dart';
import '../data/program_registry.dart';
import '../services/program_progress_service.dart';
import 'main_run_screen.dart';
import 'free_run_screen.dart';

class ProgramSelectorScreen extends StatefulWidget {
  const ProgramSelectorScreen({super.key});

  @override
  State<ProgramSelectorScreen> createState() => _ProgramSelectorScreenState();
}

class _ProgramSelectorScreenState extends State<ProgramSelectorScreen> {
  final Map<String, ProgramProgress> _progressMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    for (final program in ProgramRegistry.all) {
      if (program.category != RunCategory.freeRun) {
        _progressMap[program.id] =
            await ProgramProgressService.getProgress(program.id);
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onProgramTap(RunProgram program) {
    if (program.category == RunCategory.freeRun) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FreeRunScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MainRunScreen(program: program),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final programs = ProgramRegistry.all;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('GoRun'),
        centerTitle: true,
        backgroundColor: AppColors.calmGreen,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: programs.length,
              itemBuilder: (context, index) {
                final program = programs[index];
                return _buildProgramCard(context, program, theme);
              },
            ),
    );
  }

  Widget _buildProgramCard(
    BuildContext context,
    RunProgram program,
    ThemeData theme,
  ) {
    final isFreeRun = program.category == RunCategory.freeRun;
    final progress = _progressMap[program.id];

    double progressValue = 0.0;
    if (!isFreeRun && progress != null && program.totalWorkouts > 0) {
      progressValue =
          (progress.lastCompletedDayIndex + 1) / program.totalWorkouts;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _onProgramTap(program),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Program icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isFreeRun
                      ? AppColors.warmOrange.withValues(alpha: 0.15)
                      : AppColors.calmGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isFreeRun ? Icons.directions_run : Icons.emoji_events,
                  size: 32,
                  color: isFreeRun ? AppColors.warmOrange : AppColors.calmGreen,
                ),
              ),
              const SizedBox(width: 16),
              // Program info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            program.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Distance badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            program.category.distanceLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      program.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                    if (!isFreeRun) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progressValue,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: AppColors.calmGreen,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                    if (isFreeRun) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Tap to start a free run',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.warmOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
