import 'package:flutter/material.dart';
import '../../../models/exercise_entry.dart';
import 'exercise_name_autocomplete.dart';

class ExerciseFormDialog extends StatefulWidget {
  const ExerciseFormDialog({
    super.key,
    this.initialValue,
    required this.onSave,
  });

  final ExerciseEntry? initialValue;
  final ValueChanged<ExerciseEntry> onSave;

  @override
  State<ExerciseFormDialog> createState() => _ExerciseFormDialogState();
}

class _ExerciseFormDialogState extends State<ExerciseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late String _muscleGroup;
  late TextEditingController _sets;
  late TextEditingController _reps;
  late TextEditingController _weight;
  late TextEditingController _rest;

  static const List<String> _kMuscleGroups = [
    'Peito',
    'Costas',
    'Perna',
    'Ombro',
    'Bíceps',
    'Tríceps',
    'Abdômen',
    'Cardio',
    'Outro',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    _name = TextEditingController(text: initial?.name);
    _muscleGroup = initial?.muscleGroup ?? _kMuscleGroups.first;
    _sets = TextEditingController(text: initial?.sets.toString() ?? '3');
    _reps = TextEditingController(text: initial?.reps ?? '10');
    _weight = TextEditingController(text: initial?.weightKg.toString());
    _rest = TextEditingController(text: initial?.restSeconds.toString() ?? '60');
  }

  @override
  void dispose() {
    _name.dispose();
    _sets.dispose();
    _reps.dispose();
    _weight.dispose();
    _rest.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final exercise = ExerciseEntry(
      id: widget.initialValue?.id,
      name: _name.text.trim(),
      muscleGroup: _muscleGroup,
      sets: int.parse(_sets.text),
      reps: _reps.text.trim(),
      weightKg: double.parse(_weight.text),
      restSeconds: int.parse(_rest.text),
    );

    widget.onSave(exercise);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialValue == null ? 'Novo exercício' : 'Editar exercício'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExerciseNameAutocomplete(
                controller: _name,
                onExerciseSelected: (template) {
                  if (template != null) {
                    setState(() {
                      _muscleGroup = template.muscleGroup;
                      if (template.lastSets != null) {
                        _sets.text = template.lastSets.toString();
                      }
                      if (template.lastReps != null) {
                        _reps.text = template.lastReps!;
                      }
                      if (template.lastWeightKg != null) {
                        _weight.text = template.lastWeightKg.toString();
                      }
                      if (template.lastRestSeconds != null) {
                        _rest.text = template.lastRestSeconds.toString();
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Valores preenchidos do último treino'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _muscleGroup,
                decoration: const InputDecoration(labelText: 'Grupo muscular'),
                items: _kMuscleGroups
                    .map(
                      (group) => DropdownMenuItem(
                        value: group,
                        child: Text(group),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _muscleGroup = value!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sets,
                      decoration: const InputDecoration(labelText: 'Séries'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final parsed = int.tryParse(value ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _reps,
                      decoration: const InputDecoration(labelText: 'Repetições'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Obrigatório';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weight,
                      decoration: const InputDecoration(
                        labelText: 'Peso (kg)',
                        helperText: 'Ex: 10.5',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: false,
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(value ?? '');
                        if (parsed == null) {
                          return 'Inválido';
                        }
                        if (parsed < 0) {
                          return 'Deve ser >= 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _rest,
                      decoration: const InputDecoration(labelText: 'Descanso (s)'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final parsed = int.tryParse(value ?? '');
                        if (parsed == null || parsed < 0) {
                          return 'Inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
