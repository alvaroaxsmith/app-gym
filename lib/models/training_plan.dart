enum TrainingGoal {
  hypertrophy,
  strength,
  maintenance,
  other;

  String get label {
    switch (this) {
      case TrainingGoal.hypertrophy:
        return 'Hipertrofia';
      case TrainingGoal.strength:
        return 'Força';
      case TrainingGoal.maintenance:
        return 'Manutenção';
      case TrainingGoal.other:
        return 'Outro';
    }
  }

  String get description {
    switch (this) {
      case TrainingGoal.hypertrophy:
        return 'Foco em volume progressivo (MEV->MRV) e RPE/RIR moderado (7-9).';
      case TrainingGoal.strength:
        return 'Foco em intensidade de carga, repetições baixas e RPE alto.';
      case TrainingGoal.maintenance:
        return 'Volume reduzido (MV) para preservar massa muscular.';
      case TrainingGoal.other:
        return 'Objetivo personalizado.';
    }
  }

  static TrainingGoal fromString(String val) {
    return TrainingGoal.values.firstWhere(
      (e) => e.name == val,
      orElse: () => TrainingGoal.other,
    );
  }
}

class TrainingPlan {
  final String? id;
  final String userId;
  final String name;
  final String? description;
  final TrainingGoal goal;
  final DateTime startDate;
  final int durationWeeks;
  final List<TrainingPlanWeek> weeks;

  TrainingPlan({
    this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.goal,
    required this.startDate,
    required this.durationWeeks,
    this.weeks = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'goal': goal.name,
      'start_date': startDate.toIso8601String(),
      'duration_weeks': durationWeeks,
    };
  }

  factory TrainingPlan.fromMap(Map<String, dynamic> map) {
    return TrainingPlan(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      goal: TrainingGoal.fromString(map['goal'] as String),
      startDate: DateTime.parse(map['start_date'] as String),
      durationWeeks: map['duration_weeks'] as int,
    );
  }

  TrainingPlan copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    TrainingGoal? goal,
    DateTime? startDate,
    int? durationWeeks,
    List<TrainingPlanWeek>? weeks,
  }) {
    return TrainingPlan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      goal: goal ?? this.goal,
      startDate: startDate ?? this.startDate,
      durationWeeks: durationWeeks ?? this.durationWeeks,
      weeks: weeks ?? this.weeks,
    );
  }
}

class TrainingPlanWeek {
  final String? id;
  final String? planId;
  final int weekNumber;
  final String? label;
  final double? targetRpeMin;
  final double? targetRpeMax;
  final bool isDeload;
  final String? notes;
  final List<TrainingPlanWorkout> workouts;

  TrainingPlanWeek({
    this.id,
    this.planId,
    required this.weekNumber,
    this.label,
    this.targetRpeMin,
    this.targetRpeMax,
    this.isDeload = false,
    this.notes,
    this.workouts = const [],
  });

  Map<String, dynamic> toMap(String planId) {
    return {
      if (id != null) 'id': id,
      'plan_id': planId,
      'week_number': weekNumber,
      'label': label,
      'target_rpe_min': targetRpeMin,
      'target_rpe_max': targetRpeMax,
      'is_deload': isDeload,
      'notes': notes,
    };
  }

