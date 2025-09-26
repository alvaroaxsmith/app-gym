import 'package:intl/intl.dart';

import 'exercise_entry.dart';

class Workout {
  Workout({
    required this.id,
    required this.userId,
    required this.date,
    required this.exercises,
  });

  final String? id;
  final String userId;
  final DateTime date;
  final List<ExerciseEntry> exercises;

  double get totalVolume => exercises.fold(0, (acc, e) => acc + e.volume);

  Workout copyWith({
    String? id,
    String? userId,
    DateTime? date,
    List<ExerciseEntry>? exercises,
  }) {
    return Workout(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      exercises: exercises ?? this.exercises,
    );
  }

  factory Workout.fromMap(Map<String, dynamic> map) {
    final exercises = (map['exercises'] as List<dynamic>? ?? [])
        .map((e) => ExerciseEntry.fromMap(e as Map<String, dynamic>))
        .toList();
    return Workout(
      id: map['id'] as String?,
      userId: map['user_id'] as String? ?? '',
      date: DateTime.parse(map['date'].toString()),
      exercises: exercises,
    );
  }

  Map<String, dynamic> toWorkoutRow() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'date': DateFormat('yyyy-MM-dd').format(date),
    };
  }
}
