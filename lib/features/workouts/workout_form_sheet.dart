import 'package:flutter/material.dart';

import '../../models/exercise_entry.dart';
import '../../models/exercise_library_item.dart';
import '../../models/exercise_template.dart';
import '../exercises/exercise_library_picker_modal.dart';
import 'widgets/exercise_name_autocomplete.dart';

class WorkoutFormSheet extends StatefulWidget {
  const WorkoutFormSheet({super.key, required this.initialExercises});

  final List<ExerciseEntry> initialExercises;

  @override
  State<WorkoutFormSheet> createState() => _WorkoutFormSheetState();
}

class _WorkoutFormSheetState extends State<WorkoutFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final List<_ExerciseFormData> _items = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialExercises.isEmpty) {
      _items.add(_ExerciseFormData());
    } else {
      for (final exercise in widget.initialExercises) {
        _items.add(_ExerciseFormData.fromExercise(exercise));
      }
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addExercise() {
    setState(() {
      _items.add(_ExerciseFormData());
    });
  }

  Future<void> _addExerciseFromLibrary() async {
    final result = await showModalBottomSheet<ExerciseLibraryItem>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ExerciseLibraryPickerModal(),
    );

    if (result != null) {
      setState(() {
        _items.add(_ExerciseFormData.fromLibraryItem(result));
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.name} adicionado'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _removeExercise(int index) {
    if (_items.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inclua pelo menos um exercício')),
      );
      return;
    }
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final exercises = _items.map((item) => item.toExercise()).toList();
    if (exercises.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Adicione ao menos um exercício')));
      return;
    }
    Navigator.of(context).pop(exercises);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: padding),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Registrar treino',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._items.asMap().entries.map(
                    (entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Card(
                        key: ValueKey(item),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text('Exercício ${index + 1}',
                                        style: Theme.of(context).textTheme.titleMedium),
                                  ),
                                  IconButton(
                                    tooltip: 'Remover exercício',
                                    onPressed: () => _removeExercise(index),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ExerciseNameAutocomplete(
                                controller: item.name,
                                onExerciseSelected: (template) {
                                  if (template != null) {
                                    setState(() {
                                      item.muscleGroup = template.muscleGroup;
                                      if (template.lastSets != null) {
                                        item.sets.text = template.lastSets.toString();
                                      }
                                      if (template.lastReps != null) {
                                        item.reps.text = template.lastReps!;
                                      }
                                      if (template.lastWeightKg != null) {
                                        item.weight.text = template.lastWeightKg.toString();
                                      }
                                      if (template.lastRestSeconds != null) {
                                        item.rest.text = template.lastRestSeconds.toString();
                                      }
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Valores preenchidos do último treino'),
                                        duration: const Duration(seconds: 2),
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
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: item.muscleGroup,
                                decoration: const InputDecoration(labelText: 'Grupo muscular'),
                                items: kMuscleGroups
                                    .map(
                                      (group) => DropdownMenuItem(
                                        value: group,
                                        child: Text(group),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) => item.muscleGroup = value ?? kMuscleGroups.first,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: item.sets,
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
                                      controller: item.reps,
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
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: item.weight,
                                      decoration: const InputDecoration(
                                        labelText: 'Peso (kg)',
                                        helperText: 'Ex: 0.5 ou 10',
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(decimal: true, signed: false),
                                      validator: (value) {
                                        final parsed = double.tryParse(value ?? '');
                                        if (parsed == null) {
                                          return 'Valor inválido';
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
                                      controller: item.rest,
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
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _addExercise,
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar manualmente'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _addExerciseFromLibrary,
                          icon: const Icon(Icons.library_books),
                          label: const Text('Da biblioteca'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar treino'),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseFormData {
  _ExerciseFormData()
      : name = TextEditingController(),
        muscleGroup = kMuscleGroups.first,
        sets = TextEditingController(text: '3'),
        reps = TextEditingController(text: '10'),
        weight = TextEditingController(),
        rest = TextEditingController(text: '60');

  _ExerciseFormData.fromExercise(ExerciseEntry exercise)
      : name = TextEditingController(text: exercise.name),
        muscleGroup = exercise.muscleGroup,
        sets = TextEditingController(text: exercise.sets.toString()),
        reps = TextEditingController(text: exercise.reps),
        weight = TextEditingController(text: exercise.weightKg.toString()),
        rest = TextEditingController(text: exercise.restSeconds.toString());

  _ExerciseFormData.fromLibraryItem(ExerciseLibraryItem item)
      : name = TextEditingController(text: item.name),
        muscleGroup = item.muscleGroup,
        sets = TextEditingController(text: '3'),
        reps = TextEditingController(text: '10'),
        weight = TextEditingController(),
        rest = TextEditingController(text: '60');

  final TextEditingController name;
  String muscleGroup;
  final TextEditingController sets;
  final TextEditingController reps;
  final TextEditingController weight;
  final TextEditingController rest;

  ExerciseEntry toExercise() {
    return ExerciseEntry(
      id: null,
      name: name.text.trim(),
      muscleGroup: muscleGroup,
      sets: int.parse(sets.text),
      reps: reps.text.trim(),
      weightKg: double.parse(weight.text),
      restSeconds: int.parse(rest.text),
    );
  }

  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
    weight.dispose();
    rest.dispose();
  }
}
