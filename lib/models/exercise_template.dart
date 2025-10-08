/// Represents a template/history of an exercise
/// Used for autocomplete and exercise library
class ExerciseTemplate {
  ExerciseTemplate({
    required this.name,
    required this.muscleGroup,
    this.lastSets,
    this.lastReps,
    this.lastWeightKg,
    this.lastRestSeconds,
    this.lastUsedDate,
    this.usageCount = 0,
  });

  final String name;
  final String muscleGroup;
  final int? lastSets;
  final String? lastReps;
  final double? lastWeightKg;
  final int? lastRestSeconds;
  final DateTime? lastUsedDate;
  final int usageCount;

  factory ExerciseTemplate.fromMap(Map<String, dynamic> map) {
    return ExerciseTemplate(
      name: map['name'] as String,
      muscleGroup: map['muscle_group'] as String,
      lastSets: map['last_sets'] as int?,
      lastReps: map['last_reps'] as String?,
      lastWeightKg: map['last_weight_kg'] != null 
          ? (map['last_weight_kg'] as num).toDouble() 
          : null,
      lastRestSeconds: map['last_rest_seconds'] as int?,
      lastUsedDate: map['last_used_date'] != null 
          ? DateTime.parse(map['last_used_date'] as String)
          : null,
      usageCount: map['usage_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'muscle_group': muscleGroup,
      'last_sets': lastSets,
      'last_reps': lastReps,
      'last_weight_kg': lastWeightKg,
      'last_rest_seconds': lastRestSeconds,
      'last_used_date': lastUsedDate?.toIso8601String(),
      'usage_count': usageCount,
    };
  }

  ExerciseTemplate copyWith({
    String? name,
    String? muscleGroup,
    int? lastSets,
    String? lastReps,
    double? lastWeightKg,
    int? lastRestSeconds,
    DateTime? lastUsedDate,
    int? usageCount,
  }) {
    return ExerciseTemplate(
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      lastSets: lastSets ?? this.lastSets,
      lastReps: lastReps ?? this.lastReps,
      lastWeightKg: lastWeightKg ?? this.lastWeightKg,
      lastRestSeconds: lastRestSeconds ?? this.lastRestSeconds,
      lastUsedDate: lastUsedDate ?? this.lastUsedDate,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}
