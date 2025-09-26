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

  String get unitLabel {
    switch (this) {
      case DashboardRange.last30Days:
        return 'dia';
      case DashboardRange.last12Weeks:
        return 'semana';
      case DashboardRange.thisYear:
        return 'mês';
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

  static const Map<String, Color> _muscleGroupColors = {
    'Peito': Color(0xFFE57373),
    'Costas': Color(0xFF4FC3F7),
    'Perna': Color(0xFF81C784),
    'Ombro': Color(0xFFFFB74D),
    'Bíceps': Color(0xFFBA68C8),
    'Tríceps': Color(0xFFFF8A65),
    'Abdômen': Color(0xFFA1887F),
  };

  static const List<Color> _fallbackPieColors = [
    Color(0xFF26C6DA),
    Color(0xFFFFCA28),
    Color(0xFF8D6E63),
    Color(0xFFFF7043),
    Color(0xFFAB47BC),
    Color(0xFF66BB6A),
  ];

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
      final data = DashboardData.fromWorkouts(
        workouts,
        range: _range,
        start: start,
        end: end,
      );
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
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case DashboardRange.last30Days:
        final start = today.subtract(const Duration(days: 29));
        return (start, today);
      case DashboardRange.last12Weeks:
        final end = _startOfWeek(today);
        final start = end.subtract(const Duration(days: 7 * 11));
        return (start, end.add(const Duration(days: 6)));
      case DashboardRange.thisYear:
        final start = DateTime(today.year, 1, 1);
        return (start, today);
    }
  }

  DateTime _startOfWeek(DateTime date) {
    final weekday = date.weekday; // 1 = Monday
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  Widget _buildSummaryMetrics(BuildContext context, DashboardData data) {
    final values =
        data.series.map((point) => point.value).toList(growable: false);
    final total = values.fold<double>(0.0, (acc, value) => acc + value);
    final lastValue = values.isNotEmpty ? values.last : 0.0;
    final average = values.isNotEmpty ? total / values.length : 0.0;

    final List<(String, double)> metrics = switch (_range) {
      DashboardRange.last30Days => [
          ('Último dia', lastValue),
          ('Média diária', average),
          ('Total do período', total),
        ],
      DashboardRange.last12Weeks => [
          ('Última semana', lastValue),
          ('Média semanal', average),
          ('Total das ${values.length} semanas', total),
        ],
      DashboardRange.thisYear => [
          ('Último mês', lastValue),
          ('Média mensal', average),
          ('Total no ano', total),
        ],
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final cards = metrics
            .map(
              (entry) => _MetricCard(
                label: entry.$1,
                value: entry.$2,
                isWide: isWide,
              ),
            )
            .toList();

        if (isWide) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i != 0) const SizedBox(width: 16),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i != 0) const SizedBox(height: 12),
              cards[i],
            ],
          ],
        );
      },
    );
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
              child:
                  Center(child: Text('Nenhum dado disponível para o período.')),
            )
          else
            Expanded(
              child: Column(
                children: [
                  _buildSummaryMetrics(context, _data!),
                  const SizedBox(height: 16),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 900;
                        if (isWide) {
                          final height = constraints.maxHeight;
                          return Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildVolumeChart(
                                  context,
                                  _data!,
                                  height: height,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 2,
                                child: _buildMusclePie(
                                  context,
                                  _data!,
                                  height: height,
                                ),
                              ),
                            ],
                          );
                        }
                        const chartHeight = 240.0;
                        const pieHeight = 260.0;
                        return ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            _buildVolumeChart(context, _data!,
                                height: chartHeight),
                            const SizedBox(height: 16),
                            _buildMusclePie(context, _data!, height: pieHeight),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVolumeChart(
    BuildContext context,
    DashboardData data, {
    required double height,
  }) {
    final spots = <FlSpot>[];
    for (var i = 0; i < data.series.length; i++) {
      spots.add(FlSpot(i.toDouble(), data.series[i].value));
    }

    final titles = data.series.map((point) => point.label).toList();
    final isCompact = MediaQuery.of(context).size.width < 420;
    final desiredLabels = isCompact ? 4 : 7;
    final step = titles.isEmpty
        ? 1
        : (titles.length / desiredLabels).ceil().clamp(1, titles.length);
    final labelStyle = TextStyle(fontSize: isCompact ? 9 : 10);
    final leftReserved = isCompact ? 36.0 : 42.0;
    final barWidth = isCompact ? 2.5 : 3.0;

    return SizedBox(
      height: height,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Volume total por ${_range.unitLabel}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        barWidth: barWidth,
                        color: Theme.of(context).colorScheme.primary,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: leftReserved,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= titles.length) {
                              return const SizedBox.shrink();
                            }

                            final shouldShow =
                                index == titles.length - 1 || index % step == 0;
                            if (!shouldShow) {
                              return const SizedBox.shrink();
                            }

                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 8,
                              child: Text(
                                titles[index],
                                style: labelStyle,
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: const FlGridData(show: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMusclePie(
    BuildContext context,
    DashboardData data, {
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompactWidth = constraints.maxWidth < 360;
          final radius = isCompactWidth ? 52.0 : 80.0;
          final titleStyle = TextStyle(
            fontSize: isCompactWidth ? 10 : 12,
            fontWeight: FontWeight.w600,
          );

          final entries = data.muscleDistribution.entries.toList();
          final sections = <PieChartSectionData>[];
          for (var i = 0; i < entries.length; i++) {
            final entry = entries[i];
            final baseColor = _muscleGroupColors[entry.key] ??
                _fallbackPieColors[i % _fallbackPieColors.length];
            final sectionColor =
                isCompactWidth ? baseColor.withValues(alpha: 0.9) : baseColor;
            sections.add(
              PieChartSectionData(
                value: entry.value,
                title: '${entry.key}\n${entry.value.toStringAsFixed(0)}kg',
                radius: radius,
                color: sectionColor,
                titleStyle: titleStyle,
              ),
            );
          }

          final cardPadding = isCompactWidth
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
              : const EdgeInsets.all(16);
          final headerSpacing = isCompactWidth ? 8.0 : 12.0;

          return Card(
            child: Padding(
              padding: cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Distribuição por grupo muscular',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: headerSpacing),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: isCompactWidth ? 1 : 1.2,
                      child: PieChart(
                        PieChartData(
                          sections: sections,
                          sectionsSpace: isCompactWidth ? 1 : 2,
                          centerSpaceRadius: isCompactWidth ? 28 : 0,
                          borderData: FlBorderData(show: false),
                        ),
                      ),
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
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.isWide,
  });

  final String label;
  final double value;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = NumberFormat.decimalPattern('pt_BR');
    final formattedValue = formatter.format(value.round());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '$formattedValue kg',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!isWide) const SizedBox(height: 4),
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

  factory DashboardData.fromWorkouts(
    List<Workout> workouts, {
    required DashboardRange range,
    required DateTime start,
    required DateTime end,
  }) {
    if (workouts.isEmpty) {
      return DashboardData(
        series: const [],
        muscleDistribution: const {},
      );
    }

    workouts.sort((a, b) => a.date.compareTo(b.date));

    final dailyTotals = <DateTime, double>{};
    final weeklyTotals = <DateTime, double>{};
    final monthlyTotals = <DateTime, double>{};
    final muscleMap = <String, double>{};

    for (final workout in workouts) {
      final dayKey =
          DateTime(workout.date.year, workout.date.month, workout.date.day);
      final weekKey = _startOfWeek(workout.date);
      final monthKey = DateTime(workout.date.year, workout.date.month, 1);

      dailyTotals[dayKey] = (dailyTotals[dayKey] ?? 0) + workout.totalVolume;
      weeklyTotals[weekKey] =
          (weeklyTotals[weekKey] ?? 0) + workout.totalVolume;
      monthlyTotals[monthKey] =
          (monthlyTotals[monthKey] ?? 0) + workout.totalVolume;

      for (final exercise in workout.exercises) {
        muscleMap[exercise.muscleGroup] =
            (muscleMap[exercise.muscleGroup] ?? 0) + exercise.volume;
      }
    }

    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);

    final series = switch (range) {
      DashboardRange.last30Days =>
        _buildDailySeries(dailyTotals, normalizedStart, normalizedEnd),
      DashboardRange.last12Weeks =>
        _buildWeeklySeries(weeklyTotals, normalizedStart, normalizedEnd),
      DashboardRange.thisYear =>
        _buildMonthlySeries(monthlyTotals, normalizedStart, normalizedEnd),
    };

    final totalMuscleVolume =
        muscleMap.values.fold<double>(0, (acc, value) => acc + value);
    final normalizedMuscleMap = totalMuscleVolume == 0
        ? <String, double>{}
        : {
            for (final entry in muscleMap.entries) entry.key: entry.value,
          };

    return DashboardData(
      series: series,
      muscleDistribution: normalizedMuscleMap,
    );
  }

  static List<VolumePoint> _buildDailySeries(
    Map<DateTime, double> dailyTotals,
    DateTime start,
    DateTime end,
  ) {
    final series = <VolumePoint>[];
    for (var date = start;
        !date.isAfter(end);
        date = date.add(const Duration(days: 1))) {
      final key = DateTime(date.year, date.month, date.day);
      series.add(
        VolumePoint(
          label: DateFormat('dd/MM').format(date),
          value: dailyTotals[key] ?? 0,
        ),
      );
    }
    return series;
  }

  static List<VolumePoint> _buildMonthlySeries(
    Map<DateTime, double> monthlyTotals,
    DateTime start,
    DateTime end,
  ) {
    final series = <VolumePoint>[];
    var cursor = DateTime(start.year, start.month, 1);
    final limit = DateTime(end.year, end.month, 1);
    while (!cursor.isAfter(limit)) {
      series.add(
        VolumePoint(
          label: DateFormat('MMM/yy').format(cursor),
          value: monthlyTotals[cursor] ?? 0,
        ),
      );
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return series;
  }

  static List<VolumePoint> _buildWeeklySeries(
    Map<DateTime, double> weeklyTotals,
    DateTime start,
    DateTime end,
  ) {
    final series = <VolumePoint>[];
    var cursor = _startOfWeek(start);
    final limit = _startOfWeek(end);
    while (!cursor.isAfter(limit)) {
      final label = DateFormat('dd/MM').format(cursor);
      series.add(
        VolumePoint(
          label: label,
          value: weeklyTotals[cursor] ?? 0,
        ),
      );
      cursor = cursor.add(const Duration(days: 7));
    }
    return series;
  }

  static DateTime _startOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }
}

class VolumePoint {
  const VolumePoint({required this.label, required this.value});

  final String label;
  final double value;
}
