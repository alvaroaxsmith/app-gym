import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui_helpers.dart';
import '../../models/exercise_library_item.dart';
import '../../models/training_plan.dart';
import '../../models/exercise_entry.dart';
import '../exercises/exercise_library_picker_modal.dart';
import '../workouts/widgets/exercise_timer_modal.dart';
import 'plan_item_editor_dialog.dart';
import 'training_plan_repository.dart';

class PlanWorkoutEditorPage extends StatefulWidget {
  final String planId;
  final String weekId;
  final String workoutId;
  final String workoutName;

  const PlanWorkoutEditorPage({
    super.key,
    required this.planId,
    required this.weekId,
    required this.workoutId,
    required this.workoutName,
  });

  @override
  State<PlanWorkoutEditorPage> createState() => _PlanWorkoutEditorPageState();
}

class _PlanWorkoutEditorPageState extends State<PlanWorkoutEditorPage> {
  late final TrainingPlanRepository _repository;
  bool _isLoading = true;
  TrainingPlanWorkout? _workout;

  @override
  void initState() {
    super.initState();
    _repository = TrainingPlanRepository(Supabase.instance.client);
    _loadWorkout();
  }

  Future<void> _loadWorkout() async {
    setState(() => _isLoading = true);
    // Since we don't have a direct "fetchWorkout" method that returns items easily without fetching the whole plan or writing a new query,
    // let's write a specific fetch or just fetch the plan and find the workout.
    // Ideally, we should add `fetchWorkout` to repository.
    // For now, I'll fetch the whole plan to keep it consistent with the previous logic, although inefficient.
    // optimizing: actually, I'll add a fetchWorkoutDetails to repo?
    // Let's just try to fetch the plan and filter on client side for now to save complexity, 
    // or add a direct query here if needed.
    // BETTER: Add fetchWorkout(id) to Repository. I'll do that in a bit. 
    // For now, let's assume I can get the plan and find it.
    
    try {
      final plan = await _repository.fetchPlanDetails(widget.planId);
      final week = plan.weeks.firstWhere((w) => w.id == widget.weekId);
      final workout = week.workouts.firstWhere((w) => w.id == widget.workoutId);
      
      if (mounted) {
        setState(() {
          _workout = workout;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showSnack(context, 'Erro ao carregar treino: $e', isError: true);
      }
    }
  }

  Future<void> _addExercise() async {
    // The picker returns the selected item via Navigator.pop
    final result = await showModalBottomSheet<ExerciseLibraryItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const ExerciseLibraryPickerModal(),
    );

    if (result != null) {
      final newItem = TrainingPlanWorkoutItem(
        exerciseId: result.id,
        exerciseName: result.name,
        sets: 3,
        reps: '8-12',
        rpe: '8',
        restSeconds: 90,
      );
      await _saveItem(newItem);
    }
  }

  Future<void> _saveItem(TrainingPlanWorkoutItem item) async {
    try {
      await _repository.addWorkoutItem(widget.workoutId, item);
      _loadWorkout();
    } catch (e) {
      if (mounted) showSnack(context, 'Erro ao adicionar exercício: $e', isError: true);
    }
  }

  Future<void> _deleteItem(TrainingPlanWorkoutItem item) async {
    try {
      await _repository.deleteWorkoutItem(item.id!);
      _loadWorkout();
    } catch (e) {
       if (mounted) showSnack(context, 'Erro ao remover: $e', isError: true);
    }
  }

  Future<void> _executeExercise(TrainingPlanWorkoutItem item) async {
    // 1. Convert Plan Item to Exercise Entry (Model)
    final entry = ExerciseEntry(
      id: null,
      name: item.exerciseName ?? 'Exercício',
      muscleGroup: '', 
      sets: item.sets,
      reps: item.reps ?? '10',
      weightKg: 0,
      restSeconds: item.restSeconds ?? 60,
      rpe: double.tryParse(item.rpe ?? '0'),
    );
     
    // 2. Open Timer
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ExerciseTimerModal(exercise: entry),
    );
    
    // 3. Log if finished
    if (completed == true) {
      await _recordExerciseExecution(item);
    }
  }

  Future<void> _recordExerciseExecution(TrainingPlanWorkoutItem item) async {
    try {
      await _repository.logSingleExerciseExecution(item);
      if (mounted) {
        showSnack(context, 'Exercício concluído e registrado!');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Erro ao registrar: $e', isError: true);
    }
  }

  Future<void> _editItem(TrainingPlanWorkoutItem item) async {
    await showDialog(
      context: context,
      builder: (ctx) => PlanItemEditorDialog(
        item: item,
        onSave: (updated) async {
          try {
            await _repository.updateWorkoutItem(updated);
            _loadWorkout();
          } catch (e) {
            if (mounted) showSnack(context, 'Erro ao atualizar: $e', isError: true);
          }
        },
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_workout == null) {
      return const Scaffold(body: Center(child: Text('Treino não encontrado')));
    }

    final items = _workout!.items;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workoutName),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        label: const Text('Adicionar Exercício'),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (items.isNotEmpty)
            Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               color: Colors.yellow.shade100,
               width: double.infinity,
               child: const Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(Icons.swipe_right, size: 16),
                   SizedBox(width: 8),
                   Expanded(child: Text('Deslize para a direita para registrar como executado!', style: TextStyle(fontSize: 12))),
                 ],
               ),
            ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhum exercício planejado.\nToque em + para adicionar da biblioteca.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemBuilder: (ctx, index) {
                      final item = items[index];
                      return Dismissible(
                        key: Key(item.id ?? index.toString()),
                        direction: DismissDirection.horizontal,
                        background: Container(
                          color: Colors.green,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Executado',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        secondaryBackground: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white)),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Registrar Execução?'),
                                content: const Text(
                                    'Deseja marcar este exercício como concluído agora?'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Não')),
                                  FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Sim')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _recordExerciseExecution(item);
                            }
                            return false;
                          } else {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Remover do Plano?'),
                                content: const Text(
                                    'Isso removerá o exercício do seu planejamento futuro.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancelar')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Remover',
                                          style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _deleteItem(item);
                              return true;
                            }
                            return false;
                          }
                        },
                        child: ListTile(
                          title: Text(item.exerciseName ?? 'Exercício'),
                          subtitle: Text(
                              '${item.sets} x ${item.reps ?? "?"} @ RPE ${item.rpe ?? "?"}${item.weight != null && item.weight!.isNotEmpty ? "\nCarga: ${item.weight}" : ""}'),
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          trailing: IconButton(
                            icon: const Icon(Icons.play_circle_fill,
                                color: Colors.green),
                            onPressed: () => _executeExercise(item),
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
                                      title: const Text('Iniciar Execução (Timer)'),
                                      subtitle: const Text(
                                          'Controlar tempo de descanso e séries'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _executeExercise(item);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      title: const Text('Remover do Plano'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _deleteItem(item);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.edit_outlined),
                                      title: const Text('Editar Detalhes'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _editItem(item);
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
        ],
      ),
    );
  }
}
