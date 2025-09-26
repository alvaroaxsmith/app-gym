import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/workout.dart';
import '../workouts/workout_repository.dart';

enum DashboardRange {
  last30Days,
  last12Weeks,
  thisYear,
}

extension DashboardRangeInfo on DashboardRange {
  String get label {
    switch (this) {
      case DashboardRange.last30Days:
        return 'Últimos 30 dias';
      case DashboardRange.last12Weeks:
        return 'Últimas 12 semanas';
      case DashboardRange.thisYear:
        return 'Este ano';
    }
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardRange _range = DashboardRange.last30Days;
  bool _isLoading = false;
  DashboardData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repository = WorkoutRepository(Supabase.instance.client);
      final (start, end) = _rangeDates();
      final workouts = await repository.fetchWorkoutsBetween(start, end);
      final data = DashboardData.fromWorkouts(workouts, range: _range);
      setState(() {
        _data = data;
      });
    } catch (err) {
      setState(() {
        _error = 'Não foi possível carregar os dados do dashboard.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  (DateTime, DateTime) _rangeDates() {
    final now = DateTime.now();
    switch (_range) {
      case DashboardRange.last30Days:
        return (now.subtract(const Duration(days: 30)), now);
      case DashboardRange.last12Weeks:
        return (now.subtract(const Duration(days: 7 * 12)), now);
      case DashboardRange.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31);
        return (start, end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: DropdownButton<DashboardRange>(
              value: _range,
              onChanged: (range) {
                if (range == null) return;
                setState(() {
                  _range = range;
                });
                _loadData();
              },
              items: DashboardRange.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(child: Text(_error!)),
            )
          else if (_data == null || _data!.series.isEmpty)
            const Expanded(
              child: Center(child: Text('Nenhum dado disponível para o período.')),
            )
          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(child: _buildVolumeChart(context, _data!)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildMusclePie(context, _data!)),
                      ],
                    );
                  }
                  return ListView(
                    children: [
                      SizedBox(height: constraints.maxHeight * 0.45, child: _buildVolumeChart(context, _data!)),
                      const SizedBox(height: 24),
                      SizedBox(height: constraints.maxHeight * 0.45, child: _buildMusclePie(context, _data!)),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVolumeChart(BuildContext context, DashboardData data) {
    final spots = <FlSpot>[];
    for (var i = 0; i < data.series.length; i++) {
      spots.add(FlSpot(i.toDouble(), data.series[i].value));
    }
    final titles = data.series.map((point) => point.label).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Volume total por período', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: Theme.of(context).colorScheme.primary,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 42),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= titles.length) return const SizedBox.shrink();
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 8,
                            child: Text(
                              titles[index],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMusclePie(BuildContext context, DashboardData data) {
    final sections = data.muscleDistribution.entries
        .map(
          (entry) => PieChartSectionData(
            value: entry.value,
            title: '${entry.key}\n${entry.value.toStringAsFixed(0)}kg',
            radius: 80,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        )
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Distribuição por grupo muscular',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 0,
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardData {
  DashboardData({
    required this.series,
    required this.muscleDistribution,
  });

  final List<VolumePoint> series;
  final Map<String, double> muscleDistribution;

  factory DashboardData.fromWorkouts(List<Workout> workouts, {required DashboardRange range}) {
    if (workouts.isEmpty) {
      return DashboardData(series: const [], muscleDistribution: const {});
    }

    workouts.sort((a, b) => a.date.compareTo(b.date));
    final points = <DateTime, double>{};
    final muscleMap = <String, double>{};

    for (final workout in workouts) {
      final bucket = switch (range) {
        DashboardRange.thisYear => DateTime(workout.date.year, workout.date.month, 1),
        _ => _startOfWeek(workout.date),
      };
      points[bucket] = (points[bucket] ?? 0) + workout.totalVolume;
      for (final exercise in workout.exercises) {
        muscleMap[exercise.muscleGroup] =
            (muscleMap[exercise.muscleGroup] ?? 0) + exercise.volume;
      }
    }

    final sortedBuckets = points.keys.toList()..sort();
    final series = sortedBuckets
        .map((bucket) => VolumePoint(
              label: switch (range) {
                DashboardRange.thisYear => DateFormat('MMM').format(bucket),
                _ => DateFormat('dd/MM').format(bucket),
              },
              value: points[bucket] ?? 0,
            ))
        .toList();

    final total = muscleMap.values.fold<double>(0, (acc, value) => acc + value);
    final normalized = total == 0
        ? <String, double>{}
        : {
            for (final entry in muscleMap.entries)
              entry.key: entry.value,
          };

    return DashboardData(series: series, muscleDistribution: normalized);
  }

  static DateTime _startOfWeek(DateTime date) {
    final weekday = date.weekday; // 1 = Monday
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }
}

class VolumePoint {
  const VolumePoint({required this.label, required this.value});

  final String label;
  final double value;
}
