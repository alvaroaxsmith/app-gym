import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/custom_exercise.dart';

class CustomExerciseRepository {
  CustomExerciseRepository(this._client);

  final SupabaseClient _client;

  /// Busca todos os exercícios personalizados do usuário atual
  Future<List<CustomExercise>> fetchUserCustomExercises({
    String? searchQuery,
    String? muscleGroup,
  }) async {
    final initialQuery = _client
        .from('user_custom_exercises')
        .select()
        .eq('user_id', _client.auth.currentUser!.id);

    dynamic query = initialQuery;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('name', '%$searchQuery%');
    }

    if (muscleGroup != null && muscleGroup.isNotEmpty && muscleGroup != 'Todos') {
      query = query.eq('muscle_group', muscleGroup);
    }

    query = query.order('name', ascending: true);

    final response = await query;
    return (response as List<dynamic>)
        .map((item) => CustomExercise.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Cria um novo exercício personalizado
  Future<CustomExercise> createCustomExercise(CustomExercise exercise) async {
    final response = await _client
        .from('user_custom_exercises')
        .insert(exercise.toInsertMap())
        .select()
        .single();

    return CustomExercise.fromMap(response);
  }

  /// Atualiza um exercício personalizado existente
  Future<CustomExercise> updateCustomExercise(CustomExercise exercise) async {
    final response = await _client
        .from('user_custom_exercises')
        .update(exercise.toUpdateMap())
        .eq('id', exercise.id)
        .eq('user_id', _client.auth.currentUser!.id)
        .select()
        .single();

    return CustomExercise.fromMap(response);
  }

  /// Deleta um exercício personalizado
  Future<void> deleteCustomExercise(String exerciseId) async {
    await _client
        .from('user_custom_exercises')
        .delete()
        .eq('id', exerciseId)
        .eq('user_id', _client.auth.currentUser!.id);
  }

  /// Busca um exercício personalizado por ID
  Future<CustomExercise?> getCustomExerciseById(String exerciseId) async {
    final response = await _client
        .from('user_custom_exercises')
        .select()
        .eq('id', exerciseId)
        .eq('user_id', _client.auth.currentUser!.id)
        .maybeSingle();

    if (response == null) return null;
    return CustomExercise.fromMap(response);
  }

  /// Verifica se já existe um exercício com esse nome para o usuário
  Future<bool> exerciseNameExists(String name, {String? excludeId}) async {
    var query = _client
        .from('user_custom_exercises')
        .select('id')
        .eq('user_id', _client.auth.currentUser!.id)
        .ilike('name', name);

    if (excludeId != null) {
      query = query.neq('id', excludeId);
    }

    final response = await query;
    return (response as List<dynamic>).isNotEmpty;
  }

  /// Conta total de exercícios personalizados do usuário
  Future<int> countUserCustomExercises({
    String? searchQuery,
    String? muscleGroup,
  }) async {
    final exercises = await fetchUserCustomExercises(
      searchQuery: searchQuery,
      muscleGroup: muscleGroup,
    );
    return exercises.length;
  }
}
