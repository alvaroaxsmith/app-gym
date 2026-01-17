import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui_helpers.dart';
import '../../models/training_plan.dart';
import '../../models/exercise_library_item.dart';
import '../exercises/exercise_library_database_repository.dart';
import 'training_plan_repository.dart';

class CreatePlanPage extends StatefulWidget {
  const CreatePlanPage({super.key});

  @override
  State<CreatePlanPage> createState() => _CreatePlanPageState();
}

class _CreatePlanPageState extends State<CreatePlanPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  
  TrainingGoal _selectedGoal = TrainingGoal.hypertrophy;
  int _durationWeeks = 4;
  DateTime _startDate = DateTime.now();
  bool _isLoading = false;

  // New templates
  String _selectedSplit = 'empty'; // 'empty', 'upper_lower'
  List<ExerciseLibraryItem> _libraryExercises = [];

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    try {
      final repo = ExerciseLibraryDatabaseRepository(Supabase.instance.client);
      final ex = await repo.fetchAllExercises();
      if (mounted) setState(() => _libraryExercises = ex);
    } catch (e) {
      // Slient fail ok here
    }
  }

  String? _findExerciseId(String partialName) {
    // Simple heuristic search
    final normalized = partialName.toLowerCase();
    try {
      final match = _libraryExercises.firstWhere((e) => e.name.toLowerCase().contains(normalized));
      return match.id;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final repository = TrainingPlanRepository(Supabase.instance.client);
      
      // Auto-generate weeks logic based on user story
      final weeks = List.generate(_durationWeeks, (index) {
        final weekNum = index + 1;
        final isLastWeek = weekNum == _durationWeeks;
        
        // Logic de periodizacao simples
        // Inicio: MEV (Volume Minimo)
        // Meio: MAV (Volume Adaptativo)
        // Fim: Deload
        
        String label;
        double minRpe;
        double maxRpe;
        bool isDeload = false;
        String notes;

        if (isLastWeek) {
          label = 'Semana $weekNum - Deload';
          minRpe = 5;
          maxRpe = 6;
          isDeload = true;
          notes = 'Reduza o volume em 50% e a intensidade. Descanse para dissipar a fadiga.';
        } else if (weekNum == 1) {
          label = 'Semana $weekNum - Aclimatação (MEV)';
          minRpe = 6;
          maxRpe = 7;
          notes = 'Encontre o Mínimo Volume Efetivo. Não vá até a falha total.';
        } else {
          // Progressão
          label = 'Semana $weekNum - Progressão (MAV)'; // Semana 2, 3...
          // Aumenta RPE gradualmente
          double baseRpe = 7 + ((weekNum - 1) * 0.5); // ex: Sem2=7.5, Sem3=8.0
          if (baseRpe > 9) baseRpe = 9;
          
          minRpe = baseRpe;
          maxRpe = baseRpe + 1;
          if (maxRpe > 10) maxRpe = 10;
          
          if (weekNum == _durationWeeks - 1) {
             label = 'Semana $weekNum - Overreach (MRV)';
             notes = 'Semana de choque. Vá próximo à falha. Prepare-se para o Deload.';
             minRpe = 9;
             maxRpe = 10;
          } else {
             notes = 'Aumente cargas ou reps. Busque sobrecarga progressiva.';
          }
        }

        // Generate Workouts if Template is selected
        List<TrainingPlanWorkout> dayWorkouts = [];
        if (_selectedSplit == 'upper_lower') {
           // Logic from User Request
           // Adaptation (Week 1): 2 sets, RPE 6-7
           // Progression: +1 set (so 3 sets), RPE 7-9
           // Overreach (Last - 1): Max sets (4-5), RPE 9-10
           // Deload: 50% volume (2 sets), RPE 5-6
           
           int targetSets = 3;
           String targetRpe = '${minRpe.floor()}-${maxRpe.floor()}';
           
           if (weekNum == 1) targetSets = 2;
           if (isLastWeek) { targetSets = 2; targetRpe = '5-6'; }
           if (weekNum == _durationWeeks - 1) targetSets = 5; // MRV week

           // Define Exercises (IDs fetched by fuzzy name)
           final benchId = _findExerciseId('supino reto');
           final rowId = _findExerciseId('remada curvada');
           final pressId = _findExerciseId('desenvolvimento');
           final squatId = _findExerciseId('agachamento');
           final stiffId = _findExerciseId('stiff');
           final legId = _findExerciseId('leg press');

           // Upper A
           // Note: We only add item if exercise is found in library
           final upperAItems = <TrainingPlanWorkoutItem>[];
           if (benchId != null) upperAItems.add(TrainingPlanWorkoutItem(exerciseId: benchId, sets: targetSets, rpe: targetRpe, reps: '8-12', sortOrder: 1));
           if (rowId != null) upperAItems.add(TrainingPlanWorkoutItem(exerciseId: rowId, sets: targetSets, rpe: targetRpe, reps: '8-12', sortOrder: 2));
           if (pressId != null) upperAItems.add(TrainingPlanWorkoutItem(exerciseId: pressId, sets: targetSets, rpe: targetRpe, reps: '10-12', sortOrder: 3));

           dayWorkouts.add(TrainingPlanWorkout(
             name: 'Superior A', 
             description: 'Foco em Empurrar/Puxar Horizontal',
             dayIndex: 0, // Monday
             items: upperAItems,
           ));

           // Lower A
           final lowerAItems = <TrainingPlanWorkoutItem>[];
           if (squatId != null) lowerAItems.add(TrainingPlanWorkoutItem(exerciseId: squatId, sets: targetSets, rpe: targetRpe, reps: '6-8', sortOrder: 1));
           if (stiffId != null) lowerAItems.add(TrainingPlanWorkoutItem(exerciseId: stiffId, sets: targetSets, rpe: targetRpe, reps: '8-10', sortOrder: 2));
           if (legId != null) lowerAItems.add(TrainingPlanWorkoutItem(exerciseId: legId, sets: targetSets, rpe: targetRpe, reps: '10-12', sortOrder: 3));

           dayWorkouts.add(TrainingPlanWorkout(
             name: 'Inferior A', 
             description: 'Foco em Cadeia Anterior/Posterior',
             dayIndex: 1, // Tuesday
             items: lowerAItems
           ));
           
           // Simply duplication for B workouts for MVP, just changing name
           dayWorkouts.add(TrainingPlanWorkout(
             name: 'Superior B', 
             description: 'Foco em Hipertrofia (Variação)',
             dayIndex: 3, // Thursday
             items: upperAItems.map((e) => TrainingPlanWorkoutItem( // Copy logic needed ideally, but re-instantiating works
                exerciseId: e.exerciseId,
                sets: targetSets,
                rpe: targetRpe,
                reps: e.reps,
                sortOrder: e.sortOrder
             )).toList(),
           ));
           
           dayWorkouts.add(TrainingPlanWorkout(
             name: 'Inferior B', 
             description: 'Foco em Volume de Pernas',
             dayIndex: 4, // Friday
             items: lowerAItems.map((e) => TrainingPlanWorkoutItem(
                exerciseId: e.exerciseId,
                sets: targetSets,
                rpe: targetRpe,
                reps: e.reps,
                sortOrder: e.sortOrder
             )).toList(),
           ));
        }

        return TrainingPlanWeek(
          weekNumber: weekNum,
          label: label,
          targetRpeMin: minRpe,
          targetRpeMax: maxRpe,
          isDeload: isDeload,
          notes: notes,
          workouts: dayWorkouts,
        );
      });

      final plan = TrainingPlan(
        userId: Supabase.instance.client.auth.currentUser!.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        goal: _selectedGoal,
        startDate: _startDate,
        durationWeeks: _durationWeeks,
        weeks: weeks,
      );

      await repository.createPlan(plan);
      
      if (mounted) {
        Navigator.pop(context, true);
        showSnack(context, 'Plano criado com sucesso! Boa jornada.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showSnack(context, 'Erro ao criar plano: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Plano de Treino')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detalhes do Planejamento',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Defina a estrutura do seu próximo bloco de treinamento. O sistema irá sugerir automaticamente uma periodização com base nos princípios de MEV/MRV.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome do Plano',
                  hintText: 'Ex: Hipertrofia Bloco 1',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Informe um nome' : null,
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<TrainingGoal>(
                value: _selectedGoal,
                decoration: const InputDecoration(
                  labelText: 'Objetivo Principal',
                  border: OutlineInputBorder(),
                ),
                items: TrainingGoal.values.map((g) {
                  return DropdownMenuItem(
                    value: g,
                    child: Text(g.label),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedGoal = v!),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_selectedGoal.description, style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text('Duração (Semanas)', style: Theme.of(context).textTheme.titleMedium),
              Slider(
                value: _durationWeeks.toDouble(),
                min: 4,
                max: 12,
                divisions: 8,
                label: '$_durationWeeks semanas',
                onChanged: (val) => setState(() => _durationWeeks = val.round()),
              ),
              Center(child: Text('$_durationWeeks semanas (Recomendado: 4-6)')),
              
              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                value: _selectedSplit,
                decoration: const InputDecoration(
                  labelText: 'Estrutura Inicial de Treino',
                  border: OutlineInputBorder(),
                ),
                items: const [
                   DropdownMenuItem(value: 'empty', child: Text('Vazio (Montar do zero)')),
                   DropdownMenuItem(value: 'upper_lower', child: Text('Upper / Lower (4 dias)')),
                ],
                onChanged: (v) => setState(() => _selectedSplit = v!),
              ),
              const SizedBox(height: 8),
              if (_selectedSplit == 'upper_lower')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: const Text('Essa estrutura cria 4 treinos semanais (Superior A, Inferior A, Superior B, Inferior B) e ajusta o volume automaticamente conforme a fase do mesociclo (MEV -> MAV -> MRV -> Deload).', style: TextStyle(fontSize: 12)),
                ),

              const SizedBox(height: 24),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notas / Observações',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading 
                    ? const CircularProgressIndicator()
                    : const Text('GERAR PLANO'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
