import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui_helpers.dart';
import '../../models/training_plan.dart';
import 'plan_workout_editor_page.dart';
import 'training_plan_repository.dart';

class PlanDetailPage extends StatefulWidget {
  final String planId;

  const PlanDetailPage({super.key, required this.planId});

  @override
  State<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends State<PlanDetailPage> {
  late final TrainingPlanRepository _repository;
  bool _isLoading = true;
  TrainingPlan? _plan;

  @override
  void initState() {
    super.initState();
    _repository = TrainingPlanRepository(Supabase.instance.client);
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final plan = await _repository.fetchPlanDetails(widget.planId);
      if (mounted) {
        setState(() {
          _plan = plan;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showSnack(context, 'Erro ao carregar detalhes: $e', isError: true);
      }
    }
  }

  Future<void> _deletePlan() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Plano?'),
        content: const Text('Isso removerá todo o histórico deste planejamento.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deletePlan(widget.planId);
        if (mounted) {
          Navigator.pop(context);
          showSnack(context, 'Plano excluído.');
        }
      } catch (e) {
        if (mounted) showSnack(context, 'Erro ao excluir: $e', isError: true);
      }
    }
  }

  Future<void> _addWorkoutToWeek(TrainingPlanWeek week) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adicionar Treino - Semana ${week.weekNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration:
                  const InputDecoration(labelText: 'Nome (ex: Perna A)'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        await _repository.addWorkoutToWeek(
          week.id!,
          TrainingPlanWorkout(
            name: nameController.text,
            description: descriptionController.text.isEmpty
                ? null
                : descriptionController.text,
          ),
        );
        _loadDetails();
      } catch (e) {
        if (mounted) {
          showSnack(context, 'Erro ao criar treino: $e', isError: true);
        }
      }
    }
  }

  Future<void> _deleteWorkout(TrainingPlanWorkout workout) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Treino?'),
        content: Text('Remover "${workout.name}" desta semana?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deleteWorkout(workout.id!);
        _loadDetails();
      } catch (e) {
        if (mounted) showSnack(context, 'Erro ao deletar: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (_plan == null) {
      return const Scaffold(body: Center(child: Text('Plano não encontrado')));
    }

    final p = _plan!;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(icon: const Icon(Icons.delete), onPressed: _deletePlan),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildHeader(p),
                   const SizedBox(height: 24),
                   const Text(
                     'Estrutura do Ciclo',
                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final week = p.weeks[index];
                return _buildWeekCard(week);
              },
              childCount: p.weeks.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(TrainingPlan p) {
    return Card(
      elevation: 0,
       color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.flag),
                const SizedBox(width: 8),
                Text('Objetivo: ${p.goal.label}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
             if (p.description != null && p.description!.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(p.description!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekCard(TrainingPlanWeek week) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        side: week.isDeload ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none,
        borderRadius: BorderRadius.circular(12),
      ), 
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: week.isDeload ? Colors.green.withValues(alpha: 0.2) : null,
          child: Text('${week.weekNumber}'),
        ),
        title: Text(
          week.label ?? 'Semana ${week.weekNumber}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: week.isDeload ? Colors.green : null,
          ),
        ),
        subtitle: Text('Meta RPE: ${week.targetRpeMin?.toStringAsFixed(0) ?? "?"} - ${week.targetRpeMax?.toStringAsFixed(0) ?? "?"}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (week.isDeload)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.healing, size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(child: Text('Semana de Deload: Foco na recuperação total.', style: TextStyle(color: Colors.green))),
                      ],
                    ),
                  ),
                if (week.notes != null) ...[
                  const SizedBox(height: 12),
                  Text('Estratégia:',
                      style: Theme.of(context).textTheme.labelLarge),
                  Text(week.notes!),
                ],
                const SizedBox(height: 12),
                Text('Rotinas da Semana:',
                    style: Theme.of(context).textTheme.labelLarge),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    'Dica: Deslize para a direita para registrar o treino como realizado.',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ),
                if (week.workouts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Nenhum treino planejado.',
                        style: TextStyle(color: Colors.grey)),
                  ),

                ...week.workouts.map((w) => Dismissible(
                  background: Container(
                    color: Colors.green,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Concluir Treino', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  direction: DismissDirection.startToEnd,
                  confirmDismiss: (direction) async {
                     final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Registrar Treino Realizado?'),
                        content: Text('Isso criará um registro histórico de execução para "${w.name}" com as cargas zeradas (ou padrão) para você atualizar se necessário.\n\nDeseja continuar?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar')),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Registrar'),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      try {
                        await _repository.logWorkoutFromRoutine(w);
                        if (mounted) {
                          showSnack(context, 'Treino "${w.name}" registrado com sucesso!');
                        }
                        return false; 
                      } catch (e) {
                        if (mounted) {
                          showSnack(context, 'Erro ao registrar: $e', isError: true);
                        }
                        return false;
                      }
                    }
                    return false;
                  },
                  key: ValueKey('plan_workout_${w.id}'),
                  child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.fitness_center, size: 20),
                      title: Text(w.name),
                      subtitle: w.items.isEmpty 
                        ? const Text('Vazio', style: TextStyle(color: Colors.red))
                        : Text('${w.items.length} exercícios'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () {
                           Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlanWorkoutEditorPage(
                                planId: widget.planId,
                                weekId: week.id!,
                                workoutId: w.id!,
                                workoutName: w.name,
                              ),
                            ),
                          ).then((_) => _loadDetails());
                        },
                      ),
                      onLongPress: () => _deleteWorkout(w),
                    ),
                )),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar Rotina'),
                    onPressed: () => _addWorkoutToWeek(week),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
