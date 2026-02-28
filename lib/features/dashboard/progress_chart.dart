import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ProgressChart extends StatelessWidget {
  const ProgressChart({super.key});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            gradient: LinearGradient(
              colors: [
                AppColors.calmGreen,
                AppColors.warmOrange,
                AppColors.oceanicTeal,
              ],
            ),
            spots: const [
              FlSpot(0, 1),
              FlSpot(1, 1.5),
              FlSpot(2, 2),
              FlSpot(3, 3),
              FlSpot(4, 5),
            ],
            isCurved: true,
            dotData: const FlDotData(show: true),
          )
        ],
      ),
    );
  }
}