  factory TrainingPlanWeek.fromMap(Map<String, dynamic> map) {
    // If the query joins workouts, we can parse them.
    // Assuming Supabase returns 'training_plan_workouts' as a list in the JSON
    final workoutsList = (map['training_plan_workouts'] as List<dynamic>?)
            ?.map((e) => TrainingPlanWorkout.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    // Sort by day_index if available, or name
    workoutsList.sort((a, b) => (a.dayIndex ?? 99).compareTo(b.dayIndex ?? 99));

    return TrainingPlanWeek(
      id: map['id'] as String?,
      planId: map['plan_id'] as String?,
      weekNumber: map['week_number'] is int
          ? map['week_number'] as int
          : int.parse(map['week_number'].toString()),
      label: map['label'] as String?,
      targetRpeMin: map['target_rpe_min'] != null
          ? (map['target_rpe_min'] as num).toDouble()
          : null,
      targetRpeMax: map['target_rpe_max'] != null
          ? (map['target_rpe_max'] as num).toDouble()
          : null,
      isDeload: map['is_deload'] as bool? ?? false,
      notes: map['notes'] as String?,
      workouts: workoutsList,
    );
  }

  TrainingPlanWeek copyWith({
    String? id,
    String? planId,
    int? weekNumber,
    String? label,
    double? targetRpeMin,
    double? targetRpeMax,
    bool? isDeload,
    String? notes,
    List<TrainingPlanWorkout>? workouts,
  }) {
    return TrainingPlanWeek(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      weekNumber: weekNumber ?? this.weekNumber,
      label: label ?? this.label,
      targetRpeMin: targetRpeMin ?? this.targetRpeMin,
      targetRpeMax: targetRpeMax ?? this.targetRpeMax,
      isDeload: isDeload ?? this.isDeload,
      notes: notes ?? this.notes,
      workouts: workouts ?? this.workouts,
    );
  }
}

class TrainingPlanWorkout {
  final String? id;
  final String? weekId;
  final String name;
  final String? description;
  final int? dayIndex; // 0=Monday, ... 6=Sunday. Null = Unscheduled
  final List<TrainingPlanWorkoutItem> items;

  TrainingPlanWorkout({
    this.id,
    this.weekId,
    required this.name,
    this.description,
    this.dayIndex,
    this.items = const [],
  });

  Map<String, dynamic> toMap(String weekId) {
    return {
      if (id != null) 'id': id,
      'week_id': weekId,
      'name': name,
      'description': description,
      'day_index': dayIndex,
    };
  }

  factory TrainingPlanWorkout.fromMap(Map<String, dynamic> map) {
    final itemsList = (map['items'] as List<dynamic>?)
            ?.map((e) => TrainingPlanWorkoutItem.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    itemsList.sort((a, b) => (a.sortOrder).compareTo(b.sortOrder));

    return TrainingPlanWorkout(
      id: map['id'] as String?,
      weekId: map['week_id'] as String?,
      name: map['name'] as String? ?? 'Sem Nome',
      description: map['description'] as String?,
      dayIndex: map['day_index'] as int?,
      items: itemsList,
    );
  }
}

class TrainingPlanWorkoutItem {
  final String? id;
  final String? workoutId;
  final String exerciseId;
  final String? exerciseName; // Fetched via join
  final int sets;
  final String? reps;
  final String? rpe;
  final String? weight; // Added weight
  final int? restSeconds;
  final String? notes;
  final int sortOrder;

  TrainingPlanWorkoutItem({
    this.id,
    this.workoutId,
    required this.exerciseId,
    this.exerciseName,
    this.sets = 3,
    this.reps,
    this.rpe,
    this.weight,
    this.restSeconds,
    this.notes,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap(String workoutId) {
    return {
      if (id != null) 'id': id,
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'sets': sets,
      'reps': reps,
      'rpe': rpe,
      'weight': weight,
      'rest_seconds': restSeconds,
      'notes': notes,
      'sort_order': sortOrder,
    };
  }

  factory TrainingPlanWorkoutItem.fromMap(Map<String, dynamic> map) {
    // If using a join, exercise name might be inside 'exercise_library' object
    String? exName;
    if (map['exercise_library'] != null) {
      exName = map['exercise_library']['name'];
    }

    return TrainingPlanWorkoutItem(
      id: map['id'] as String?,
      workoutId: map['workout_id'] as String?,
      exerciseId: map['exercise_id'] as String,
      exerciseName: exName,
      sets: map['sets'] as int? ?? 3,
      reps: map['reps'] as String?,
      rpe: map['rpe'] as String?,
      weight: map['weight'] as String?,
      restSeconds: map['rest_seconds'] as int?,
      notes: map['notes'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }
}
