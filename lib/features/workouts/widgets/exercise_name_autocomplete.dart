import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/exercise_template.dart';
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

class _ExerciseNameAutocompleteState extends State<ExerciseNameAutocomplete> {
  final _repository = ExerciseLibraryRepository(Supabase.instance.client);
  List<ExerciseTemplate> _suggestions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      final suggestions = await _repository.fetchUserExercises();
      if (mounted) {
        setState(() => _suggestions = suggestions);
      }
    } catch (e) {
      // Silently fail - autocomplete is optional
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<ExerciseTemplate>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<ExerciseTemplate>.empty();
        }
        
        final lowerQuery = textEditingValue.text.toLowerCase();
        return _suggestions.where((exercise) {
          return exercise.name.toLowerCase().contains(lowerQuery);
        });
      },
      displayStringForOption: (ExerciseTemplate option) => option.name,
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
      onSelected: (ExerciseTemplate selection) {
        widget.controller.text = selection.name;
        widget.onExerciseSelected(selection);
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<ExerciseTemplate> onSelected,
        Iterable<ExerciseTemplate> options,
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
                  final ExerciseTemplate option = options.elementAt(index);
                  return ListTile(
                    leading: const Icon(Icons.fitness_center, size: 20),
                    title: Text(option.name),
                    subtitle: Text(
                      '${option.muscleGroup} • Usado ${option.usageCount}x',
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
