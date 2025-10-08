import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/exercise_library_item.dart';

class ExerciseLibraryDatabaseRepository {
  ExerciseLibraryDatabaseRepository(this._client);

  final SupabaseClient _client;

  /// Fetch all exercises from the library
  Future<List<ExerciseLibraryItem>> fetchAllExercises() async {
    final response = await _client
        .from('exercise_library')
        .select()
        .order('name');

    final data = response as List<dynamic>;
    return data
        .map((item) => ExerciseLibraryItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetch exercises with pagination
  Future<List<ExerciseLibraryItem>> fetchExercisesPaginated({
    required int page,
    required int pageSize,
    String? muscleGroup,
    String? searchQuery,
  }) async {
    var query = _client
        .from('exercise_library')
        .select();

    // Apply filters
    if (muscleGroup != null && muscleGroup != 'Todos') {
      query = query.eq('muscle_group', muscleGroup);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.ilike('name', '%$searchQuery%');
    }

    // Apply pagination
    final start = page * pageSize;
    final end = start + pageSize - 1;

    final response = await query
        .order('name')
        .range(start, end);

    final data = response as List<dynamic>;
    return data
        .map((item) => ExerciseLibraryItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Count total exercises (for pagination)
  Future<int> countExercises({
    String? muscleGroup,
    String? searchQuery,
  }) async {
    var query = _client
        .from('exercise_library')
        .select('id');

    // Apply filters
    if (muscleGroup != null && muscleGroup != 'Todos') {
      query = query.eq('muscle_group', muscleGroup);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.ilike('name', '%$searchQuery%');
    }

    final response = await query;
    final data = response as List<dynamic>;
    return data.length;
  }

  /// Fetch exercises filtered by muscle group
  Future<List<ExerciseLibraryItem>> fetchExercisesByMuscleGroup(String muscleGroup) async {
    final response = await _client
        .from('exercise_library')
        .select()
        .eq('muscle_group', muscleGroup)
        .order('name');

    final data = response as List<dynamic>;
    return data
        .map((item) => ExerciseLibraryItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Search exercises by name
  Future<List<ExerciseLibraryItem>> searchExercises(String query) async {
    if (query.trim().isEmpty) {
      return fetchAllExercises();
    }

    final response = await _client
        .from('exercise_library')
        .select()
        .ilike('name', '%$query%')
        .order('name');

    final data = response as List<dynamic>;
    return data
        .map((item) => ExerciseLibraryItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Get exercise by ID
  Future<ExerciseLibraryItem?> getExerciseById(String id) async {
    final response = await _client
        .from('exercise_library')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return ExerciseLibraryItem.fromMap(response);
  }
}
