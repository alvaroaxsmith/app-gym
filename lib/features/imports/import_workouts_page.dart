import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui_helpers.dart';
import '../../models/exercise_entry.dart';
import '../../models/workout.dart';
import '../workouts/workout_repository.dart';

class ImportWorkoutsPage extends StatefulWidget {
  const ImportWorkoutsPage({super.key, this.onImportSuccess});

  /// Callback chamado após uma importação bem-sucedida
  final VoidCallback? onImportSuccess;

  @override
  State<ImportWorkoutsPage> createState() => _ImportWorkoutsPageState();
}

class _ImportWorkoutsPageState extends State<ImportWorkoutsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _statusMessage;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Export Logic ---

  Future<void> _exportData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Preparando exportação...';
      _hasError = false;
    });

    try {
      final repository = WorkoutRepository(Supabase.instance.client);
      final workouts = await repository.fetchAllWorkouts();

      if (workouts.isEmpty) {
        throw Exception('Nenhum treino encontrado para exportar.');
      }

      final csvData = _generateCsv(workouts);
      final filePath = await _saveCsvFile(csvData);

      if (mounted) {
        setState(() {
          _statusMessage = 'Exportação concluída! Compartilhando...';
        });

        // Share the file
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Meus treinos exportados do App Gym',
        );
        
        setState(() {
          _isLoading = false;
          _statusMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Erro: ${e.toString()}';
          _hasError = true;
        });
      }
    }
  }

  String _generateCsv(List<Workout> workouts) {
    // Header
    final List<List<dynamic>> rows = [
      [
        'Data',
        'Dia Semana',
        'Exercício',
        'Grupo Muscular',
        'Séries',
        'Repetições',
        'Peso (kg)',
        'Descanso (s)',
        'Volume Total (kg)'
      ],
    ];

    for (final workout in workouts) {
      final dateStr = workout.date.toIso8601String().split('T').first;
      final weekday = _getWeekdayName(workout.date.weekday);

      for (final exercise in workout.exercises) {
        rows.add([
          dateStr,
          weekday,
          exercise.name,
          exercise.muscleGroup,
          exercise.sets,
          exercise.reps,
          exercise.weightKg,
          exercise.restSeconds,
          exercise.volume,
        ]);
      }
    }

    return const ListToCsvConverter().convert(rows);
  }

  String _getWeekdayName(int weekday) {
    const days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return days[weekday - 1];
  }

  Future<String> _saveCsvFile(String csvContent) async {
    final directory = await getTemporaryDirectory();
    final now = DateTime.now();
    final fileName = 'treinos_${now.year}${now.month}${now.day}_${now.hour}${now.minute}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvContent);
    return file.path;
  }

  // --- Import Logic ---

  Future<void> _pickAndImport() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Lendo arquivo...';
      _hasError = false;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['csv', 'json'],
      );
      if (result == null) {
         setState(() => _isLoading = false);
         return;
      }
      if (!mounted) return;
      
      final file = result.files.single;
      
      // Validação do tamanho do arquivo (limite de 5MB)
      if (file.size > 5 * 1024 * 1024) {
        showSnack(context, 'Arquivo muito grande. Limite: 5MB', isError: true);
        setState(() => _isLoading = false);
        return;
      }
      
      if (file.bytes == null) {
        showSnack(context, 'Não foi possível ler o arquivo selecionado.', isError: true);
        setState(() => _isLoading = false);
        return;
      }
      
      // Decodificação do conteúdo (suporte a UTF-8)
      final content = utf8.decode(file.bytes!);
      final extension = file.extension?.toLowerCase();

      setState(() {
        _statusMessage = 'Processando dados...';
        // _isImporting logic removed in favor of _isLoading
      });

      List<Workout> workouts = [];
      if (extension == 'csv') {
        workouts = _parseCsv(content);
      } else if (extension == 'json') {
        workouts = _parseJson(content);
      } else {
        throw FormatException('Formato não suportado: $extension');
      }

      setState(() {
        _statusMessage = 'Salvando ${workouts.length} treinos...';
      });

      await _saveWorkouts(workouts);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Importação concluída com sucesso!';
          _hasError = false;
        });
        showSnack(context, '${workouts.length} treinos importados com sucesso!');
        widget.onImportSuccess?.call();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Erro: ${e.toString()}';
        _hasError = true;
      });
      showSnack(
        context,
        'Erro na importação: ${e.toString()}',
        isError: true,
      );
    }
  }

  List<Workout> _parseCsv(String content) {
    final rows = const CsvToListConverter(eol: '\n').convert(content, shouldParseNumbers: false);
    if (rows.isEmpty) {
      throw const FormatException('CSV vazio');
    }
    
    final header = rows.first.map((value) => value.toString().trim().toLowerCase()).toList();
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
      throw FormatException(
        'Cabeçalho CSV inválido. Esperado: ${expected.join(", ")}\nEncontrado: ${header.join(", ")}'
      );
    }
    
    final grouped = <DateTime, List<ExerciseEntry>>{};
    final errors = <String>[];
    
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      
      // Ignorar linhas vazias
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }
      
      if (row.length < expected.length) {
        errors.add('Linha ${i + 1}: número insuficiente de colunas (${row.length}/${expected.length})');
        continue;
      }
      
      try {
        final dateStr = row[0].toString().trim();
        if (dateStr.isEmpty) {
          errors.add('Linha ${i + 1}: data vazia');
          continue;
        }
        
        final date = DateTime.parse(dateStr);
        final exerciseName = row[1].toString().trim();
        
        if (exerciseName.isEmpty) {
          errors.add('Linha ${i + 1}: nome do exercício vazio');
          continue;
        }
        
        final sets = int.tryParse(row[3].toString().trim());
        if (sets == null || sets <= 0) {
          errors.add('Linha ${i + 1}: número de séries inválido (${row[3]})');
          continue;
        }
        
        final weightKg = double.tryParse(row[5].toString().trim());
        if (weightKg == null || weightKg < 0) {
          errors.add('Linha ${i + 1}: peso inválido (${row[5]})');
          continue;
        }
        
        grouped.putIfAbsent(_onlyDate(date), () => []);
        grouped[_onlyDate(date)]!.add(
          ExerciseEntry(
            id: null,
            name: exerciseName,
            muscleGroup: row[2].toString().trim(),
            sets: sets,
            reps: row[4].toString().trim(),
            weightKg: weightKg,
            restSeconds: int.tryParse(row[6].toString().trim()) ?? 0,
          ),
        );
      } catch (e) {
        errors.add('Linha ${i + 1}: erro ao processar ($e)');
      }
    }
    
    if (grouped.isEmpty && errors.isNotEmpty) {
      throw FormatException('Nenhum registro válido encontrado.\nErros:\n${errors.take(5).join("\n")}${errors.length > 5 ? "\n... e mais ${errors.length - 5} erro(s)" : ""}');
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
    dynamic json;
    try {
      json = jsonDecode(content);
    } catch (e) {
      throw FormatException('JSON inválido: ${e.toString()}');
    }
    
    if (json is! List) {
      throw const FormatException('JSON deve ser um array de treinos');
    }
    
    final workouts = <Workout>[];
    final errors = <String>[];
    
    for (var i = 0; i < json.length; i++) {
      final item = json[i];
      
      if (item is! Map<String, dynamic>) {
        errors.add('Item ${i + 1}: formato inválido (esperado objeto)');
        continue;
      }
      
      try {
        // Validação da data
        final dateStr = item['date'] as String?;
        if (dateStr == null || dateStr.trim().isEmpty) {
          errors.add('Item ${i + 1}: campo "date" ausente ou vazio');
          continue;
        }
        
        final date = DateTime.parse(dateStr);
        
        // Validação dos exercícios
        final exercisesJson = item['exercises'];
        if (exercisesJson == null) {
          errors.add('Item ${i + 1}: campo "exercises" ausente');
          continue;
        }
        
        if (exercisesJson is! List) {
          errors.add('Item ${i + 1}: "exercises" deve ser um array');
          continue;
        }
        
        if (exercisesJson.isEmpty) {
          errors.add('Item ${i + 1}: lista de exercícios vazia');
          continue;
        }
        
        final exercises = <ExerciseEntry>[];
        for (var j = 0; j < exercisesJson.length; j++) {
          final exercise = exercisesJson[j];
          
          if (exercise is! Map<String, dynamic>) {
            errors.add('Item ${i + 1}, Exercício ${j + 1}: formato inválido');
            continue;
          }
          
          final name = exercise['name'] as String?;
          if (name == null || name.trim().isEmpty) {
            errors.add('Item ${i + 1}, Exercício ${j + 1}: nome ausente ou vazio');
            continue;
          }
          
          final sets = exercise['sets'];
          if (sets == null || (sets is num && sets <= 0)) {
            errors.add('Item ${i + 1}, Exercício ${j + 1}: número de séries inválido');
            continue;
          }
          
          final weightKg = exercise['weight_kg'];
          if (weightKg != null && weightKg is num && weightKg < 0) {
            errors.add('Item ${i + 1}, Exercício ${j + 1}: peso negativo');
            continue;
          }
          
          exercises.add(
            ExerciseEntry(
              id: null,
              name: name.trim(),
              muscleGroup: (exercise['muscle_group'] as String?)?.trim() ?? '',
              sets: (sets as num).toInt(),
              reps: exercise['reps']?.toString() ?? '0',
              weightKg: (weightKg as num?)?.toDouble() ?? 0,
              restSeconds: (exercise['rest_seconds'] as num?)?.toInt() ?? 0,
            ),
          );
        }
        
        if (exercises.isNotEmpty) {
          workouts.add(
            Workout(id: null, userId: '', date: _onlyDate(date), exercises: exercises),
          );
        }
      } catch (e) {
        errors.add('Item ${i + 1}: erro ao processar ($e)');
      }
    }
    
    if (workouts.isEmpty && errors.isNotEmpty) {
      throw FormatException('Nenhum treino válido encontrado.\nErros:\n${errors.take(5).join("\n")}${errors.length > 5 ? "\n... e mais ${errors.length - 5} erro(s)" : ""}');
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(text: 'Importar', icon: Icon(Icons.download)),
            Tab(text: 'Exportar', icon: Icon(Icons.upload)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildImportTab(context),
              _buildExportTab(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImportTab(BuildContext context) {
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
            'Faça upload de um arquivo CSV ou JSON seguindo os modelos disponíveis. '
            'Clique em "Ver Exemplo" para visualizar e copiar o formato correto.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          
          // Seção de ajuda
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Dicas importantes',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTipItem(context, 'O arquivo deve ter no máximo 5MB'),
                  _buildTipItem(context, 'Datas devem estar no formato YYYY-MM-DD (ex: 2025-01-11)'),
                  _buildTipItem(context, 'Valores numéricos devem usar ponto como separador decimal (ex: 12.5)'),
                  _buildTipItem(context, 'Cada treino deve ter pelo menos um exercício'),
                ],
              ),
            ),
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
                Text(_isLoading ? 'Processando...' : 'Arraste o arquivo aqui ou toque para selecionar'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _pickAndImport,
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
              onPressed: () => _showSampleDialog(context, 'assets/samples/treinos.csv', 'CSV'),
              icon: const Icon(Icons.visibility),
              label: const Text('Ver Exemplo'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('Formato esperado (JSON)'),
            subtitle: const Text('[{ "date": "YYYY-MM-DD", "exercises": [...] }]'),
            trailing: TextButton.icon(
              onPressed: () => _showSampleDialog(context, 'assets/samples/treinos.json', 'JSON'),
              icon: const Icon(Icons.visibility),
              label: const Text('Ver Exemplo'),
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _hasError
                    ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3)
                    : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                border: Border.all(
                  color: _hasError
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _hasError ? Icons.error_outline : Icons.check_circle_outline,
                    color: _hasError
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _hasError
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_hasError) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => widget.onImportSuccess?.call(),
                icon: const Icon(Icons.fitness_center),
                label: const Text('Ver Meus Exercícios'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildExportTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exportar dados',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 8),
          Text(
            'Exporte todo o seu histórico de treinos para um arquivo CSV. Você pode abrir este arquivo no Excel ou Google Sheets.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          
          if (_isLoading) ...[
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage ?? 'Processando...'),
                ],
              ),
            ),
          ] else ...[
             if (_hasError)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage ?? 'Erro desconhecido',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

             if (_statusMessage != null && !_hasError)
               Container(
                 margin: const EdgeInsets.only(bottom: 24),
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: Theme.of(context).colorScheme.tertiaryContainer,
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Row(
                   children: [
                     Icon(
                       Icons.check_circle,
                       color: Theme.of(context).colorScheme.onTertiaryContainer,
                     ),
                     const SizedBox(width: 12),
                     Expanded(
                       child: Text(
                         _statusMessage!,
                         style: TextStyle(
                           color: Theme.of(context).colorScheme.onTertiaryContainer,
                         ),
                       ),
                     ),
                   ],
                 ),
               ),

            Center(
              child: FilledButton.icon(
                onPressed: _exportData,
                icon: const Icon(Icons.share),
                label: const Text('Gerar e Compartilhar CSV'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showSampleDialog(BuildContext context, String assetPath, String format) async {
    try {
      // Carregar o conteúdo do arquivo de exemplo
      final content = await rootBundle.loadString(assetPath);
      
      if (!context.mounted) return;
      
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Exemplo $format'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Use este formato como referência:',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: SelectableText(
                      content,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: content));
                if (context.mounted) {
                  showSnack(context, 'Exemplo copiado para a área de transferência!');
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showSnack(
        context,
        'Erro ao carregar exemplo: ${e.toString()}',
        isError: true,
      );
    }
  }

  Widget _buildTipItem(BuildContext context, String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: Theme.of(context).textTheme.bodySmall,
            ),
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