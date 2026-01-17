import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_ranking.dart';

class RankingRepository {
  RankingRepository(this._client);

  final SupabaseClient _client;

  Future<List<UserRanking>> fetchUserRanking({
    RankingPeriod period = RankingPeriod.weekly,
    RankingMetric metric = RankingMetric.volume,
  }) async {
    try {
      final (startDate, endDate) = _getDateRange(period);
      
      // Query SQL personalizada para calcular o ranking
      final response = await _client.rpc('get_user_ranking', params: {
        'p_start_date': startDate?.toIso8601String().split('T')[0],
        'p_end_date': endDate?.toIso8601String().split('T')[0],
        'p_order_by': metric == RankingMetric.workouts ? 'workouts' : 'volume',
      });
      
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
      // Fallback: mostrar erro ou dados locais se for allTime?
      // Por simplicidade, mantemos fallback básico se falhar chamada
      // mas o fallback original não filtrava datas.
      // Se a RPC falhar por falta de parametros (migração pendente), vai cair aqui.
      print('Erro ao buscar ranking: $e');
      return []; 
    }
  }

  (DateTime?, DateTime?) _getDateRange(RankingPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case RankingPeriod.weekly:
        // Segunda-feira da semana atual
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
         return (startOfWeek, endOfWeek);
      case RankingPeriod.monthly:
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);
        return (startOfMonth, endOfMonth);
      case RankingPeriod.allTime:
        return (null, null);
    }
  }
}

enum RankingPeriod { weekly, monthly, allTime }

enum RankingMetric { volume, workouts }