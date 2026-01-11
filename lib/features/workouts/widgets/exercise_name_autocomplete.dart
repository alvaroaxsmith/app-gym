import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/exercise_template.dart';
import '../../exercises/custom_exercise_repository.dart';
import '../../exercises/exercise_library_repository.dart';

class ExerciseNameAutocomplete extends StatefulWidget {
  const ExerciseNameAutocomplete({
    super.key,
    required this.controller,
    required this.onExerciseSelected,
    this.validator,
  });

  final TextEditingController controller;
  final Function(ExerciseTemplate?) onExerciseSelected;
  final String? Function(String?)? validator;

  @override
  State<ExerciseNameAutocomplete> createState() => _ExerciseNameAutocompleteState();
}

class _ExerciseSuggestion {
  final String name;
  final String? muscleGroup;
  final int usageCount;
  final bool isCustom;
  final ExerciseTemplate? template;

  _ExerciseSuggestion({
    required this.name,
    this.muscleGroup,
    required this.usageCount,
    required this.isCustom,
    this.template,
  });
}

class _ExerciseNameAutocompleteState extends State<ExerciseNameAutocomplete> {
  final _repository = ExerciseLibraryRepository(Supabase.instance.client);
  final _customRepository = CustomExerciseRepository(Supabase.instance.client);
  List<_ExerciseSuggestion> _suggestions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    if (mounted) setState(() => _isLoading = true);
    
    try {
      final suggestions = await _repository.fetchUserExercises();
      final customExercises = await _customRepository.fetchUserCustomExercises();
      
      if (mounted) {
        setState(() {
          _suggestions = [
            // Custom exercises first
            ...customExercises.map((e) => _ExerciseSuggestion(
              name: e.name,
              muscleGroup: e.muscleGroup,
              usageCount: 0, // Custom exercises don't have usage count yet
              isCustom: true,
            )),
            // Then history exercises
            ...suggestions.map((e) => _ExerciseSuggestion(
              name: e.name,
              muscleGroup: e.muscleGroup,
              usageCount: e.usageCount,
              isCustom: false,
              template: e,
            )),
          ];
        });
      }
    } catch (e) {
      // Silently fail - autocomplete is optional
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<_ExerciseSuggestion>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<_ExerciseSuggestion>.empty();
        }
        
        final lowerQuery = textEditingValue.text.toLowerCase();
        return _suggestions.where((exercise) {
          return exercise.name.toLowerCase().contains(lowerQuery);
        });
      },
      displayStringForOption: (_ExerciseSuggestion option) => option.name,
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldController,
        FocusNode fieldFocusNode,
        VoidCallback onFieldSubmitted,
      ) {
        // Sync with the provided controller
        if (widget.controller.text != fieldController.text) {
          fieldController.text = widget.controller.text;
        }
        
        fieldController.addListener(() {
          if (widget.controller.text != fieldController.text) {
            widget.controller.text = fieldController.text;
          }
        });

        return TextFormField(
          controller: fieldController,
          focusNode: fieldFocusNode,
          decoration: InputDecoration(
            labelText: 'Nome do exercício',
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.arrow_drop_down),
          ),
          validator: widget.validator,
          onFieldSubmitted: (value) => onFieldSubmitted(),
        );
      },
      onSelected: (_ExerciseSuggestion selection) {
        widget.controller.text = selection.name;
        widget.onExerciseSelected(selection.template);
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<_ExerciseSuggestion> onSelected,
        Iterable<_ExerciseSuggestion> options,
      ) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final _ExerciseSuggestion option = options.elementAt(index);
                  return ListTile(
                    leading: Icon(
                      option.isCustom ? Icons.star : Icons.fitness_center,
                      size: 20,
                      color: option.isCustom ? Colors.amber : null,
                    ),
                    title: Text(option.name),
                    subtitle: Text(
                      option.isCustom
                          ? '${option.muscleGroup} • Personalizado'
                          : '${option.muscleGroup} • Usado ${option.usageCount}x',
                      style: const TextStyle(fontSize: 12),
                    ),
                    dense: true,
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
