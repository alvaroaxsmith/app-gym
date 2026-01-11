import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/exercise_template.dart';

/// Estatísticas do histórico de exercícios do usuário
class ExerciseStats {
  ExerciseStats({
    required this.totalUniqueExercises,
    this.mostPracticedExercise,
    this.mostTrainedMuscleGroup,
    this.lastWorkoutDate,
  });

  final int totalUniqueExercises;
  final ExerciseTemplate? mostPracticedExercise;
  final String? mostTrainedMuscleGroup;
  final DateTime? lastWorkoutDate;
}

class ExerciseLibraryRepository {
  ExerciseLibraryRepository(this._client);

  final SupabaseClient _client;

  User get _currentUser {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Usuário não autenticado');
    }
    return user;
  }

  /// Fetch all unique exercises for the current user with their last usage data
  Future<List<ExerciseTemplate>> fetchUserExercises() async {
    final user = _currentUser;
    
    // Query to get unique exercises with their most recent usage
    final response = await _client.rpc('get_user_exercise_history', 
      params: {'user_id_param': user.id});
    
    if (response == null) return [];
    
    final data = response as List<dynamic>;
    return data
        .map((item) => ExerciseTemplate.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetch user exercises with pagination
  Future<List<ExerciseTemplate>> fetchUserExercisesPaginated({
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortBy,
    String? muscleGroup,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final allExercises = await fetchUserExercises();
    
    // Apply search filter
    var filtered = allExercises;
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      filtered = filtered
          .where((exercise) => exercise.name.toLowerCase().contains(lowerQuery))
          .toList();
    }

    // Apply muscle group filter
    if (muscleGroup != null && muscleGroup != 'Todos') {
      filtered = filtered
          .where((exercise) => exercise.muscleGroup == muscleGroup)
          .toList();
    }

    // Apply date range filter
    if (startDate != null || endDate != null) {
      filtered = filtered.where((exercise) {
        if (exercise.lastUsedDate == null) return false;
        
        final exerciseDate = exercise.lastUsedDate!;
        if (startDate != null && exerciseDate.isBefore(startDate)) {
          return false;
        }
        if (endDate != null && exerciseDate.isAfter(endDate)) {
          return false;
        }
        return true;
      }).toList();
    }
    
    // Apply sorting
    if (sortBy == 'name') {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    } else if (sortBy == 'date') {
      filtered.sort((a, b) {
        final dateA = a.lastUsedDate ?? DateTime(1970);
        final dateB = b.lastUsedDate ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
    } else if (sortBy == 'frequency') {
      filtered.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    }
    
    // Apply pagination
    final start = page * pageSize;
    final end = start + pageSize;
    
    if (start >= filtered.length) {
      return [];
    }
    
    return filtered.sublist(
      start,
      end > filtered.length ? filtered.length : end,
    );
  }

  /// Count total user exercises
  Future<int> countUserExercises({
    String? searchQuery,
    String? muscleGroup,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final allExercises = await fetchUserExercises();
    
    var filtered = allExercises;
    
    // Apply search filter
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      filtered = filtered
          .where((exercise) => exercise.name.toLowerCase().contains(lowerQuery))
          .toList();
    }

    // Apply muscle group filter
    if (muscleGroup != null && muscleGroup != 'Todos') {
      filtered = filtered
          .where((exercise) => exercise.muscleGroup == muscleGroup)
          .toList();
    }

    // Apply date range filter
    if (startDate != null || endDate != null) {
      filtered = filtered.where((exercise) {
        if (exercise.lastUsedDate == null) return false;
        
        final exerciseDate = exercise.lastUsedDate!;
        if (startDate != null && exerciseDate.isBefore(startDate)) {
          return false;
        }
        if (endDate != null && exerciseDate.isAfter(endDate)) {
          return false;
        }
        return true;
      }).toList();
    }
    
    return filtered.length;
  }

  /// Search exercises by name (for autocomplete)
  Future<List<ExerciseTemplate>> searchExercises(String query) async {
    if (query.trim().isEmpty) {
      return fetchUserExercises();
    }
    
    final exercises = await fetchUserExercises();
    final lowerQuery = query.toLowerCase();
    
    return exercises
        .where((exercise) => exercise.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Get the most recent data for a specific exercise name
  Future<ExerciseTemplate?> getExerciseByName(String name) async {
    final exercises = await fetchUserExercises();
    try {
      return exercises.firstWhere(
        (exercise) => exercise.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get statistics about user's exercise history
  Future<ExerciseStats> getUserExerciseStats({
    String? muscleGroup,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Build query with filters
    var query = _client
        .from('exercise_entries')
        .select('exercise_name, muscle_group, workout_date')
        .eq('user_id', userId);

    // Apply filters
    if (muscleGroup != null && muscleGroup.isNotEmpty) {
      query = query.eq('muscle_group', muscleGroup);
    }
    if (startDate != null) {
      query = query.gte('workout_date', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('workout_date', endDate.toIso8601String());
    }

    final data = await query as List;
    
    if (data.isEmpty) {
      return ExerciseStats(
        totalUniqueExercises: 0,
      );
    }

    // Calculate exercise frequencies
    final exerciseCounts = <String, int>{};
    final muscleGroupCounts = <String, int>{};
    DateTime? lastWorkout;

    for (final entry in data) {
      final name = entry['exercise_name'] as String;
      final group = entry['muscle_group'] as String;
      final date = DateTime.parse(entry['workout_date'] as String);

      exerciseCounts[name] = (exerciseCounts[name] ?? 0) + 1;
      muscleGroupCounts[group] = (muscleGroupCounts[group] ?? 0) + 1;

      if (lastWorkout == null || date.isAfter(lastWorkout)) {
        lastWorkout = date;
      }
    }

    // Find most practiced exercise
    ExerciseTemplate? mostPracticed;
    if (exerciseCounts.isNotEmpty) {
      final mostPracticedName = exerciseCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      
      // Try to find the exercise details
      try {
        final exerciseData = await _client
            .from('exercise_library')
            .select()
            .eq('name', mostPracticedName)
            .maybeSingle();
        
        if (exerciseData != null) {
          mostPracticed = ExerciseTemplate.fromMap({
            ...exerciseData,
            'usage_count': exerciseCounts[mostPracticedName],
          });
        }
      } catch (e) {
        // Ignore error, just don't set mostPracticed
      }
    }

    // Find most trained muscle group
    String? mostTrainedGroup;
    if (muscleGroupCounts.isNotEmpty) {
      mostTrainedGroup = muscleGroupCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    return ExerciseStats(
      totalUniqueExercises: exerciseCounts.length,
      mostPracticedExercise: mostPracticed,
      mostTrainedMuscleGroup: mostTrainedGroup,
      lastWorkoutDate: lastWorkout,
    );
  }

  /// Delete all occurrences of an exercise from user's history
  Future<void> deleteUserExercise(String exerciseName) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Get all workout IDs for this user
    final workouts = await _client
        .from('workouts')
        .select('id')
        .eq('user_id', userId);

    if (workouts.isEmpty) return;

    final workoutIds = (workouts as List).map((w) => w['id'] as String).toList();

    // Delete all exercises with this name from user's workouts
    await _client
        .from('exercises')
        .delete()
        .eq('name', exerciseName)
        .inFilter('workout_id', workoutIds);
  }
}
