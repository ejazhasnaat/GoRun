import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_settings_service.dart';
import '../models/audio_settings_model.dart';
import '../audio/audio_playback_engine.dart';

class AudioSettingsScreen extends StatefulWidget {
  const AudioSettingsScreen({super.key});

  @override
  State<AudioSettingsScreen> createState() => _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends State<AudioSettingsScreen> {
  late AudioPlaybackEngine _audioEngine;

  static const List<String> voiceOptions = [
    'US Female',
    'US Male',
    'UK Female',
    'UK Male',
    'IN Female',
    'IN Male',
  ];

  static const List<String> styleOptions = ['Calm', 'Energetic', 'Neutral'];

  @override
  void initState() {
    super.initState();
    final settings = context.read<AudioSettingsService>().settings;
    _audioEngine = AudioPlaybackEngine(settings);
  }

  @override
  void dispose() {
    _audioEngine.dispose();
    super.dispose();
  }

  Future<void> _updateAndPreview({
    String? voice,
    String? style,
    double? volume,
    bool preview = true,
  }) async {
    final service = context.read<AudioSettingsService>();

    await service.update(voice: voice, style: style, cueVolume: volume);

    await _audioEngine.reloadSettings(service.settings);

    if (preview && service.settings.enableTTS) {
      await _audioEngine.speak(
        "This is a ${service.settings.style} preview using ${service.settings.voice}.",
      );
    }

    if (mounted) setState(() {});
  }

  Future<void> _updateCueSetting(Future<void> Function() updateFunction) async {
    await updateFunction();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final audioService = context.watch<AudioSettingsService>();
    final settings = audioService.settings;

    return Scaffold(
      appBar: AppBar(title: const Text("Audio Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // TTS Master Toggle
          Card(
            child: SwitchListTile(
              title: const Text("Enable Text-to-Speech (TTS)"),
              subtitle: Text(
                settings.enableTTS
                    ? "Voice announcements are enabled"
                    : "Voice announcements are disabled",
              ),
              value: settings.enableTTS,
              onChanged: (value) async {
                await audioService.update(enableTTS: value);
                await _audioEngine.reloadSettings(audioService.settings);
                if (mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(height: 16),

          if (settings.enableTTS) ...[
            _sectionHeader("Voice Settings"),
            _buildDropdownTile(
              label: "Voice",
              value: settings.voice,
              options: voiceOptions,
              icon: Icons.record_voice_over,
              onChanged: (value) {
                if (value != null && value != settings.voice) {
                  _updateAndPreview(voice: value);
                }
              },
            ),
            _buildDropdownTile(
              label: "Motivational Style",
              value: settings.style,
              options: styleOptions,
              icon: Icons.mood,
              onChanged: (value) {
                if (value != null && value != settings.style) {
                  _updateAndPreview(style: value);
                }
              },
            ),
            const SizedBox(height: 16),

            _sectionHeader("Volume Control"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildVolumeSlider(settings),
              ),
            ),
            const SizedBox(height: 16),

            _sectionHeader("Test Current Settings"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildOverallSettingsTester(settings),
              ),
            ),
            const SizedBox(height: 16),

            _sectionHeader("Audio Cue Settings"),
            _buildCueToggle(
              "Halfway Cue",
              "Announce halfway point of the workout",
              settings.enableHalfwayCue,
              (v) => _updateCueSetting(
                () => audioService.update(enableHalfwayCue: v),
              ),
            ),
            _buildCueToggle(
              "Countdown Cue",
              "Count down last 5 seconds of each interval",
              settings.enableCountdownCue,
              (v) => _updateCueSetting(
                () => audioService.update(enableCountdownCue: v),
              ),
            ),
          ] else
            _buildTTSDisabledMessage(),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDropdownTile({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    IconData? icon,
  }) {
    return Card(
      child: ListTile(
        leading: icon != null ? Icon(icon) : null,
        title: Text(label),
        subtitle: Text("Current: $value"),
        trailing: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          underline: const SizedBox(),
          items: options.map((opt) {
            return DropdownMenuItem<String>(value: opt, child: Text(opt));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildVolumeSlider(AudioSettingsModel settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.volume_up),
            const SizedBox(width: 8),
            const Text(
              "Cue Volume",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text("${(settings.cueVolume * 100).round()}%"),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(trackHeight: 4.0),
          child: Slider(
            value: settings.cueVolume,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            label: "${(settings.cueVolume * 100).round()}%",
            onChanged: (value) {
              _updateAndPreview(volume: value, preview: false);
            },
            onChangeEnd: (value) {
              _updateAndPreview(volume: value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOverallSettingsTester(AudioSettingsModel settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.play_circle_outline),
            SizedBox(width: 8),
            Text(
              "Test Overall Settings",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "Current Configuration:",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.record_voice_over, size: 16),
                  const SizedBox(width: 8),
                  Text("Voice: ${settings.voice}"),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.mood, size: 16),
                  const SizedBox(width: 8),
                  Text("Style: ${settings.style}"),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.volume_up, size: 16),
                  const SizedBox(width: 8),
                  Text("Volume: ${(settings.cueVolume * 100).round()}%"),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _audioEngine.speak(
                    "Testing current audio settings. Voice: ${settings.voice}, Style: ${settings.style}, Volume: ${(settings.cueVolume * 100).round()} percent.",
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text("Test Settings"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _audioEngine.speak(
                    "This is a sample workout announcement. Great job! Keep up the excellent work. You're doing amazing!",
                  );
                },
                icon: const Icon(Icons.fitness_center),
                label: const Text("Test Workout Cue"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCueToggle(
    String label,
    String subtitle,
    bool value,
    Future<void> Function(bool) onChanged,
  ) {
    return Card(
      child: SwitchListTile(
        title: Text(label),
        subtitle: Text(subtitle),
        value: value,
        onChanged: (val) async {
          await onChanged(val);
        },
      ),
    );
  }

  Widget _buildTTSDisabledMessage() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(Icons.volume_off, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              "Text-to-Speech is disabled",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              "Enable TTS above to configure voice settings and audio cues",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
