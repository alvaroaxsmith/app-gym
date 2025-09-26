import 'package:flutter/foundation.dart';

import '../../models/exercise_entry.dart';
import '../../models/workout.dart';
import 'workout_repository.dart';

class WorkoutProvider extends ChangeNotifier {
  WorkoutProvider(this._repository);

  final WorkoutRepository _repository;

  Map<DateTime, Workout> _workoutsByDay = {};
  Workout? _selectedWorkout;
  DateTime _focusedMonth = _onlyMonth(DateTime.now());
  DateTime _selectedDate = _onlyDate(DateTime.now());
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  Map<DateTime, Workout> get workoutsByDay => _workoutsByDay;
  Workout? get selectedWorkout => _selectedWorkout;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    final now = DateTime.now();
    _selectedDate = _onlyDate(now);
    await loadMonth(now);
    await selectDate(now);
  }

  Future<void> loadMonth(DateTime month) async {
    _focusedMonth = _onlyMonth(month);
    _setLoading(true);
    try {
      _workoutsByDay = await _repository.fetchWorkoutsForMonth(month);
      if (!_workoutsByDay.containsKey(_selectedDate)) {
        _selectedWorkout = null;
      }
      _errorMessage = null;
    } catch (err) {
      _errorMessage = 'Não foi possível carregar os treinos do mês.';
      if (kDebugMode) {
        print(err);
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> selectDate(DateTime date) async {
    final normalized = _onlyDate(date);
    _selectedDate = normalized;
    if (_workoutsByDay.containsKey(normalized)) {
      _selectedWorkout = _workoutsByDay[normalized];
      notifyListeners();
      return;
    }
    _setLoading(true);
    try {
      final workout = await _repository.fetchWorkoutByDate(normalized);
      if (workout != null) {
        _workoutsByDay = {
          ..._workoutsByDay,
          normalized: workout,
        };
      }
      _selectedWorkout = workout;
      _errorMessage = null;
    } catch (err) {
      _errorMessage = 'Erro ao carregar treino do dia.';
      if (kDebugMode) {
        print(err);
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> saveWorkout(List<ExerciseEntry> exercises) async {
    _setSaving(true);
    try {
      final existing = _workoutsByDay[_selectedDate];
      final workout = Workout(
        id: existing?.id,
        userId: existing?.userId ?? '',
        date: _selectedDate,
        exercises: exercises,
      );
      final saved = await _repository.upsertWorkout(workout);
      _workoutsByDay = {
        ..._workoutsByDay,
        _selectedDate: saved,
      };
      _selectedWorkout = saved;
      _errorMessage = null;
    } catch (err) {
      _errorMessage = 'Erro ao salvar treino.';
      if (kDebugMode) {
        print(err);
      }
    } finally {
      _setSaving(false);
    }
  }

  Future<void> deleteSelectedWorkout() async {
    final workout = _workoutsByDay[_selectedDate];
    if (workout == null || workout.id == null) return;
    _setSaving(true);
    try {
      await _repository.deleteWorkout(workout.id!);
      final updated = Map<DateTime, Workout>.from(_workoutsByDay)
        ..remove(_selectedDate);
      _workoutsByDay = updated;
      _selectedWorkout = null;
      _errorMessage = null;
    } catch (err) {
      _errorMessage = 'Erro ao excluir treino.';
      if (kDebugMode) {
        print(err);
      }
    } finally {
      _setSaving(false);
    }
  }

  Future<List<Workout>> fetchForRange(DateTime start, DateTime end) {
    return _repository.fetchWorkoutsBetween(start, end);
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  static DateTime _onlyDate(DateTime date) => DateTime(date.year, date.month, date.day);
  static DateTime _onlyMonth(DateTime date) => DateTime(date.year, date.month);
}
