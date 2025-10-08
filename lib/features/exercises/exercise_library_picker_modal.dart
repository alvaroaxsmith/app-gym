import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui_helpers.dart';
import '../../models/exercise_library_item.dart';
import 'exercise_detail_page.dart';
import 'exercise_library_database_repository.dart';

class ExerciseLibraryPickerModal extends StatefulWidget {
  const ExerciseLibraryPickerModal({super.key});

  @override
  State<ExerciseLibraryPickerModal> createState() => _ExerciseLibraryPickerModalState();
}

class _ExerciseLibraryPickerModalState extends State<ExerciseLibraryPickerModal> {
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Biblioteca de Exercícios',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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

          const SizedBox(height: 12),

          // Muscle group filter chips
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
          const Divider(height: 1),

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

          // Exercise list
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
      padding: const EdgeInsets.all(16),
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
        onTap: () async {
          final result = await Navigator.of(context).push<ExerciseLibraryItem>(
            MaterialPageRoute(
              builder: (_) => ExerciseDetailPage(exercise: exercise),
            ),
          );
          if (result != null && mounted) {
            Navigator.of(context).pop(result);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon or image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: exercise.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          exercise.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.fitness_center,
                              color: colorScheme.onPrimaryContainer,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.fitness_center,
                        color: colorScheme.onPrimaryContainer,
                      ),
              ),
              const SizedBox(width: 12),

              // Exercise info
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
                        if (exercise.difficultyLevel != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            _getDifficultyIcon(exercise.difficultyLevel!),
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            exercise.difficultyLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (exercise.equipment != null) ...[
                      const SizedBox(height: 4),
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
              ),

              // Arrow icon
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

  IconData _getDifficultyIcon(String level) {
    switch (level) {
      case 'beginner':
        return Icons.star_outline;
      case 'intermediate':
        return Icons.star_half;
      case 'advanced':
        return Icons.star;
      default:
        return Icons.help_outline;
    }
  }
}
