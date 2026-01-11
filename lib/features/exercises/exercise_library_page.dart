import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui_helpers.dart';
import '../../models/custom_exercise.dart';
import '../../models/exercise_entry.dart';
import '../../models/exercise_library_item.dart';
import '../../models/exercise_template.dart';
import '../workouts/workout_form_sheet.dart';
import '../workouts/workout_provider.dart';
import '../workouts/workout_repository.dart';
import 'create_custom_exercise_modal.dart';
import 'custom_exercise_repository.dart';
import 'exercise_detail_page.dart';
import 'exercise_library_database_repository.dart';
import 'exercise_library_repository.dart';

// Custom scroll behavior para permitir arrastar em todas as plataformas
class DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

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

class _MyHistoryTabState extends State<_MyHistoryTab> with AutomaticKeepAliveClientMixin {
  final _repository = ExerciseLibraryRepository(Supabase.instance.client);
  final _scrollController = ScrollController();
  List<ExerciseTemplate> _exercises = [];
  String _searchQuery = '';
  String _sortBy = 'date'; // 'date', 'name', or 'frequency'
  String? _selectedMuscleGroup; // null = 'Todos'
  String _selectedPeriod = 'all'; // 'week', 'month', '3months', 'year', 'all'
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  int _totalCount = 0;
  static const int _pageSize = 5;
  
  /// Timestamp da última carga para controlar refresh automático
  DateTime? _lastLoadTime;

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
  bool get wantKeepAlive => true;

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
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recarrega dados se passou mais de 30 segundos desde a última carga
    // Isso garante que ao voltar de uma importação, os dados sejam atualizados
    if (_lastLoadTime != null && 
        DateTime.now().difference(_lastLoadTime!).inSeconds > 30 &&
        !_isLoading) {
      _loadExercises();
    }
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
      final dateRange = _getDateRange();
      
      final count = await _repository.countUserExercises(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        muscleGroup: _selectedMuscleGroup,
        startDate: dateRange?.$1,
        endDate: dateRange?.$2,
      );

      final exercises = await _repository.fetchUserExercisesPaginated(
        page: 0,
        pageSize: _pageSize,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        sortBy: _sortBy,
        muscleGroup: _selectedMuscleGroup,
        startDate: dateRange?.$1,
        endDate: dateRange?.$2,
      );

      if (mounted) {
        setState(() {
          _exercises = exercises;
          _totalCount = count;
          _isLoading = false;
          _lastLoadTime = DateTime.now();
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
      final dateRange = _getDateRange();
      final nextPage = _currentPage + 1;
      final exercises = await _repository.fetchUserExercisesPaginated(
        page: nextPage,
        pageSize: _pageSize,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        sortBy: _sortBy,
        muscleGroup: _selectedMuscleGroup,
        startDate: dateRange?.$1,
        endDate: dateRange?.$2,
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

  /// Calcula o intervalo de datas baseado no período selecionado
  (DateTime, DateTime)? _getDateRange() {
    if (_selectedPeriod == 'all') return null;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    switch (_selectedPeriod) {
      case 'week':
        return (today.subtract(const Duration(days: 7)), today);
      case 'month':
        return (today.subtract(const Duration(days: 30)), today);
      case '3months':
        return (today.subtract(const Duration(days: 90)), today);
      case 'year':
        return (today.subtract(const Duration(days: 365)), today);
      default:
        return null;
    }
  }

  void _onFilterChanged() {
    _loadExercises();
  }

  Widget _buildPeriodChip(String value, String label) {
    final isSelected = _selectedPeriod == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedPeriod = value);
        _onFilterChanged();
      },
    );
  }

  Widget _buildStatsCard() {
    return FutureBuilder<ExerciseStats>(
      future: _repository.getUserExerciseStats(
        muscleGroup: _selectedMuscleGroup,
        startDate: _getDateRange()?.$1,
        endDate: _getDateRange()?.$2,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;
        final colorScheme = Theme.of(context).colorScheme;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estatísticas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.fitness_center,
                          label: 'Exercícios únicos',
                          value: '${stats.totalUniqueExercises}',
                          colorScheme: colorScheme,
                        ),
                      ),
                      if (stats.mostPracticedExercise != null)
                        Expanded(
                          child: _buildStatItem(
                            icon: Icons.star,
                            label: 'Mais praticado',
                            value: stats.mostPracticedExercise!.name,
                            subtitle: '${stats.mostPracticedExercise!.usageCount}x',
                            colorScheme: colorScheme,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (stats.mostTrainedMuscleGroup != null)
                        Expanded(
                          child: _buildStatItem(
                            icon: Icons.outlined_flag,
                            label: 'Grupo favorito',
                            value: stats.mostTrainedMuscleGroup!,
                            colorScheme: colorScheme,
                          ),
                        ),
                      if (stats.lastWorkoutDate != null)
                        Expanded(
                          child: _buildStatItem(
                            icon: Icons.calendar_today,
                            label: 'Última sessão',
                            value: _formatDate(stats.lastWorkoutDate!),
                            colorScheme: colorScheme,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Necessário para AutomaticKeepAliveClientMixin
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Text(
                  'Ordenar por:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ScrollConfiguration(
                  behavior: DragScrollBehavior(),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
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
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Muscle group filter chips
          SizedBox(
            height: 48,
            child: ScrollConfiguration(
              behavior: DragScrollBehavior(),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _muscleGroups.length,
                itemBuilder: (context, index) {
                  final group = _muscleGroups[index];
                  final isSelected = _selectedMuscleGroup == group ||
                      (_selectedMuscleGroup == null && group == 'Todos');

                  return Padding(
                    padding: EdgeInsets.only(right: index < _muscleGroups.length - 1 ? 8 : 0),
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
          ),

          // Period filter
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
                child: Text(
                  'Período:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ScrollConfiguration(
                  behavior: DragScrollBehavior(),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildPeriodChip('week', 'Última semana'),
                      const SizedBox(width: 8),
                      _buildPeriodChip('month', 'Último mês'),
                      const SizedBox(width: 8),
                      _buildPeriodChip('3months', 'Últimos 3 meses'),
                      const SizedBox(width: 8),
                      _buildPeriodChip('year', 'Último ano'),
                      const SizedBox(width: 8),
                      _buildPeriodChip('all', 'Todo período'),
                    ],
                  ),
                ),
              ),
            ],
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

          // Statistics card
          if (!_isLoading && _totalCount > 0)
            _buildStatsCard(),

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
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _confirmDeleteExercise(exercise);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Excluir do histórico'),
                        ],
                      ),
                    ),
                  ],
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

  Future<void> _confirmDeleteExercise(ExerciseTemplate exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir exercício'),
        content: Text(
          'Tem certeza que deseja excluir "${exercise.name}" do seu histórico?\n\n'
          'Isso irá remover todas as ${exercise.usageCount} ocorrências deste exercício.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteUserExercise(exercise.name);
        if (mounted) {
          showSnack(context, 'Exercício excluído do histórico');
          _loadExercises(); // Reload the list
        }
      } catch (e) {
        if (mounted) {
          showSnack(context, 'Erro ao excluir exercício: $e', isError: true);
        }
      }
    }
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
  final _customRepository = CustomExerciseRepository(Supabase.instance.client);
  final _scrollController = ScrollController();
  List<ExerciseLibraryItem> _exercises = [];
  List<CustomExercise> _customExercises = [];
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
      _customExercises = [];
    });

