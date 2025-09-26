import 'package:flutter_test/flutter_test.dart';

import 'package:construindo_fibra/models/exercise_entry.dart';

void main() {
  group('ExerciseEntry', () {
    test('calcula volume com reps numéricas', () {
      final exercise = ExerciseEntry(
        id: null,
        name: 'Supino',
        muscleGroup: 'Peito',
        sets: 4,
        reps: '10',
        weightKg: 80,
        restSeconds: 60,
      );
      expect(exercise.volume, 3200);
    });

    test('calcula volume com intervalo de reps', () {
      final exercise = ExerciseEntry(
        id: null,
        name: 'Supino',
        muscleGroup: 'Peito',
        sets: 4,
        reps: '8-12',
        weightKg: 80,
        restSeconds: 60,
      );
      expect(exercise.volume, closeTo(4 * 10 * 80, 0.01));
    });
  });
}
