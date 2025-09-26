class UserRanking {
  UserRanking({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.totalVolume,
    required this.totalWorkouts,
    required this.position,
  });

  final String userId;
  final String email;
  final String? displayName;
  final double totalVolume;
  final int totalWorkouts;
  final int position;

  String get name => displayName ?? email.split('@').first;

  factory UserRanking.fromMap(Map<String, dynamic> map, int position) {
    return UserRanking(
      userId: map['user_id'] as String,
      email: map['email'] as String? ?? '',
      displayName: map['display_name'] as String?,
      totalVolume: (map['total_volume'] as num?)?.toDouble() ?? 0.0,
      totalWorkouts: (map['total_workouts'] as num?)?.toInt() ?? 0,
      position: position,
    );
  }
}