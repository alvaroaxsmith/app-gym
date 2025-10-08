import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/exercise_template.dart';

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
  Future<int> countUserExercises({String? searchQuery}) async {
    final allExercises = await fetchUserExercises();
    
    if (searchQuery == null || searchQuery.trim().isEmpty) {
      return allExercises.length;
    }
    
    final lowerQuery = searchQuery.toLowerCase();
    return allExercises
        .where((exercise) => exercise.name.toLowerCase().contains(lowerQuery))
        .length;
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
}
