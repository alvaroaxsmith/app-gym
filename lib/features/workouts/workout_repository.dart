import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/exercise_entry.dart';
import '../../models/workout.dart';

class WorkoutRepository {
  WorkoutRepository(this._client);

  final SupabaseClient _client;

  User get _currentUser {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Usuário não autenticado');
    }
    return user;
  }

  Future<Map<DateTime, Workout>> fetchWorkoutsForMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final workouts = await fetchWorkoutsBetween(start, end);
    return {
      for (final workout in workouts) _onlyDate(workout.date): workout,
    };
  }

  Future<List<Workout>> fetchWorkoutsBetween(DateTime start, DateTime end) async {
    final user = _currentUser;
    final response = await _client
        .from('workouts')
        .select('id, user_id, date, exercises (id, name, muscle_group, sets, reps, weight_kg, rest_seconds)')
        .eq('user_id', user.id)
        .gte('date', DateFormat('yyyy-MM-dd').format(start))
        .lte('date', DateFormat('yyyy-MM-dd').format(end))
        .order('date');

    final data = response as List<dynamic>;
    return data.map((item) => Workout.fromMap(item as Map<String, dynamic>)).toList();
  }

  Future<Workout?> fetchWorkoutByDate(DateTime date) async {
    final user = _currentUser;
    final response = await _client
        .from('workouts')
        .select('id, user_id, date, exercises (id, name, muscle_group, sets, reps, weight_kg, rest_seconds)')
        .eq('user_id', user.id)
        .eq('date', DateFormat('yyyy-MM-dd').format(date))
        .maybeSingle();
    if (response == null) return null;
    return Workout.fromMap(response);
  }

  Future<Workout> upsertWorkout(Workout workout) async {
    final user = _currentUser;
    final payload = workout.copyWith(userId: user.id).toWorkoutRow();
    Map<String, dynamic> row;
    if (workout.id == null) {
      row = await _client
          .from('workouts')
          .insert(payload)
          .select('id, user_id, date')
          .single();
    } else {
      row = await _client
          .from('workouts')
          .update(payload)
      .eq('id', workout.id!)
          .select('id, user_id, date')
          .single();
    }

    final workoutId = row['id'] as String;
    await _client.from('exercises').delete().eq('workout_id', workoutId);
    if (workout.exercises.isNotEmpty) {
      final exercisesPayload = workout.exercises
          .map((exercise) => exercise.toMap(workoutId))
          .toList();
      await _client.from('exercises').insert(exercisesPayload);
    }

    final fullWorkout = await fetchWorkoutById(workoutId);
    if (fullWorkout == null) {
      throw StateError('Falha ao recuperar treino recém criado');
    }
    return fullWorkout;
  }

  Future<void> deleteWorkout(String workoutId) async {
    await _client.from('workouts').delete().eq('id', workoutId);
  }

  Future<Workout?> fetchWorkoutById(String id) async {
    final user = _currentUser;
    final response = await _client
        .from('workouts')
        .select('id, user_id, date, exercises (id, name, muscle_group, sets, reps, weight_kg, rest_seconds)')
        .eq('user_id', user.id)
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return Workout.fromMap(response);
  }

  DateTime _onlyDate(DateTime date) => DateTime(date.year, date.month, date.day);
}
