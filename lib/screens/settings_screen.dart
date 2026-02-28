import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/feedback_settings_service.dart';
import '../services/audio_settings_service.dart';
import 'audio_settings_screen.dart';
import 'height_weight_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final feedbackService = Provider.of<FeedbackSettingsService>(context);
    final audioService = Provider.of<AudioSettingsService>(context);
    final audioSettings = audioService.settings;
    final isMetric = feedbackService.isMetric;

    String formatHeight(double cm) {
      return isMetric
          ? "${cm.toStringAsFixed(1)} cm"
          : "${(cm / 2.54).toStringAsFixed(1)} in";
    }

    String formatWeight(double kg) {
      return isMetric
          ? "${kg.toStringAsFixed(1)} kg"
          : "${(kg * 2.20462).toStringAsFixed(1)} lb";
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: SafeArea(
        child: ListView(
        children: [
          _sectionHeader(context, "Appearance"),
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: themeService.isDarkMode,
            onChanged: themeService.toggleTheme,
          ),
          const Divider(),

          _sectionHeader(context, "Audio & Feedback"),
          ListTile(
            leading: const Icon(Icons.volume_up),
            title: const Text("Audio Settings"),
            subtitle: Text(
              audioSettings.enableTTS
                  ? "TTS: ${audioSettings.voice} (${audioSettings.style})"
                  : "TTS: Disabled",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AudioSettingsScreen()),
            ),
          ),
          SwitchListTile(
            title: const Text("Reminders"),
            value: feedbackService.remindersEnabled,
            onChanged: feedbackService.setRemindersEnabled,
          ),
          SwitchListTile(
            title: const Text("Beeps"),
            subtitle: const Text("Play sound at each interval"),
            value: feedbackService.beepsEnabled,
            onChanged: feedbackService.setBeepsEnabled,
          ),
          SwitchListTile(
            title: const Text("Vibrate"),
            subtitle: const Text("Vibrate at each interval"),
            value: feedbackService.vibrateEnabled,
            onChanged: feedbackService.setVibrateEnabled,
          ),
          const Divider(),

          _sectionHeader(context, "Tracking"),
          ListTile(
            title: const Text("Units"),
            subtitle: Text(isMetric ? "Kilometers / Kilograms" : "Miles / Pounds"),
            trailing: const Icon(Icons.swap_horiz),
            onTap: feedbackService.toggleUnits,
          ),
          ListTile(
            leading: const Icon(Icons.height),
            title: const Text("Height / Weight"),
            subtitle: Text(
              "Height: ${formatHeight(feedbackService.height)}, "
              "Weight: ${formatWeight(feedbackService.weight)}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HeightWeightScreen()),
            ),
          ),
          SwitchListTile(
            title: const Text("Disable Sleep"),
            subtitle: const Text("Keep screen always ON"),
            value: feedbackService.disableSleep,
            onChanged: feedbackService.setDisableSleep,
          ),
          const Divider(),

          _sectionHeader(context, "System"),
          ListTile(
            title: const Text("Reset All Workouts"),
            trailing: const Icon(Icons.restore),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Reset Workouts?"),
                  content: const Text(
                      "This will erase your progress. Are you sure?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Reset"),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                // TODO: Implement reset logic
              }
            },
          ),
          ListTile(
            title: const Text("Legal Disclaimer"),
            trailing: const Icon(Icons.info_outline),
            onTap: () {
              // TODO: Show disclaimer
            },
          ),
          ListTile(
            title: const Text("Support & Donations"),
            trailing: const Icon(Icons.favorite),
            onTap: () {
              // TODO: Navigate to donations page
            },
          ),
        ],
      ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
      ),
    );
  }
}

