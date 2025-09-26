import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui_helpers.dart';
import '../../models/exercise_entry.dart';
import '../../models/workout.dart';
import '../workouts/workout_repository.dart';

class ImportWorkoutsPage extends StatefulWidget {
  const ImportWorkoutsPage({super.key});

  @override
  State<ImportWorkoutsPage> createState() => _ImportWorkoutsPageState();
}

class _ImportWorkoutsPageState extends State<ImportWorkoutsPage> {
  bool _isImporting = false;
  String? _statusMessage;

  Future<void> _pickAndImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['csv', 'json'],
      );
      if (result == null) return;
      if (!mounted) return;
      final file = result.files.single;
      if (file.bytes == null) {
        showSnack(context, 'Não foi possível ler o arquivo selecionado.', isError: true);
        return;
      }
      setState(() => _isImporting = true);
      final content = utf8.decode(file.bytes!);
      List<Workout> workouts;
      if (file.extension?.toLowerCase() == 'csv') {
        workouts = _parseCsv(content);
      } else {
        workouts = _parseJson(content);
      }
      await _saveWorkouts(workouts);
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Importação concluída: ${workouts.length} treinos e ${workouts.fold<int>(0, (sum, w) => sum + w.exercises.length)} exercícios.';
      });
      showSnack(context, 'Importação concluída com sucesso!');
    } catch (err) {
      if (!mounted) return;
      showSnack(context, 'Falha na importação. Verifique o arquivo.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  List<Workout> _parseCsv(String content) {
    final rows = const CsvToListConverter(eol: '\n').convert(content, shouldParseNumbers: false);
    if (rows.isEmpty) {
      throw const FormatException('CSV vazio');
    }
    final header = rows.first.map((value) => value.toString()).toList();
    final expected = [
      'date',
      'exercise_name',
      'muscle_group',
      'sets',
      'reps',
      'weight_kg',
      'rest_seconds',
    ];
  if (!const ListEquality().equals(header, expected)) {
      throw const FormatException('Cabeçalho CSV inválido');
    }
    final grouped = <DateTime, List<ExerciseEntry>>{};
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < expected.length) continue;
      final date = DateTime.parse(row[0].toString());
      grouped.putIfAbsent(_onlyDate(date), () => []);
      grouped[_onlyDate(date)]!.add(
        ExerciseEntry(
          id: null,
          name: row[1].toString(),
          muscleGroup: row[2].toString(),
          sets: int.tryParse(row[3].toString()) ?? 0,
          reps: row[4].toString(),
          weightKg: double.tryParse(row[5].toString()) ?? 0,
          restSeconds: int.tryParse(row[6].toString()) ?? 0,
        ),
      );
    }
    return grouped.entries
        .map(
          (entry) => Workout(
            id: null,
            userId: '',
            date: entry.key,
            exercises: entry.value,
          ),
        )
        .toList();
  }

  List<Workout> _parseJson(String content) {
    final json = jsonDecode(content) as List<dynamic>;
    final workouts = <Workout>[];
    for (final item in json) {
      final map = item as Map<String, dynamic>;
      final date = DateTime.parse(map['date'] as String);
      final exercisesJson = map['exercises'] as List<dynamic>? ?? [];
      final exercises = exercisesJson
          .map(
            (exercise) => ExerciseEntry(
              id: null,
              name: exercise['name'] as String? ?? '',
              muscleGroup: exercise['muscle_group'] as String? ?? '',
              sets: (exercise['sets'] as num?)?.toInt() ?? 0,
              reps: exercise['reps'].toString(),
              weightKg: (exercise['weight_kg'] as num?)?.toDouble() ?? 0,
              restSeconds: (exercise['rest_seconds'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList();
      workouts.add(
        Workout(id: null, userId: '', date: _onlyDate(date), exercises: exercises),
      );
    }
    return workouts;
  }

  Future<void> _saveWorkouts(List<Workout> workouts) async {
    final repository = WorkoutRepository(Supabase.instance.client);
    for (final workout in workouts) {
      await repository.upsertWorkout(workout);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Importação de treinos',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Faça upload de um arquivo CSV ou JSON seguindo os modelos disponíveis em assets/samples.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.4),
                width: 1.5,
              ),
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.15),
            ),
            child: Column(
              children: [
                Icon(Icons.upload_file, size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text(_isImporting ? 'Processando...' : 'Arraste o arquivo aqui ou toque para selecionar'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isImporting ? null : _pickAndImport,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Selecionar arquivo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('Formato esperado (CSV)'),
            subtitle: Text(
              'date, exercise_name, muscle_group, sets, reps, weight_kg, rest_seconds',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: TextButton.icon(
              onPressed: () => _openSample(context, 'assets/samples/treinos.csv'),
              icon: const Icon(Icons.download),
              label: const Text('Exemplo CSV'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('Formato esperado (JSON)'),
            subtitle: const Text('[{ "date": "YYYY-MM-DD", "exercises": [...] }]'),
            trailing: TextButton.icon(
              onPressed: () => _openSample(context, 'assets/samples/treinos.json'),
              icon: const Icon(Icons.download),
              label: const Text('Exemplo JSON'),
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _statusMessage!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openSample(BuildContext context, String assetPath) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Como usar os exemplos'),
        content: Text(
          'Os arquivos de exemplo estão disponíveis no diretório do projeto em\n$assetPath. '
          'Use-os como referência para preparar suas importações.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  DateTime _onlyDate(DateTime date) => DateTime(date.year, date.month, date.day);
}

class ListEquality {
  const ListEquality();

  bool equals(List<Object?> a, List<Object?> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i]?.toString() != b[i]?.toString()) return false;
    }
    return true;
  }
}
