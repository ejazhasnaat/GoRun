import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/feedback_settings_service.dart';

class HeightWeightScreen extends StatefulWidget {
  const HeightWeightScreen({super.key});

  @override
  State<HeightWeightScreen> createState() => _HeightWeightScreenState();
}

class _HeightWeightScreenState extends State<HeightWeightScreen> {
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    final service = Provider.of<FeedbackSettingsService>(context, listen: false);
    final isMetric = service.isMetric;

    _heightController = TextEditingController(
      text: isMetric
          ? service.height.toStringAsFixed(1)
          : _cmToInches(service.height).toStringAsFixed(1),
    );
    _weightController = TextEditingController(
      text: isMetric
          ? service.weight.toStringAsFixed(1)
          : _kgToLbs(service.weight).toStringAsFixed(1),
    );
  }

  double _cmToInches(double cm) => cm / 2.54;
  double _inchesToCm(double inches) => inches * 2.54;

  double _kgToLbs(double kg) => kg * 2.20462;
  double _lbsToKg(double lbs) => lbs / 2.20462;

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    final service = Provider.of<FeedbackSettingsService>(context, listen: false);
    final isMetric = service.isMetric;

    final heightInput = double.tryParse(_heightController.text.trim());
    final weightInput = double.tryParse(_weightController.text.trim());

    if (heightInput != null && weightInput != null) {
      final height = isMetric ? heightInput : _inchesToCm(heightInput);
      final weight = isMetric ? weightInput : _lbsToKg(weightInput);

      service.setHeight(height);
      service.setWeight(weight);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Height and weight saved successfully.")),
      );

      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid numbers.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMetric = Provider.of<FeedbackSettingsService>(context).isMetric;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text("Height / Weight")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  TextField(
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isMetric ? "Height (cm)" : "Height (in)",
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isMetric ? "Weight (kg)" : "Weight (lb)",
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _save(context),
                      child: const Text("Save"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