    try {
      // Load custom exercises
      final customExercises = await _customRepository.fetchUserCustomExercises(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        muscleGroup: _selectedMuscleGroup,
      );

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
          _customExercises = customExercises;
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

  Future<void> _showCreateCustomExerciseModal() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const CreateCustomExerciseModal(),
    );
    
    if (result == true) {
      _loadExercises();
    }
  }

  Future<void> _showEditCustomExerciseModal(CustomExercise exercise) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CreateCustomExerciseModal(existingExercise: exercise),
    );
    
    if (result == true) {
      _loadExercises();
    }
  }

  Future<void> _deleteCustomExercise(CustomExercise exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir exercício'),
        content: Text('Deseja realmente excluir o exercício "${exercise.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _customRepository.deleteCustomExercise(exercise.id);
      _loadExercises();
      if (mounted) {
        showSnack(context, 'Exercício excluído com sucesso');
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Erro ao excluir exercício: $e', isError: true);
      }
    }
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
            height: 48,
            child: ScrollConfiguration(
              behavior: DragScrollBehavior(),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _muscleGroups.length,
                itemBuilder: (context, index) {
                  final group = _muscleGroups[index];
                  final isSelected = _selectedMuscleGroup == group ||
                      (_selectedMuscleGroup == null && group == 'Todos');

                  return Padding(
                    padding: EdgeInsets.only(right: index < _muscleGroups.length - 1 ? 8 : 0),
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
          ),
          const SizedBox(height: 8),

          // Results count
          if (!_isLoading && (_customExercises.isNotEmpty || _totalCount > 0))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _customExercises.isEmpty
                        ? '${_exercises.length} de $_totalCount exercícios'
                        : '${_customExercises.length} personalizados • ${_exercises.length} da biblioteca',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _showCreateCustomExerciseModal,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Criar Exercício'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
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

    if (_exercises.isEmpty && _customExercises.isEmpty) {
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
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _showCreateCustomExerciseModal,
              icon: const Icon(Icons.add),
              label: const Text('Criar Primeiro Exercício'),
            ),
          ],
        ),
      );
    }

    final totalItems = _customExercises.length + _exercises.length + (_isLoadingMore ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // Custom exercises first
        if (index < _customExercises.length) {
          return _buildCustomExerciseCard(_customExercises[index]);
        }
        
        // Then library exercises
        final libraryIndex = index - _customExercises.length;
        if (libraryIndex < _exercises.length) {
          return _buildExerciseCard(_exercises[libraryIndex]);
        }
        
        // Loading indicator at the bottom
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _buildCustomExerciseCard(CustomExercise exercise) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: InkWell(
        onTap: () => _showEditCustomExerciseModal(exercise),
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
                  Icons.star,
                  color: colorScheme.onPrimaryContainer,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            exercise.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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
                        const SizedBox(width: 8),
                        Text(
                          'Personalizado',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    if (exercise.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        exercise.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditCustomExerciseModal(exercise);
                  } else if (value == 'delete') {
                    _deleteCustomExercise(exercise);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Excluir', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
                    List<ExerciseEntry>? exercises;
                    final width = MediaQuery.of(context).size.width;
                    
                    if (width > 600) {
                      exercises = await showDialog<List<ExerciseEntry>>(
                        context: context,
                        builder: (context) => Dialog(
                          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: WorkoutFormSheet(initialExercises: []),
                            ),
                          ),
                        ),
                      );
                    } else {
                      exercises = await showModalBottomSheet<List<ExerciseEntry>>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (context) => const WorkoutFormSheet(
                          initialExercises: [],
                        ),
                      );
                    }

                    if (exercises != null && exercises.isNotEmpty && mounted) {
                      // Atualiza a data selecionada no provider
                      provider.selectDate(_selectedDate);
                      
                      // Salva o treino
                      await provider.saveWorkout(exercises);

                      if (context.mounted) {
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
