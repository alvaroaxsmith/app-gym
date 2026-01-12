class ExerciseEntry {
  ExerciseEntry({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.sets,
    required this.reps,
    required this.weightKg,
    required this.restSeconds,
    this.rpe,
    this.isWarmup = false,
    this.warmupSets = 0,
  });

  final String? id;
  final String name;
  final String muscleGroup;
  final int sets;
  final String reps;
  final double weightKg;
  final int restSeconds;
  final double? rpe;
  final bool isWarmup;
  final int warmupSets;

  double get volume => sets * repsAsNumber * weightKg;

  double get repsAsNumber {
    final numericValue = double.tryParse(reps.trim());
    if (numericValue != null) {
      return numericValue;
    }
    final match = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(reps.trim());
    if (match != null) {
      return double.tryParse(match.group(1) ?? '') ?? 0;
    }
    final fallback = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(reps);
    if (fallback != null) {
      return double.tryParse(fallback.group(1) ?? '') ?? 0;
    }
    return 0;
  }

  ExerciseEntry copyWith({
    String? id,
    String? name,
    String? muscleGroup,
    int? sets,
    String? reps,
    double? weightKg,
    int? restSeconds,
    double? rpe,
    bool? isWarmup,
    int? warmupSets,
  }) {
    return ExerciseEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weightKg: weightKg ?? this.weightKg,
      restSeconds: restSeconds ?? this.restSeconds,
      rpe: rpe ?? this.rpe,
      isWarmup: isWarmup ?? this.isWarmup,
      warmupSets: warmupSets ?? this.warmupSets,
    );
  }

  factory ExerciseEntry.fromMap(Map<String, dynamic> map) {
    return ExerciseEntry(
      id: map['id'] as String?,
      name: map['name'] as String? ?? '',
      muscleGroup: map['muscle_group'] as String? ?? '',
      sets: map['sets'] is int
          ? map['sets'] as int
          : int.tryParse(map['sets'].toString()) ?? 0,
      reps: map['reps']?.toString() ?? '',
      weightKg: map['weight_kg'] is num
          ? (map['weight_kg'] as num).toDouble()
          : double.tryParse(map['weight_kg']?.toString() ?? '') ?? 0,
      restSeconds: map['rest_seconds'] is int
          ? map['rest_seconds'] as int
          : int.tryParse(map['rest_seconds']?.toString() ?? '') ?? 0,
      rpe: map['rpe'] != null ? (map['rpe'] as num).toDouble() : null,
      isWarmup: map['is_warmup'] as bool? ?? false,
      warmupSets: map['warmup_sets'] is int
          ? map['warmup_sets'] as int
          : int.tryParse(map['warmup_sets']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toMap(String workoutId) {
    return {
      if (id != null) 'id': id,
      'workout_id': workoutId,
      'name': name,
      'muscle_group': muscleGroup,
      'sets': sets,
      'reps': reps,
      'weight_kg': weightKg,
      'rest_seconds': restSeconds,
      'rpe': rpe,
      'is_warmup': isWarmup,
      'warmup_sets': warmupSets,
    };
  }
}

const List<String> kMuscleGroups = [
  'Peito',
  'Costas',
  'Pernas',
  'Ombros',
  'Bíceps',
  'Tríceps',
  'Abdômen',
];
