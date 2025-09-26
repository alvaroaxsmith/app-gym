import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui_helpers.dart';
import '../../models/user_ranking.dart';
import 'ranking_repository.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  final _repository = RankingRepository(Supabase.instance.client);
  List<UserRanking>? _rankings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRankings();
  }

  Future<void> _loadRankings() async {
    try {
      final rankings = await _repository.fetchUserRanking();
      if (mounted) {
        setState(() {
          _rankings = rankings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        showSnack(context, 'Erro ao carregar ranking: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_rankings == null || _rankings!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nenhum usuário encontrado',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Comece a treinar para aparecer no ranking!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRankings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rankings!.length,
        itemBuilder: (context, index) {
          final user = _rankings![index];
          return _buildRankingCard(user);
        },
      ),
    );
  }

  Widget _buildRankingCard(UserRanking user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: user.position <= 3 ? 8 : 2,
      child: Container(
        decoration: user.position <= 3 
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: _getGradientForPosition(user.position),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Posição e Medal
              SizedBox(
                width: 60,
                child: _buildPositionWidget(user.position),
              ),
              const SizedBox(width: 16),
              
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  user.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Informações do usuário
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: user.position <= 3 ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user.totalWorkouts} treino${user.totalWorkouts != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        color: user.position <= 3 ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Volume total
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_formatVolume(user.totalVolume)} kg',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: user.position <= 3 ? Colors.white : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    'Volume total',
                    style: TextStyle(
                      fontSize: 12,
                      color: user.position <= 3 ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPositionWidget(int position) {
    if (position <= 3) {
      return Column(
        children: [
          _getMedalIcon(position),
          const SizedBox(height: 4),
          Text(
            '$position°',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      );
    }

    return Text(
      '$position°',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _getMedalIcon(int position) {
    IconData icon = Icons.emoji_events;
    Color color;
    
    switch (position) {
      case 1:
        color = const Color(0xFFFFD700); // Ouro
        break;
      case 2:
        color = const Color(0xFFC0C0C0); // Prata
        break;
      case 3:
        color = const Color(0xFFCD7F32); // Bronze
        break;
      default:
        color = Colors.grey;
    }

    return Icon(
      icon,
      size: 32,
      color: color,
    );
  }

  LinearGradient? _getGradientForPosition(int position) {
    switch (position) {
      case 1:
        return const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 2:
        return const LinearGradient(
          colors: [Color(0xFFC0C0C0), Color(0xFF808080)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 3:
        return const LinearGradient(
          colors: [Color(0xFFCD7F32), Color(0xFF8B4513)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return null;
    }
  }

  String _formatVolume(double volume) {
    if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    } else {
      return volume.toStringAsFixed(0);
    }
  }
}