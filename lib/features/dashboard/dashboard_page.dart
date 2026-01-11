import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui_helpers.dart'; // Add this import
import '../../models/workout.dart';
import '../workouts/workout_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

enum DashboardPeriod {
  month,
  threeMonths,
  sixMonths,
  year;

  String get label {
    switch (this) {
      case DashboardPeriod.month:
        return '1 Mês';
      case DashboardPeriod.threeMonths:
        return '3 Meses';
      case DashboardPeriod.sixMonths:
        return '6 Meses';
      case DashboardPeriod.year:
        return '1 Ano';
    }
  }

  int get days {
    switch (this) {
      case DashboardPeriod.month:
        return 30;
      case DashboardPeriod.threeMonths:
        return 90;
      case DashboardPeriod.sixMonths:
        return 180;
      case DashboardPeriod.year:
        return 365;
    }
  }
}

enum DashboardMetric {
  volume,
  sets,
  load, // Progressão de Carga
  oneRM; // Estimativa de 1RM

  String get label {
    switch (this) {
      case DashboardMetric.volume:
        return 'Volume (kg)';
      case DashboardMetric.sets:
        return 'Séries Semanais';
      case DashboardMetric.load:
        return 'Carga Máxima';
      case DashboardMetric.oneRM:
        return 'Estimativa 1RM';
    }
  }
}

enum ChartMode {
  absolute,
  percentage;

  String get label {
    switch (this) {
      case ChartMode.absolute:
        return 'Absoluto';
      case ChartMode.percentage:
        return 'Evolução %';
    }
  }
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  List<Workout> _workouts = []; // Treinos dentro do periodo selecionado

  // Estado dos Filtros
  DashboardPeriod _period = DashboardPeriod.month;
  String? _selectedMuscleGroup; // null = Todos
  DashboardMetric _metric = DashboardMetric.volume;
  String? _selectedExercise; // Obrigatório se metric == load
  ChartMode _chartMode = ChartMode.absolute;
  bool _onlyHardSets = false; // Contar apenas séries com RPE >= 7

  // Cache de opções
  List<String> _availableMuscleGroups = [];
  List<String> _availableExercises = [];

