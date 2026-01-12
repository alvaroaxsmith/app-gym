import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/training_plan.dart';

class TrainingPlanRepository {
  final SupabaseClient _client;

  TrainingPlanRepository(this._client);

  Future<List<TrainingPlan>> fetchPlans() async {
    final userId = _client.auth.currentUser!.id;
    final response = await _client
        .from('training_plans')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final data = response as List<dynamic>;
    return data.map((e) => TrainingPlan.fromMap(e)).toList();
  }

  Future<TrainingPlan> createPlan(TrainingPlan plan) async {
    // 1. Insert Plan
    final planData = await _client
        .from('training_plans')
        .insert(plan.toMap())
        .select()
        .single();
    
    final createdPlan = TrainingPlan.fromMap(planData);

    // 2. Insert Weeks & Deep Hierarcy
    if (plan.weeks.isNotEmpty) {
      for (final week in plan.weeks) {
         // Insert Week and get ID
         final weekData = await _client
            .from('training_plan_weeks')
            .insert(week.toMap(createdPlan.id!))
            .select()
            .single();
         final createdWeekId = weekData['id'] as String;

         // 3. Insert Workouts if any
         if (week.workouts.isNotEmpty) {
           for (final workout in week.workouts) {
             final workoutData = await _client
                .from('training_plan_workouts')
                .insert(workout.toMap(createdWeekId))
                .select()
                .single();
             final createdWorkoutId = workoutData['id'] as String;

             // 4. Insert Items if any
             if (workout.items.isNotEmpty) {
                final itemsPayload = workout.items.map((i) => i.toMap(createdWorkoutId)).toList();
                await _client.from('training_plan_workout_items').insert(itemsPayload);
             }
           }
         }
      }
    }

    return createdPlan;
  }

  Future<TrainingPlan> fetchPlanDetails(String planId) async {
    final response = await _client.from('training_plans').select('''
          *,
          weeks:training_plan_weeks(
            *,
            training_plan_workouts(
              *,
              items:training_plan_workout_items(
                *,
                exercise_library(name)
              )
            )
          )
        ''').eq('id', planId).single();

    final plan = TrainingPlan.fromMap(response);
    // Supabase returns weeks in the main map under 'weeks' key if we alias it, or 'training_plan_weeks'
    // But currently TrainingPlan.fromMap doesn't parse 'weeks' automatically deep down unless we change it.
    // Actually, TrainingPlan.fromMap is shallow in current code (check previous file read).
    // Wait, I should verify TrainingPlan.fromMap implementation.
    // In lib/models/training_plan.dart:
    // factory TrainingPlan.fromMap(Map<String, dynamic> map) {
    //   ...
    //   weeks: (map['weeks'] ... ??? No, it wasn't there in first read)
    // }

    // Let's create a richer parser here or update the Model.
    // Better to update the Model's fromMap to handle 'weeks' or manually handle it here.
    // Given the previous file read of TrainingPlan.fromMap, it DID NOT have 'weeks' parsing logic.
    // So I need to parse it here.

    final weeksData = (response['weeks'] as List<dynamic>?) ?? [];
    final weeks = weeksData
        .map((w) => TrainingPlanWeek.fromMap(w as Map<String, dynamic>))
        .toList();
    
    // Sort weeks
    weeks.sort((a,b) => a.weekNumber.compareTo(b.weekNumber));

    return plan.copyWith(weeks: weeks);
  }

  Future<void> addWorkoutToWeek(String weekId, TrainingPlanWorkout workout) async {
    await _client.from('training_plan_workouts').insert(workout.toMap(weekId));
  }

  Future<void> deleteWorkout(String workoutId) async {
    await _client.from('training_plan_workouts').delete().eq('id', workoutId);
  }

  Future<void> deletePlan(String planId) async {
    await _client.from('training_plans').delete().eq('id', planId);
  }

  Future<void> addWorkoutItem(String workoutId, TrainingPlanWorkoutItem item) async {
    await _client
        .from('training_plan_workout_items')
        .insert(item.toMap(workoutId));
  }

  Future<void> deleteWorkoutItem(String itemId) async {
    await _client.from('training_plan_workout_items').delete().eq('id', itemId);
  }

  Future<void> updateWorkoutItem(TrainingPlanWorkoutItem item) async {
    await _client.from('training_plan_workout_items').update({
      'sets': item.sets,
       'reps': item.reps,
       'rpe': item.rpe,
       'weight': item.weight,
       'rest_seconds': item.restSeconds,
       'notes': item.notes,
    }).eq('id', item.id!);
  }

