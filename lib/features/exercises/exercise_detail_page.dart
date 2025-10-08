import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/exercise_library_item.dart';
import '../../models/exercise_template.dart';
import '../exercises/exercise_library_repository.dart';

class ExerciseDetailPage extends StatefulWidget {
  const ExerciseDetailPage({
    super.key,
    required this.exercise,
  });

  final ExerciseLibraryItem exercise;

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  final _historyRepository = ExerciseLibraryRepository(Supabase.instance.client);
  ExerciseTemplate? _userHistory;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadUserHistory();
  }

  Future<void> _loadUserHistory() async {
    try {
      final history = await _historyRepository.getExerciseByName(widget.exercise.name);
      if (mounted) {
        setState(() {
          _userHistory = history;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exercise.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Adicionar ao treino',
            onPressed: () {
              Navigator.of(context).pop(widget.exercise);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image placeholder
            Container(
              height: 250,
              color: colorScheme.surfaceVariant,
              child: widget.exercise.imageUrl != null
                  ? Image.network(
                      widget.exercise.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderImage();
                      },
                    )
                  : _buildPlaceholderImage(),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.fitness_center, size: 18),
                        label: Text(widget.exercise.muscleGroup),
                        backgroundColor: colorScheme.primaryContainer,
                      ),
                      if (widget.exercise.difficultyLevel != null)
                        Chip(
                          avatar: Icon(_getDifficultyIcon(), size: 18),
                          label: Text(widget.exercise.difficultyLabel),
                          backgroundColor: _getDifficultyColor(),
                        ),
                      if (widget.exercise.equipment != null)
                        Chip(
                          avatar: const Icon(Icons.build, size: 18),
                          label: Text(widget.exercise.equipment!),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Description
                  if (widget.exercise.description != null) ...[
                    Text(
                      'Descrição',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.exercise.description!,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Instructions
                  if (widget.exercise.instructions != null) ...[
                    Text(
                      'Como executar',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.exercise.instructions!,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // User history section
                  Text(
                    'Seu histórico',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  
                  if (_isLoadingHistory)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_userHistory != null)
                    _buildHistoryCard(_userHistory!)
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.history,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Você ainda não fez este exercício',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop(widget.exercise);
            },
            icon: const Icon(Icons.add),
            label: const Text('Adicionar ao Treino'),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Center(
      child: Icon(
        Icons.fitness_center,
        size: 80,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildHistoryCard(ExerciseTemplate history) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Última execução',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (history.lastUsedDate != null)
                  Text(
                    _formatDate(history.lastUsedDate!),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (history.lastSets != null && history.lastReps != null)
                  _buildStatChip(
                    Icons.repeat,
                    '${history.lastSets}x${history.lastReps}',
                  ),
                if (history.lastWeightKg != null)
                  _buildStatChip(
                    Icons.scale,
                    '${_formatWeight(history.lastWeightKg!)} kg',
                  ),
                if (history.lastRestSeconds != null)
                  _buildStatChip(
                    Icons.timer,
                    '${history.lastRestSeconds}s',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Realizado ${history.usageCount}x',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDifficultyIcon() {
    switch (widget.exercise.difficultyLevel) {
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

  Color _getDifficultyColor() {
    switch (widget.exercise.difficultyLevel) {
      case 'beginner':
        return Colors.green[100]!;
      case 'intermediate':
        return Colors.orange[100]!;
      case 'advanced':
        return Colors.red[100]!;
      default:
        return Colors.grey[200]!;
    }
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
