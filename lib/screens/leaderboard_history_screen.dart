import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/run_data.dart';
import '../screens/run_summary_screen.dart';

enum MetricType { distance, duration, pace, calories }

class LeaderboardHistoryScreen extends StatefulWidget {
  const LeaderboardHistoryScreen({super.key});

  @override
  State<LeaderboardHistoryScreen> createState() => _LeaderboardHistoryScreenState();
}

class _LeaderboardHistoryScreenState extends State<LeaderboardHistoryScreen> {
  List<RunData> _runHistory = [];
  MetricType _selectedMetric = MetricType.distance;
  bool _sortDescending = true;
  int? _tappedIndex;

  @override
  void initState() {
    super.initState();
    _loadRunHistory();
  }

  Future<void> _loadRunHistory() async {
    final box = await Hive.openBox<RunData>('run_history');
    final runs = box.values.toList();
    _sortRunData(runs);
  }

  void _sortRunData(List<RunData> runs) {
    runs.sort((a, b) => _sortDescending
        ? b.startTime.compareTo(a.startTime)
        : a.startTime.compareTo(b.startTime));
    setState(() {
      _runHistory = runs;
    });
  }

  void _navigateToSummary(RunData run) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RunSummaryScreen(run: run)),
    );
  }

  double _getMetricValue(RunData run) {
    switch (_selectedMetric) {
      case MetricType.distance:
        return run.distanceMeters / 1000;
      case MetricType.duration:
        return run.durationSeconds / 60;
      case MetricType.pace:
        return run.paceMinPerKm;
      case MetricType.calories:
        return run.calories;
    }
  }

  String _metricLabel(double value) {
    switch (_selectedMetric) {
      case MetricType.distance:
        return "${value.toStringAsFixed(2)} km";
      case MetricType.duration:
        return "${value.toStringAsFixed(1)} min";
      case MetricType.pace:
        return "${value.toStringAsFixed(1)} min/km";
      case MetricType.calories:
        return "${value.toStringAsFixed(0)} kcal";
    }
  }

  List<BarChartGroupData> _buildBarChartGroups() {
    return _runHistory.asMap().entries.map((entry) {
      final index = entry.key;
      final value = _getMetricValue(entry.value);
      final isSelected = index == _tappedIndex;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: isSelected ? Colors.deepOrange : Colors.teal,
            width: 14,
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: BackgroundBarChartRodData(show: false),
          ),
        ],
        showingTooltipIndicators: [0],
      );
    }).toList();
  }

  Widget _bottomTitles(double value, TitleMeta meta) {
    if (value.toInt() >= _runHistory.length) return const SizedBox.shrink();
    final run = _runHistory[value.toInt()];
    final label = DateFormat('MM/dd').format(run.startTime);
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 6,
      child: Text(label, style: const TextStyle(fontSize: 10)),
    );
  }

  Widget _leftTitles(double value, TitleMeta meta) {
    return Text(_metricLabel(value), style: const TextStyle(fontSize: 10));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Run History"),
        actions: [
          PopupMenuButton<MetricType>(
            icon: const Icon(Icons.bar_chart),
            onSelected: (metric) => setState(() => _selectedMetric = metric),
            itemBuilder: (context) => MetricType.values.map((metric) {
              return PopupMenuItem(
                value: metric,
                child: Text(metric.name.toUpperCase()),
              );
            }).toList(),
          ),
          IconButton(
            icon: Icon(_sortDescending ? Icons.arrow_downward : Icons.arrow_upward),
            tooltip: "Toggle Sort Order",
            onPressed: () {
              _sortDescending = !_sortDescending;
              _sortRunData(List.from(_runHistory));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _runHistory.isEmpty
          ? const Center(child: Text("No run history yet."))
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Text(
                    "Run ${_selectedMetric.name.capitalize()} Overview",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  AspectRatio(
                    aspectRatio: 1.7,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: BarChart(
                        BarChartData(
                          barGroups: _buildBarChartGroups(),
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchCallback: (event, response) {
                              if (!event.isInterestedForInteractions || response == null) return;
                              setState(() {
                                _tappedIndex = response.spot?.touchedBarGroupIndex;
                              });
                            },
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor: Colors.black87,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final run = _runHistory[group.x.toInt()];
                                final value = _getMetricValue(run);
                                return BarTooltipItem(
                                  _metricLabel(value),
                                  const TextStyle(color: Colors.white),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: _leftTitles,
                                reservedSize: (MediaQuery.of(context).size.width * 0.12).clamp(32, 44),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: _bottomTitles,
                              ),
                            ),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(show: true),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: _runHistory.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final run = _runHistory[index];
                      return ListTile(
                        title: Text(DateFormat('yyyy-MM-dd – kk:mm').format(run.startTime)),
                        subtitle: Text(
                          "Distance: ${run.formattedDistance} • Duration: ${run.formattedDuration} • Pace: ${run.formattedPace}",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _navigateToSummary(run),
                      );
                    },
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

extension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1)}";
}

