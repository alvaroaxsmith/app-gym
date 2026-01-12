import 'package:flutter/material.dart';
import '../../models/training_plan.dart';

class PlanItemEditorDialog extends StatefulWidget {
  final TrainingPlanWorkoutItem item;
  final ValueChanged<TrainingPlanWorkoutItem> onSave;

  const PlanItemEditorDialog({
    super.key,
    required this.item,
    required this.onSave,
  });

  @override
  State<PlanItemEditorDialog> createState() => _PlanItemEditorDialogState();
}

class _PlanItemEditorDialogState extends State<PlanItemEditorDialog> {
  late TextEditingController _setsController;
  late TextEditingController _repsController;
  late TextEditingController _rpeController;
  late TextEditingController _restController;
  late TextEditingController _weightController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _setsController = TextEditingController(text: widget.item.sets.toString());
    _repsController = TextEditingController(text: widget.item.reps ?? '');
    _rpeController = TextEditingController(text: widget.item.rpe ?? '');
    _restController = TextEditingController(text: widget.item.restSeconds?.toString() ?? '60');
    _weightController = TextEditingController(text: widget.item.weight ?? '');
    _notesController = TextEditingController(text: widget.item.notes ?? '');
  }

  @override
  void dispose() {
    _setsController.dispose();
    _repsController.dispose();
    _rpeController.dispose();
    _restController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    // Validate
    final sets = int.tryParse(_setsController.text) ?? 3;
    final rest = int.tryParse(_restController.text);

    final modified = TrainingPlanWorkoutItem(
      id: widget.item.id,
      workoutId: widget.item.workoutId,
      exerciseId: widget.item.exerciseId,
      exerciseName: widget.item.exerciseName,
      sets: sets,
      reps: _repsController.text,
      rpe: _rpeController.text,
      weight: _weightController.text,
      restSeconds: rest,
      notes: _notesController.text,
      sortOrder: widget.item.sortOrder,
    );
    widget.onSave(modified);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Editar: ${widget.item.exerciseName ?? "Exercício"}'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _setsController,
                  decoration: const InputDecoration(labelText: 'Séries', suffixText: 'x'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _repsController,
                  decoration: const InputDecoration(labelText: 'Reps (ex: 8-12)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weightController,
            decoration: const InputDecoration(
              labelText: 'Peso / Carga', 
              hintText: 'ex: 20kg (para métricas)',
              helperText: 'Use valores numéricos ou "20kg" para contabilizar no Dashboard',
              prefixIcon: Icon(Icons.fitness_center),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _rpeController,
                  decoration: const InputDecoration(labelText: 'RPE Alvo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _restController,
                  decoration: const InputDecoration(labelText: 'Descanso (s)', suffixText: 's'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notas / Observações'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Salvar')),
      ],
    );
  }
}
