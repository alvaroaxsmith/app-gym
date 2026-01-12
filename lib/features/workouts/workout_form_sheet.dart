import 'package:flutter/material.dart';

import '../../models/exercise_entry.dart';
import '../../models/exercise_library_item.dart';
import '../exercises/exercise_library_picker_modal.dart';
import 'widgets/exercise_form_dialog.dart';
import 'widgets/exercise_timer_modal.dart';

class WorkoutFormSheet extends StatefulWidget {
  const WorkoutFormSheet({super.key, required this.initialExercises});

  final List<ExerciseEntry> initialExercises;

  @override
  State<WorkoutFormSheet> createState() => _WorkoutFormSheetState();
}

class _WorkoutFormSheetState extends State<WorkoutFormSheet> {
  final List<ExerciseEntry> _exercises = [];

  @override
  void initState() {
    super.initState();
    _exercises.addAll(widget.initialExercises);
    if (_exercises.isEmpty) {
      // Opcional: Iniciar o fluxo de adicionar exercício automaticamente se vazio?
      // Por enquanto, deixamos vazia e o usuário clica em adicionar.
    }
  }

  Future<void> _addManualExercise() async {
    await showDialog(
      context: context,
      builder: (context) => ExerciseFormDialog(
        onSave: (exercise) {
          setState(() {
            _exercises.add(exercise);
          });
        },
      ),
    );
  }

  Future<void> _editExercise(int index) async {
    await showDialog(
      context: context,
      builder: (context) => ExerciseFormDialog(
        initialValue: _exercises[index],
        onSave: (exercise) {
          setState(() {
            _exercises[index] = exercise;
          });
        },
      ),
    );
  }

  Future<void> _addExerciseFromLibrary() async {
    final result = await showModalBottomSheet<ExerciseLibraryItem>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ExerciseLibraryPickerModal(),
    );

    if (result != null) {
      // Transforma o item da biblioteca em um exercício com valores padrão
      final exercise = ExerciseEntry(
        id: null,
        name: result.name,
        muscleGroup: result.muscleGroup,
        sets: 3,
        reps: '10',
        weightKg: 0,
        restSeconds: 60,
      );

      // Abre o diálogo de edição para confirmar/ajustar valores
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => ExerciseFormDialog(
            initialValue: exercise,
            onSave: (savedExercise) {
              setState(() {
                _exercises.add(savedExercise);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${savedExercise.name} adicionado'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        );
      }
    }
  }

  Future<void> _openTimer(int index) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ExerciseTimerModal(exercise: _exercises[index]),
    );
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  void _submit() {
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Adicione ao menos um exercício')));
      return;
    }
    Navigator.of(context).pop(_exercises);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: padding),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Registrar treino',
                    style: theme.textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _exercises.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum exercício adicionado',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _exercises.length,
                      itemBuilder: (context, index) {
                        final exercise = _exercises[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Text(
                                exercise.muscleGroup.substring(0, 1),
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            title: Text(exercise.name),
                            subtitle: Text(
                              '${exercise.sets}x ${exercise.reps} • ${exercise.weightKg}kg • ${exercise.restSeconds}s',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _removeExercise(index),
                            ),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (ctx) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.timer_outlined),
                                        title: const Text('Iniciar Contagem (Descanso)'),
                                        subtitle: const Text('Executar séries com cronômetro'),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          _openTimer(index);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.edit_outlined),
                                        title: const Text('Editar Detalhes'),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          _editExercise(index);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _addManualExercise,
                          icon: const Icon(Icons.add),
                          label: const Text('Manual'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _addExerciseFromLibrary,
                          icon: const Icon(Icons.library_books),
                          label: const Text('Biblioteca'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar treino'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

