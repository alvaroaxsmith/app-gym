import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui_helpers.dart';
import '../../models/custom_exercise.dart';
import 'custom_exercise_repository.dart';

class CreateCustomExerciseModal extends StatefulWidget {
  const CreateCustomExerciseModal({
    super.key,
    this.existingExercise,
  });

  /// Se fornecido, o modal abre em modo edição
  final CustomExercise? existingExercise;

  @override
  State<CreateCustomExerciseModal> createState() => _CreateCustomExerciseModalState();
}

class _CreateCustomExerciseModalState extends State<CreateCustomExerciseModal> {
  final _formKey = GlobalKey<FormState>();
  final _repository = CustomExerciseRepository(Supabase.instance.client);
  
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  
  String _selectedMuscleGroup = 'Peito';
  bool _isSaving = false;

  final List<String> _muscleGroups = [
    'Peito',
    'Costas',
    'Pernas',
    'Ombros',
    'Bíceps',
    'Tríceps',
    'Abdômen',
    'Cardio',
    'Outro',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingExercise?.name);
    _descriptionController = TextEditingController(text: widget.existingExercise?.description);
    if (widget.existingExercise != null) {
      _selectedMuscleGroup = widget.existingExercise!.muscleGroup;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existingExercise != null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // Verificar se já existe exercício com esse nome
      final nameExists = await _repository.exerciseNameExists(
        _nameController.text.trim(),
        excludeId: widget.existingExercise?.id,
      );

      if (nameExists && mounted) {
        showSnack(
          context,
          'Já existe um exercício com esse nome',
          isError: true,
        );
        setState(() => _isSaving = false);
        return;
      }

      if (_isEditing) {
        // Atualizar exercício existente
        final updated = widget.existingExercise!.copyWith(
          name: _nameController.text.trim(),
          muscleGroup: _selectedMuscleGroup,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
        await _repository.updateCustomExercise(updated);
        if (mounted) {
          Navigator.of(context).pop(true); // Retorna true para indicar sucesso
          showSnack(context, 'Exercício atualizado com sucesso!');
        }
      } else {
        // Criar novo exercício
        final newExercise = CustomExercise(
          id: '', // Será gerado pelo banco
          userId: userId,
          name: _nameController.text.trim(),
          muscleGroup: _selectedMuscleGroup,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          imageUrl: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _repository.createCustomExercise(newExercise);
        if (mounted) {
          Navigator.of(context).pop(true); // Retorna true para indicar sucesso
          showSnack(context, 'Exercício criado com sucesso!');
        }
      }
    } catch (e) {
      if (mounted) {
        showSnack(
          context,
          'Erro ao ${_isEditing ? 'atualizar' : 'criar'} exercício: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isEditing ? 'Editar Exercício' : 'Novo Exercício Personalizado',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Nome do exercício
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do exercício *',
                      hintText: 'Ex: Rosca direta variação',
                      prefixIcon: Icon(Icons.fitness_center),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o nome do exercício';
                      }
                      if (value.trim().length < 3) {
                        return 'Nome deve ter pelo menos 3 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Grupo muscular
                  DropdownButtonFormField<String>(
                    value: _selectedMuscleGroup,
                    decoration: const InputDecoration(
                      labelText: 'Grupo muscular *',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                    items: _muscleGroups.map((group) {
                      return DropdownMenuItem(
                        value: group,
                        child: Text(group),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedMuscleGroup = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Descrição (opcional)
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição (opcional)',
                      hintText: 'Ex: Puxada com pegada supinada',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 24),

                  // Botão salvar
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_isEditing ? Icons.save : Icons.add_circle),
                    label: Text(_isSaving
                        ? 'Salvando...'
                        : _isEditing
                            ? 'Salvar Alterações'
                            : 'Criar Exercício'),
                  ),
                  
                  if (!_isEditing) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Seus exercícios personalizados aparecerão na biblioteca e no autocomplete.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