  final _muscleColors = <String, Color>{
    'Peito': const Color(0xFFE57373),
    'Costas': const Color(0xFF4FC3F7),
    'Perna': const Color(0xFF81C784),
    'Ombro': const Color(0xFFFFB74D),
    'Bíceps': const Color(0xFFBA68C8),
    'Tríceps': const Color(0xFFFF8A65),
    'Abdômen': const Color(0xFFA1887F),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repository = WorkoutRepository(Supabase.instance.client);
      final now = DateTime.now();
      final start = now.subtract(Duration(days: _period.days));
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Busca treinos do período
      final data = await repository.fetchWorkoutsBetween(start, end);
      
      // Ordena por data
      data.sort((a, b) => a.date.compareTo(b.date));

      if (mounted) {
        setState(() {
          _workouts = data;
          _isLoading = false;
          _updateFilterOptions();
          
          // Auto-select exercise if needed and none selected or invalid
          if (_selectedExercise != null && !_availableExercises.contains(_selectedExercise)) {
             _selectedExercise = null;
          }
          if (_metric == DashboardMetric.load && _selectedExercise == null && _availableExercises.isNotEmpty) {
            _selectedExercise = _availableExercises.first; // Pode melhorar a heurística (ex: mais frequente)
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    }
  }

  void _updateFilterOptions() {
    // Extrai grupos musculares dos treinos carregados
    final muscleGroups = <String>{};
    final allExercises = <String>{};

    for (final w in _workouts) {
      for (final e in w.exercises) {
        muscleGroups.add(e.muscleGroup);
        // Filtragem de exercícios dependente do grupo muscular selecionado
        if (_selectedMuscleGroup == null || e.muscleGroup == _selectedMuscleGroup) {
          allExercises.add(e.name);
        }
      }
    }

    _availableMuscleGroups = muscleGroups.toList()..sort();
    _availableExercises = allExercises.toList()..sort();
  }

  void _onPeriodChanged(DashboardPeriod? p) {
    if (p != null && p != _period) {
      setState(() => _period = p);
      _loadData();
    }
  }

  void _onMuscleGroupChanged(String? group) {
    setState(() {
      _selectedMuscleGroup = group;
      _selectedExercise = null; // Reset exercise selection
      _updateFilterOptions();
      
      // Se estiver em modo Carga, tenta selecionar o primeiro
      if (_metric == DashboardMetric.load && _availableExercises.isNotEmpty) {
        _selectedExercise = _availableExercises.first;
      }
    });
  }
  
  // Função auxiliar para analisar frequência
  Widget _buildMuscleGroupDistroOrFrequency() {
      // Se estamos fitrando por grupo muscular, mostrar Frequência
      if (_selectedMuscleGroup != null) {
          int weeks = _period.days ~/ 7;
          if (weeks < 1) weeks = 1;
          
          // Contar dias únicos de treino para esse músculo
          final uniqueDays = <String>{};
          for (final w in _workouts) {
              final hasMuscle = w.exercises.any((e) => e.muscleGroup == _selectedMuscleGroup);
              if (hasMuscle) {
                  uniqueDays.add(DateFormat('yyyy-MM-dd').format(w.date));
              }
          }
          
          final freq = uniqueDays.length / weeks;
          
          Color freqColor = Colors.orange;
          String status = 'Baixa';
          if (freq >= 2 && freq <= 4) {
             freqColor = Colors.green;
             status = 'Ideal (2-4x)';
          } else if (freq > 4) {
             freqColor = Colors.red;
             status = 'Alta (Risco)';
          } else if (freq < 1) {
             status = 'Muito Baixa';
          } else {
             status = 'Moderada';
             freqColor = Colors.blue;
          }

          return Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text('Frequência de Treino: $_selectedMuscleGroup', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                  Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                          Text(
                                              '${freq.toStringAsFixed(1)}x / semana', 
                                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
                                          ),
                                          Text(
                                              status, 
                                              style: TextStyle(color: freqColor, fontWeight: FontWeight.bold)
                                          ),
                                      ],
                                  ),
                                  Icon(Icons.calendar_month, size: 48, color: freqColor.withOpacity(0.5)),
                              ],
                          ),
                          const SizedBox(height: 8),
                          const Text('Recomendação: 2 a 4 vezes por semana para otimizar hipertrofia.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ]
                  )
              )
          );
      } else {
          return _buildSecondaryStats();
      }
  }

  // ...existing code...

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cockpit de Performance'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Visão Geral', icon: Icon(Icons.dashboard)),
              Tab(text: 'Progresso', icon: Icon(Icons.show_chart)),
              Tab(text: 'Recuperação', icon: Icon(Icons.battery_charging_full)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCockpitTab(),
            _buildProgressTab(),
            _buildRecoveryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCockpitTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildReadinessWidget(),
        const SizedBox(height: 24),
        Row(
          children: [
            Text('Barômetro de Volume Semanal', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: 8),
            const GlossaryButton(termKey: 'volume_landmarks'),
          ],
        ),
        const SizedBox(height: 8),
        _buildVolumeBarometer(),
        const SizedBox(height: 24),
        _buildQuickAlerts(),
      ],
    );
  }

  Widget _buildProgressTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFilters(),
        const SizedBox(height: 16),
        _buildMetricSelector(),
        if (_metric == DashboardMetric.load || _metric == DashboardMetric.oneRM) ...[
          const SizedBox(height: 16),
          _buildExerciseSelector(),
        ],
        if (_metric == DashboardMetric.sets) ...[
           SwitchListTile(
             title: Row(
               children: [
                 const Text('Apenas "Hard Sets" (RPE ≥ 7)'),
                 const SizedBox(width: 8),
                 GlossaryButton(termKey: 'hard_sets', size: 18),
               ],
             ),
             subtitle: const Text('Ignora séries de aquecimento'),
             value: _onlyHardSets,
             onChanged: (val) => setState(() => _onlyHardSets = val),
           ),
        ],
        const SizedBox(height: 16),
        _buildStatsCards(),
        const SizedBox(height: 24),
        _buildMainChart(),
        const SizedBox(height: 16),
        _buildChartModeToggle(),
        const SizedBox(height: 32),
        _buildMuscleGroupDistroOrFrequency(),
      ],
    );
  }

  Widget _buildRecoveryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFatigueChecklist(),
        const SizedBox(height: 24),
        _buildDeloadRecommendation(),
      ],
    );
  }

  Widget _buildReadinessWidget() {
    // Mock de Prontidão (Idealmente viria de input do usuário ou wearables)
    // Calculo simples baseado em dias sem treino (exemplo)
    final lastWorkout = _workouts.isNotEmpty ? _workouts.last.date : DateTime.now().subtract(const Duration(days: 7));
    final hoursSinceLast = DateTime.now().difference(lastWorkout).inHours;
    
    double readiness = 1.0;
    String status = 'Excelente';
    Color color = Colors.green;

    if (hoursSinceLast < 12) {
      readiness = 0.4;
      status = 'Baixa (Recuperando)';
      color = Colors.red;
    } else if (hoursSinceLast < 24) {
      readiness = 0.7;
      status = 'Moderada';
      color = Colors.orange;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              height: 80,
              width: 80,
              child: Stack(
                children: [
                  Center(child: CircularProgressIndicator(value: readiness, strokeWidth: 8, color: color, backgroundColor: color.withOpacity(0.2))),
                  Center(child: Text('${(readiness * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Prontidão Diária', style: Theme.of(context).textTheme.titleMedium),
                  Text(status, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Baseado no descanso desde o último treino.', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeBarometer() {
    // Calcula sets dos últimos 7 dias
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    final sets = <String, double>{};
    
    for (final w in _workouts) {
       if (w.date.isAfter(start)) {
          for (final e in w.exercises) {
             sets[e.muscleGroup] = (sets[e.muscleGroup] ?? 0) + e.sets;
          }
       }
    }

    final sorted = sets.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    
    return Column(
      children: sorted.map((e) {
        final val = e.value;
        Color color = Colors.grey;
        String zone = '';
        
        // Landmarks de Mike Israetel (Aprox)
        if (val < 6) { zone = 'Manutenção (MV)'; color = Colors.blue; }
        else if (val < 12) { zone = 'Mín. Efetivo (MEV)'; color = Colors.yellow.shade700; }
        else if (val <= 20) { zone = 'Adaptativo Máx (MAV)'; color = Colors.green; }
        else { zone = 'Risco Over. (MRV)'; color = Colors.red; }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${val.toInt()} séries ($zone)', style: TextStyle(fontSize: 12, color: color)),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (val / 30).clamp(0.0, 1.0), // Escala até 30 sets
                color: color,
                backgroundColor: Colors.grey.shade200,
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('0', style: TextStyle(fontSize: 10)),
                  Text('10 (MEV)', style: TextStyle(fontSize: 10)),
                  Text('20 (MRV)', style: TextStyle(fontSize: 10)),
                  Text('30+', style: TextStyle(fontSize: 10)),
                ],
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickAlerts() {
    // Verifica se MRV excedido
    final sets = _getWeeklySetsByMuscle();
    final overtrained = sets.entries.where((e) => e.value > 20).toList();

    if (overtrained.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text('Alerta de Volume', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))]),
            const SizedBox(height: 8),
            Text('Você excedeu o MRV (20 séries) para: ${overtrained.map((e) => e.key).join(", ")}. Considere reduzir o volume ou iniciar um Deload.'),
          ],
        ),
      ),
    );
  }

  Map<String, double> _getWeeklySetsByMuscle() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    final sets = <String, double>{};
    for (final w in _workouts) {
       if (w.date.isAfter(start)) {
          for (final e in w.exercises) {
             sets[e.muscleGroup] = (sets[e.muscleGroup] ?? 0) + e.sets;
          }
       }
    }
    return sets;
  }

  Widget _buildFatigueChecklist() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Check-in de Recuperação'),
            subtitle: const Text('Monitore sinais de Overtraining'),
            trailing: const GlossaryButton(termKey: 'recovery'),
          ),
          const Divider(),
          _ChecklistItem(title: 'Qualidade do Sono Ruim?', icon: Icons.bed),
          _ChecklistItem(title: 'Dores Articulares Persistentes?', icon: Icons.accessibility_new),
          _ChecklistItem(title: 'Irritabilidade ou Mau Humor?', icon: Icons.sentiment_dissatisfied),
          _ChecklistItem(title: 'Queda de Performance > 2 semanas?', icon: Icons.trending_down),
        ],
      ),
    );
  }

  Widget _buildDeloadRecommendation() {
     return Card(
       color: Colors.blue.shade50,
       child: Padding(
         padding: const EdgeInsets.all(16),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text('Recomendação de Deload', style: Theme.of(context).textTheme.titleMedium),
             const SizedBox(height: 8),
             const Text('Se você marcou 2 ou mais itens acima, ou se seu progresso estagnou nas últimas semanas, considere uma semana de Deload:'),
             const SizedBox(height: 8),
             const Text('• Reduza volume em 50%\n• Reduza carga em 10-20%\n• Foque em técnica e recuperação'),
           ],
         ),
       ),
     );
  }



  Widget _buildFilters() {
    return Row(
      children: [
        // Filtro de Período
        Expanded(
          child: DropdownButtonFormField<DashboardPeriod>(
            decoration: const InputDecoration(
              labelText: 'Período',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            ),
            value: _period,
            items: DashboardPeriod.values.map((p) {
              return DropdownMenuItem(value: p, child: Text(p.label));
            }).toList(),
            onChanged: _onPeriodChanged,
          ),
        ),
        const SizedBox(width: 16),
        // Filtro de Grupo Muscular
        Expanded(
          child: DropdownButtonFormField<String?>(
            decoration: const InputDecoration(
              labelText: 'Grupo Muscular',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            ),
            value: (_selectedMuscleGroup != null && _availableMuscleGroups.contains(_selectedMuscleGroup)) 
                ? _selectedMuscleGroup 
                : null,
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              ..._availableMuscleGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))),
            ],
            onChanged: _onMuscleGroupChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<DashboardMetric>(
        segments: DashboardMetric.values.map((m) {
          return ButtonSegment(value: m, label: Text(m.label));
        }).toList(),
        selected: {_metric},
        onSelectionChanged: (s) => setState(() => _metric = s.first),
      ),
    );
  }

  Widget _buildExerciseSelector() {
    if (_availableExercises.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nenhum exercício encontrado para este filtro.'),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Selecione o Exercício',
        border: OutlineInputBorder(),
        helperText: 'Necessário para análise de carga',
      ),
      value: (_selectedExercise != null && _availableExercises.contains(_selectedExercise))
          ? _selectedExercise
          : null,
      items: _availableExercises.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (val) {
        if (val != null) setState(() => _selectedExercise = val);
      },
    );
  }

  Widget _buildChartModeToggle() {
    return Center(
      child: SegmentedButton<ChartMode>(
        segments: ChartMode.values.map((m) => ButtonSegment(value: m, label: Text(m.label))).toList(),
        selected: {_chartMode},
        onSelectionChanged: (s) => setState(() => _chartMode = s.first),
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  // --- Lógica de Dados para Gráficos e Stats ---

  Map<DateTime, double> _getChartData() {
    final data = <DateTime, double>{};

    if (_metric == DashboardMetric.volume) {
      // Agrega volume por dia
      for (final w in _workouts) {
        final date = DateTime(w.date.year, w.date.month, w.date.day);
        
        double dailyVolume = 0;
        for (final e in w.exercises) {
          if (_selectedMuscleGroup == null || e.muscleGroup == _selectedMuscleGroup) {
            dailyVolume += e.volume;
          }
        }
        
        if (dailyVolume > 0) {
          data[date] = (data[date] ?? 0) + dailyVolume;
        }
      }
    } else if (_metric == DashboardMetric.sets) {
       for (final w in _workouts) {
        final date = DateTime(w.date.year, w.date.month, w.date.day);
        // Janela de 7 dias para Volume Semanal
        final windowStart = w.date.subtract(const Duration(days: 6));
        final windowEnd = w.date.add(const Duration(seconds: 1));
        
        double weeklySets = 0;
        
        for (final otherW in _workouts) {
            if (otherW.date.isAfter(windowStart) && otherW.date.isBefore(windowEnd)) {
                 for (final e in otherW.exercises) {
                    if (_selectedMuscleGroup == null || e.muscleGroup == _selectedMuscleGroup) {
                       // Filtro de Hard Sets (RPE >= 7 ou null se assumirmos que dados antigos são válidos)
                       // Lógica: Se _onlyHardSets é true, checa RPE. 
                       // Se RPE for null, consideramos Hard Set apenas se não quisermos ser muito estritos, 
                       // ou podemos considerar que sem RPE não é Hard Set.
                       // Para facilitar: Se RPE >= 7 OR RPE is null (legacy data might be hard sets)
                       bool isHardSet = (e.rpe == null || e.rpe! >= 7);
                       
                       if (!_onlyHardSets || isHardSet) {
                          weeklySets += e.sets;
                       }
                    }
                 }
            }
        }
        
        if (weeklySets > 0) {
            data[date] = weeklySets;
        }
      }
    } else if ((_metric == DashboardMetric.load || _metric == DashboardMetric.oneRM) && _selectedExercise != null) {
      // Agrega carga ou 1RM
      for (final w in _workouts) {
         final pertinentExercises = w.exercises.where((e) => e.name == _selectedExercise);
         if (pertinentExercises.isNotEmpty) {
            double value = 0.0; // Max value found for the day
            
            for (final e in pertinentExercises) {
                double val = 0;
                if (_metric == DashboardMetric.load) {
                    val = e.weightKg;
                } else {
                    // Epley Formula: 1RM = w * (1 + r/30)
                    // Usar repsCount
                    val = e.weightKg * (1 + (e.repsAsNumber / 30));
                }
                
               if (val > value) value = val;
            }
            
            final date = DateTime(w.date.year, w.date.month, w.date.day);
            final currentMax = data[date] ?? 0;
            if (value > currentMax) {
              data[date] = value;
            }
         }
      }
    }

    return data;
  }

  Widget _buildStatsCards() {
    final data = _getChartData();
    if (data.isEmpty) return const SizedBox.shrink();

    final sortedDates = data.keys.toList()..sort();
    final firstValue = data[sortedDates.first]!;
    final lastValue = data[sortedDates.last]!;
    
    // Total ou Máximo Atual dependendo da métrica
    String mainValueStr = '';
    String label = '';
    
    if (_metric == DashboardMetric.volume) {
      final totalVolume = data.values.fold(0.0, (sum, val) => sum + val);
      mainValueStr = '${(totalVolume / 1000).toStringAsFixed(1)}t';
      label = 'Volume Total no Período';
    } else if (_metric == DashboardMetric.sets) {
      mainValueStr = '${lastValue.toInt()}';
      label = 'Séries Semanais (Atual)';
    } else {
      mainValueStr = '${lastValue.toStringAsFixed(1)}kg';
      label = 'Carga Atual (Último Treino)';
    }

    // Evolução Percentual
    final evolution = firstValue > 0 ? ((lastValue - firstValue) / firstValue) * 100 : 0.0;
    final isPositive = evolution >= 0;

    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Text(
                    mainValueStr, 
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            color: isPositive 
                ? Colors.green.withOpacity(0.1) 
                : Colors.red.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Evolução (vs Início)', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        color: isPositive ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isPositive ? "+" : ""}${evolution.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: isPositive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainChart() {
    final data = _getChartData();
    if (data.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(child: Text('Sem dados para os filtros selecionados.')),
      );
    }

    final sortedDates = data.keys.toList()..sort();
    final firstDate = sortedDates.first;
    final firstValue = data[firstDate]!;

    // Preparar Spots
    final spots = <FlSpot>[];
    for (final date in sortedDates) {
      final x = date.difference(firstDate).inDays.toDouble();
      final y = data[date]!;
      
      if (_chartMode == ChartMode.percentage) {
        // Calcular % relativo ao primeiro
        if (firstValue > 0) {
          spots.add(FlSpot(x, ((y - firstValue) / firstValue) * 100));
        } else {
             spots.add(FlSpot(x, 0)); // Evitar div por zero
        }
      } else {
        spots.add(FlSpot(x, y));
      }
    }

    // Configuração do Eixo X
    final totalDays = sortedDates.last.difference(firstDate).inDays;
    double interval = 1;
     if (totalDays > 365) interval = 60;
    else if (totalDays > 180) interval = 30;
    else if (totalDays > 90) interval = 15;
    else if (totalDays > 30) interval = 7;
    else if (totalDays > 14) interval = 2;

    // Configuração de linhas de limite (Landmarks) para Séries Semanais
    // Apenas se visualizando Sets em modo Absoluto e com Músculo selecionado
    final showLandmarks = _metric == DashboardMetric.sets && 
                          _selectedMuscleGroup != null && 
                          _chartMode == ChartMode.absolute;

    return Column(
      children: [
        if (showLandmarks)
           Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 12, height: 12, color: Colors.green.withOpacity(0.5)),
                const SizedBox(width: 4),
                const Text('Hipertrofia (10-20 séries)', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Container(width: 12, height: 12, color: Colors.orange.withOpacity(0.5)),
                const SizedBox(width: 4),
                const Text('Risco Over. (>20)', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.only(right: 24, left: 16, top: 24, bottom: 24),
            child: AspectRatio(
              aspectRatio: 1.5,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  extraLinesData: showLandmarks 
                    ? ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: 10, /* MEV (Minimum Effective Volume) approx */
                            color: Colors.green.withOpacity(0.5),
                            strokeWidth: 1,
                            dashArray: [5, 5],
                            label: HorizontalLineLabel(
                              show: true, 
                              alignment: Alignment.topRight,
                              style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                              labelResolver: (line) => 'Mín. Eficaz (MEV)',
                            ),
                          ),
                          HorizontalLine(
                            y: 20, /* MRV (Maximum Recoverable Volume) approx */
                            color: Colors.red.withOpacity(0.5),
                            strokeWidth: 1,
                            dashArray: [5, 5],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.bottomRight,
                              style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                              labelResolver: (line) => 'Máx. Recuperável',
                            ),
                          ),
                        ],
                      ) 
                    : null,
                  titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            if (_chartMode == ChartMode.percentage) {
                              return Text('${value.toInt()}%', style: const TextStyle(fontSize: 10));
                            }
                            if (_metric == DashboardMetric.sets) {
                                return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                            }
                            return Text(
                              value >= 1000 ? '${(value/1000).toStringAsFixed(1)}k' : value.toInt().toString(),
                              style: const TextStyle(fontSize: 10)
                              );
                          }
                        )
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: interval,
                          getTitlesWidget: (value, meta) {
                            final date = firstDate.add(Duration(days: value.toInt()));
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(DateFormat('dd/MM').format(date), style: const TextStyle(fontSize: 10)),
                            );
                          }
                        )
                      )
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: _metric != DashboardMetric.load, // Carga reto, outros curvos
                      color: _metric == DashboardMetric.volume 
                          ? Theme.of(context).colorScheme.primary 
                          : (_metric == DashboardMetric.sets ? Colors.purple : Colors.orange),
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                          show: _metric != DashboardMetric.load,
                          color: (_metric == DashboardMetric.sets ? Colors.purple : Theme.of(context).colorScheme.primary).withOpacity(0.1),
                      ),
                    )
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final date = firstDate.add(Duration(days: spot.x.toInt()));
                          final val = spot.y;
                          String label = '';
                          if (_chartMode == ChartMode.percentage) {
                            label = '${val > 0 ? "+" : ""}${val.toStringAsFixed(1)}%';
                          } else {
                            String unit = '';
                            if (_metric == DashboardMetric.volume) unit = 'kg';
                            else if (_metric == DashboardMetric.sets) unit = 'séries';
                            else unit = 'kg';
                            
                            label = '${val.toStringAsFixed(1)} $unit';
                          }
                          
                          return LineTooltipItem(
                            '${DateFormat('dd/MM').format(date)}\n$label',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        }).toList();
                      }
                    )
                  )
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryStats() {
    // Se o filtro Grupo Muscular estiver como "Todos", mostramos a distribuição
    if (_selectedMuscleGroup == null) {
      final muscleVolume = <String, double>{};
      for (final w in _workouts) {
        for (final e in w.exercises) {
          muscleVolume[e.muscleGroup] = (muscleVolume[e.muscleGroup] ?? 0) + e.volume;
        }
      }
      
      final totalVolume = muscleVolume.values.fold(0.0, (s, v) => s + v);
      final sorted = muscleVolume.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
      
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Distribuição por Grupo Muscular', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              ...sorted.map((e) {
                final pct = totalVolume > 0 ? e.value / totalVolume : 0.0;
                final color = _muscleColors[e.key] ?? Colors.grey;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key),
                          Text('${(pct*100).toStringAsFixed(1)}%'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: pct,
                        color: color,
                        backgroundColor: color.withOpacity(0.2),
                      )
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    } 
    // Se estiver filtrado por músculo, pode mostrar Volume por Exercício dentro do grupo
    else {
      final exerciseVolume = <String, double>{};
      for (final w in _workouts) {
        for (final e in w.exercises) {
          if (e.muscleGroup == _selectedMuscleGroup) {
            exerciseVolume[e.name] = (exerciseVolume[e.name] ?? 0) + e.volume;
          }
        }
      }
      final sorted = exerciseVolume.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
      // Top 5
      final top5 = sorted.take(5);

      return Card(
         child: Padding(
           padding: const EdgeInsets.all(16),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text('Top Exercícios (Volume Total)', style: Theme.of(context).textTheme.titleMedium),
               const SizedBox(height: 16),
               ...top5.map((e) {
                 return ListTile(
                   contentPadding: EdgeInsets.zero,
                   title: Text(e.key),
                   trailing: Text('${(e.value/1000).toStringAsFixed(1)}t', style: const TextStyle(fontWeight: FontWeight.bold)),
                 );
               })
             ],
           ),
         ),
      );
    }
  }
}

class _ChecklistItem extends StatefulWidget {
  final String title;
  final IconData icon;

  const _ChecklistItem({required this.title, required this.icon});

  @override
  State<_ChecklistItem> createState() => _ChecklistItemState();
}

class _ChecklistItemState extends State<_ChecklistItem> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Row(
        children: [
          Icon(widget.icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 14))),
        ],
      ),
      value: _checked,
      onChanged: (val) => setState(() => _checked = val ?? false),
    );
  }
}