  Future<void> logWorkoutFromRoutine(TrainingPlanWorkout routine) async {
    final userId = _client.auth.currentUser!.id;
    final now = DateTime.now();

    // 1. Create Workout Log
    final workoutRes = await _client.from('workouts').insert({
      'user_id': userId,
      'date': now.toIso8601String(), // 'date' column is type DATE, might truncate time part but ISO string is usually ok
    }).select().single();
    
    final workoutId = workoutRes['id'] as String;

    // 2. Log Exercises (Assume Planned = Executed for Quick Log)
    if (routine.items.isNotEmpty) {
      // 2a. Fetch Exercise Details (name, muscle_group) from Library
      final exerciseIds = routine.items.map((e) => e.exerciseId).toSet().toList();
      final libraryRes = await _client
          .from('exercise_library')
          .select('id, name, muscle_group')
          .filter('id', 'in', exerciseIds); // fixed from .in_
      
      final libraryMap = {
        for (var item in (libraryRes as List))
          item['id'] as String: item
      };

      final List<Map<String, dynamic>> entries = [];

      for (var item in routine.items) {
        final libInfo = libraryMap[item.exerciseId];
        if (libInfo != null) {
          entries.add({
            'workout_id': workoutId,
            'name': libInfo['name'],
            'muscle_group': libInfo['muscle_group'],
            'sets': item.sets,
            'reps': item.reps ?? '0',
            'weight_kg': _parseWeight(item.weight), 
            'rest_seconds': item.restSeconds ?? 60,
            'rpe': _parseRpe(item.rpe),
          });
        }
      }

      if (entries.isNotEmpty) {
        await _client.from('exercises').insert(entries);
      }
    }
  }

  Future<void> logSingleExerciseExecution(TrainingPlanWorkoutItem planItem) async {
    final userId = _client.auth.currentUser!.id;
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0]; // YYYY-MM-DD

    // 1. Find or Create "Active Workout" for TODAY
    // We try to find a workout created TODAY for this user.
    // If multiple exist, we pick the latest one or create new?
    // For simplicity: Pick the latest one created today. If none, create one.
    
    final workoutRes = await _client
        .from('workouts')
        .select()
        .eq('user_id', userId)
        .eq('date', todayStr)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    
    String workoutId;
    if (workoutRes != null) {
      workoutId = workoutRes['id'] as String;
    } else {
      final newWorkout = await _client.from('workouts').insert({
        'user_id': userId,
        'date': todayStr,
      }).select().single();
      workoutId = newWorkout['id'] as String;
    }

    // 2. Insert Exercise
    // Need to fetch details from library?
    // We have item.exerciseId.
    final libRes = await _client.from('exercise_library').select('name, muscle_group').eq('id', planItem.exerciseId).single();
    
    await _client.from('exercises').insert({
      'workout_id': workoutId,
      'name': libRes['name'],
      'muscle_group': libRes['muscle_group'],
      'sets': planItem.sets,
      'reps': planItem.reps ?? '10',
      'weight_kg': _parseWeight(planItem.weight),
      'rest_seconds': planItem.restSeconds ?? 60,
      'rpe': _parseRpe(planItem.rpe),
    });
  }

  double _parseRpe(String? val) {
    if (val == null || val.isEmpty) return 0;
    // Extract first number (e.g. "RPE 8" -> 8, "7-8" -> 7)
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(val);
    if (match != null) {
      final num = double.tryParse(match.group(1)?.replaceAll(',', '.') ?? '') ?? 0;
      if (num > 10) return 10;
      return num;
    }
    return 0;
  }

  // Helper to parse weight from string (e.g. "50kg" -> 50.0)
  // Standardizes metric collection for Dashboard
  double _parseWeight(String? val) {
    if (val == null || val.isEmpty) return 0;
    
    String text = val.toLowerCase().trim();

    // 1. Ignore Percentages (cannot determine absolute load without 1RM context)
    // Prevents inputs like "70% 1RM" from being parsed as "701" or "70" which distorts volume.
    if (text.contains('%')) return 0;

    // 2. Look for explicit "kg" pattern (e.g., "20kg", "20 kg")
    final kgMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*kg').firstMatch(text);
    if (kgMatch != null) {
      return double.tryParse(kgMatch.group(1)?.replaceAll(',', '.') ?? '') ?? 0;
    }

    // 3. Look for explicit "halter" or "dumbbells" logic if number exists before/after? 
    // Simplify: Just try to parse the whole string as a number first.
    final cleanNumeric = double.tryParse(text.replaceAll(',', '.'));
    if (cleanNumeric != null) return cleanNumeric;

    // 4. Fallback: Extract first contiguous number found
    // Risk: "3x10" -> 3. But usually weight field shouldn't have sets/reps.
    final numberMatch = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(text);
    if (numberMatch != null) {
      return double.tryParse(numberMatch.group(1)?.replaceAll(',', '.') ?? '') ?? 0;
    }

    return 0;
  }
}
