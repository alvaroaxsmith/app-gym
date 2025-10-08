import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui_helpers.dart';
import '../../models/exercise_entry.dart';
import '../../models/exercise_library_item.dart';
import '../../models/exercise_template.dart';
import '../../models/workout.dart';
import '../workouts/workout_form_sheet.dart';
import '../workouts/workout_provider.dart';
import '../workouts/workout_repository.dart';
import 'exercise_detail_page.dart';
import 'exercise_library_database_repository.dart';
import 'exercise_library_repository.dart';

class ExerciseLibraryPage extends StatefulWidget {
  const ExerciseLibraryPage({super.key});

  @override
  State<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.history), text: 'Meu Histórico'),
            Tab(icon: Icon(Icons.library_books), text: 'Biblioteca'),
            Tab(icon: Icon(Icons.add_circle), text: 'Novo Treino'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _MyHistoryTab(),
              _ExerciseLibraryTab(),
              _NewWorkoutTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// Tab 1: Meu Histórico
class _MyHistoryTab extends StatefulWidget {
  const _MyHistoryTab();

  @override
  State<_MyHistoryTab> createState() => _MyHistoryTabState();
}

class _MyHistoryTabState extends State<_MyHistoryTab> {
  final _repository = ExerciseLibraryRepository(Supabase.instance.client);
  final _scrollController = ScrollController();
  List<ExerciseTemplate> _exercises = [];
  String _searchQuery = '';
  String _sortBy = 'date'; // 'date', 'name', or 'frequency'
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  int _totalCount = 0;
  static const int _pageSize = 5;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadExercises();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final delta = MediaQuery.of(context).size.height * 0.2;

    if (maxScroll - currentScroll <= delta) {
      _loadMoreExercises();
    }
  }

  Future<void> _loadExercises() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _exercises = [];
    });

    try {
      final count = await _repository.countUserExercises(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );

      final exercises = await _repository.fetchUserExercisesPaginated(
        page: 0,
        pageSize: _pageSize,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        sortBy: _sortBy,
      );

      if (mounted) {
        setState(() {
          _exercises = exercises;
          _totalCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showSnack(context, 'Erro ao carregar exercícios: $e', isError: true);
      }
    }
  }

  Future<void> _loadMoreExercises() async {
    if (_exercises.length >= _totalCount) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final exercises = await _repository.fetchUserExercisesPaginated(
        page: nextPage,
        pageSize: _pageSize,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        sortBy: _sortBy,
      );

      if (mounted) {
        setState(() {
          _exercises.addAll(exercises);
          _currentPage = nextPage;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        showSnack(context, 'Erro ao carregar mais exercícios: $e', isError: true);
      }
    }
  }

  void _onFilterChanged() {
    _loadExercises();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadExercises,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar exercício...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _onFilterChanged();
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              onSubmitted: (_) => _onFilterChanged(),
            ),
          ),

          // Sort options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Ordenar por:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Data'),
                  selected: _sortBy == 'date',
                  onSelected: (selected) {
                    setState(() => _sortBy = 'date');
                    _onFilterChanged();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Nome'),
                  selected: _sortBy == 'name',
                  onSelected: (selected) {
                    setState(() => _sortBy = 'name');
                    _onFilterChanged();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Frequência'),
                  selected: _sortBy == 'frequency',
                  onSelected: (selected) {
                    setState(() => _sortBy = 'frequency');
                    _onFilterChanged();
                  },
                ),
              ],
            ),
          ),

          // Results count
          if (!_isLoading && _totalCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_exercises.length} de $_totalCount exercícios',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),

          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_exercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'Nenhum exercício encontrado'
                  : 'Nenhum resultado para "$_searchQuery"',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Comece a treinar para criar seu histórico!'
                  : 'Tente outro termo de busca',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _exercises.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _exercises.length) {
          // Loading indicator at the bottom
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final exercise = _exercises[index];
        return _buildExerciseCard(exercise);
      },
    );
  }

  Widget _buildExerciseCard(ExerciseTemplate exercise) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.fitness_center,
                    color: colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exercise.muscleGroup,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${exercise.usageCount}x',
                    style: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (exercise.lastSets != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Últimos valores usados:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    Icons.repeat,
                    '${exercise.lastSets}x${exercise.lastReps}',
                  ),
                  if (exercise.lastWeightKg != null)
                    _buildInfoChip(
                      Icons.scale,
                      '${_formatWeight(exercise.lastWeightKg!)} kg',
                    ),
                  if (exercise.lastRestSeconds != null)
                    _buildInfoChip(
                      Icons.timer,
                      '${exercise.lastRestSeconds}s',
                    ),
                ],
              ),
              if (exercise.lastUsedDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Última vez: ${_formatDate(exercise.lastUsedDate!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  String _formatWeight(double weight) {
    if (weight >= 1) {
      return weight.toStringAsFixed(0);
    }
    return weight.toStringAsFixed(1);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final exerciseDate = DateTime(date.year, date.month, date.day);

    if (exerciseDate == today) {
      return 'Hoje';
    } else if (exerciseDate == yesterday) {
      return 'Ontem';
    } else {
      final diff = today.difference(exerciseDate).inDays;
      if (diff < 7) {
        return 'há $diff dias';
      } else if (diff < 30) {
        final weeks = (diff / 7).floor();
        return 'há $weeks ${weeks == 1 ? 'semana' : 'semanas'}';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    }
  }
}

// Tab 2: Biblioteca de Exercícios
class _ExerciseLibraryTab extends StatefulWidget {
  const _ExerciseLibraryTab();

  @override
  State<_ExerciseLibraryTab> createState() => _ExerciseLibraryTabState();
}

class _ExerciseLibraryTabState extends State<_ExerciseLibraryTab> {
  final _repository = ExerciseLibraryDatabaseRepository(Supabase.instance.client);
  final _scrollController = ScrollController();
  List<ExerciseLibraryItem> _exercises = [];
  String? _selectedMuscleGroup;
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  int _totalCount = 0;
  static const int _pageSize = 8;

  final List<String> _muscleGroups = [
    'Todos',
    'Peito',
    'Costas',
    'Pernas',
    'Ombros',
    'Bíceps',
    'Tríceps',
    'Abdômen',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadExercises();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final delta = MediaQuery.of(context).size.height * 0.2;

    if (maxScroll - currentScroll <= delta) {
      _loadMoreExercises();
    }
  }

  Future<void> _loadExercises() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _exercises = [];
    });

    try {
      final count = await _repository.countExercises(
        muscleGroup: _selectedMuscleGroup,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );

      final exercises = await _repository.fetchExercisesPaginated(
        page: 0,
        pageSize: _pageSize,
        muscleGroup: _selectedMuscleGroup,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (mounted) {
        setState(() {
          _exercises = exercises;
          _totalCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showSnack(context, 'Erro ao carregar exercícios: $e', isError: true);
      }
    }
  }

  Future<void> _loadMoreExercises() async {
    if (_exercises.length >= _totalCount) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final exercises = await _repository.fetchExercisesPaginated(
        page: nextPage,
        pageSize: _pageSize,
        muscleGroup: _selectedMuscleGroup,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (mounted) {
        setState(() {
          _exercises.addAll(exercises);
          _currentPage = nextPage;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        showSnack(context, 'Erro ao carregar mais exercícios: $e', isError: true);
      }
    }
  }

  void _onFilterChanged() {
    _loadExercises();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadExercises,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar exercício...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _onFilterChanged();
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              onSubmitted: (_) => _onFilterChanged(),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _muscleGroups.length,
              itemBuilder: (context, index) {
                final group = _muscleGroups[index];
                final isSelected = _selectedMuscleGroup == group ||
                    (_selectedMuscleGroup == null && group == 'Todos');

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(group),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedMuscleGroup = group == 'Todos' ? null : group;
                      });
                      _onFilterChanged();
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Results count
          if (!_isLoading && _totalCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${_exercises.length} de $_totalCount exercícios',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),

          Expanded(
            child: _buildExerciseList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_exercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum exercício encontrado',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _exercises.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _exercises.length) {
          // Loading indicator at the bottom
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final exercise = _exercises[index];
        return _buildExerciseCard(exercise);
      },
    );
  }

  Widget _buildExerciseCard(ExerciseLibraryItem exercise) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ExerciseDetailPage(exercise: exercise),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            exercise.muscleGroup,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        if (exercise.equipment != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            exercise.equipment!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Tab 3: Novo Treino
class _NewWorkoutTab extends StatelessWidget {
  const _NewWorkoutTab();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WorkoutProvider>(
      create: (_) => WorkoutProvider(WorkoutRepository(Supabase.instance.client)),
      child: const _NewWorkoutContent(),
    );
  }
}

class _NewWorkoutContent extends StatefulWidget {
  const _NewWorkoutContent();

  @override
  State<_NewWorkoutContent> createState() => _NewWorkoutContentState();
}

class _NewWorkoutContentState extends State<_NewWorkoutContent> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selecione a data do treino',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _formatDate(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: provider.isSaving
                ? null
                : () async {
                    final exercises = await showModalBottomSheet<List<ExerciseEntry>>(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => const WorkoutFormSheet(
                        initialExercises: [],
                      ),
                    );

                    if (exercises != null && exercises.isNotEmpty && mounted) {
                      // Atualiza a data selecionada no provider
                      provider.selectDate(_selectedDate);
                      
                      // Salva o treino
                      await provider.saveWorkout(exercises);

                      if (mounted) {
                        if (provider.errorMessage != null) {
                          showSnack(
                            context,
                            provider.errorMessage!,
                            isError: true,
                          );
                        } else {
                          showSnack(
                            context,
                            'Treino salvo com sucesso!',
                          );
                          // Voltar para a primeira aba (histórico)
                          DefaultTabController.of(context).animateTo(0);
                        }
                      }
                    }
                  },
            icon: provider.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(
              provider.isSaving ? 'Salvando...' : 'Adicionar Exercícios',
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Clique no botão acima para\nadicionar exercícios ao treino',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final selectedDay = DateTime(date.year, date.month, date.day);

    if (selectedDay == today) {
      return 'Hoje, ${date.day}/${date.month}/${date.year}';
    } else if (selectedDay == yesterday) {
      return 'Ontem, ${date.day}/${date.month}/${date.year}';
    } else {
      final weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
      return '${weekdays[date.weekday - 1]}, ${date.day}/${date.month}/${date.year}';
    }
  }
}
