import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_ranking.dart';

class RankingRepository {
  RankingRepository(this._client);

  final SupabaseClient _client;

  Future<List<UserRanking>> fetchUserRanking() async {
    try {
      // Query SQL personalizada para calcular o volume total por usuário
      final response = await _client.rpc('get_user_ranking');
      
      final data = response as List<dynamic>;
      return data
          .asMap()
          .entries
          .map((entry) => UserRanking.fromMap(
                entry.value as Map<String, dynamic>,
                entry.key + 1, // position (1-indexed)
              ))
          .toList();
    } catch (e) {
      // Fallback: buscar dados manualmente se a function RPC não existir
      return await _fetchUserRankingFallback();
    }
  }

  Future<List<UserRanking>> _fetchUserRankingFallback() async {
    // Para o fallback, vamos mostrar apenas o usuário atual
    // Em uma implementação completa, seria necessário ter uma view ou 
    // política de segurança que permita ver dados agregados de outros usuários
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return [];

    // Buscar workouts do usuário atual
    final workoutsResponse = await _client
        .from('workouts')
        .select('''
          user_id,
          exercises (
            sets,
            reps,
            weight_kg
          )
        ''')
        .eq('user_id', currentUser.id);

    double totalVolume = 0;
    int totalWorkouts = workoutsResponse.length;

    for (final workout in workoutsResponse) {
      final exercises = workout['exercises'] as List<dynamic>;
      
      for (final exercise in exercises) {
        final sets = exercise['sets'] as int;
        final reps = _parseReps(exercise['reps'] as String);
        final weightKg = (exercise['weight_kg'] as num).toDouble();
        
        totalVolume += sets * reps * weightKg;
      }
    }

    // Buscar perfil do usuário
    final profileResponse = await _client
        .from('profiles')
        .select('full_name')
        .eq('id', currentUser.id)
        .maybeSingle();

    return [
      UserRanking(
        userId: currentUser.id,
        email: currentUser.email ?? '',
        displayName: profileResponse?['full_name'] as String?,
        totalVolume: totalVolume,
        totalWorkouts: totalWorkouts,
        position: 1,
      ),
    ];
  }

  double _parseReps(String reps) {
    final parsed = double.tryParse(reps);
    if (parsed != null) {
      return parsed;
    }
    final match = RegExp(r"(\d+)").allMatches(reps);
    if (match.isEmpty) {
      return 0;
    }
    return double.parse(match.first.group(1)!);
  }
}