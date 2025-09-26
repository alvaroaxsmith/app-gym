import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/ui_helpers.dart';
import '../../models/exercise_entry.dart';
import '../../models/workout.dart';
import 'workout_provider.dart';
import 'workout_repository.dart';
import 'workout_form_sheet.dart';

class WorkoutsCalendarPage extends StatelessWidget {
  const WorkoutsCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WorkoutProvider>(
      create: (_) => WorkoutProvider(WorkoutRepository(Supabase.instance.client))
        ..initialize(),
      builder: (context, child) {
        final provider = context.watch<WorkoutProvider>();
        final events = provider.workoutsByDay;
        final selectedWorkout = provider.selectedWorkout;
        final isLoading = provider.isLoading;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final calendar = _CalendarSection(events: events, provider: provider);
            final details = _DetailsSection(
              selectedDate: provider.selectedDate,
              workout: selectedWorkout,
              isSaving: provider.isSaving,
              onEdit: () async {
                await _openEditor(context, provider, selectedWorkout);
              },
              onCreate: () async {
                await _openEditor(context, provider, null);
              },
              onDelete: selectedWorkout == null
                  ? null
                  : () async {
                      await provider.deleteSelectedWorkout();
                      if (context.mounted) {
                        showSnack(context, 'Treino removido');
                      }
                    },
            );

            return Stack(
              children: [
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: calendar),
                      const SizedBox(width: 24),
                      Expanded(flex: 3, child: details),
                    ],
                  )
                else
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      calendar,
                      const SizedBox(height: 16),
                      details,
                    ],
                  ),
                if (isLoading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black12,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WorkoutProvider provider,
    Workout? workout,
  ) async {
    final initialExercises = workout?.exercises ?? <ExerciseEntry>[];
    final result = await showModalBottomSheet<List<ExerciseEntry>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => WorkoutFormSheet(initialExercises: initialExercises),
    );
    if (result != null) {
      await provider.saveWorkout(result);
      if (context.mounted) {
        showSnack(context, 'Treino salvo com sucesso');
      }
    }
  }
}

class _CalendarSection extends StatelessWidget {
  const _CalendarSection({
    required this.events,
    required this.provider,
  });

  final Map<DateTime, Workout> events;
  final WorkoutProvider provider;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TableCalendar<Workout>(
          locale: 'pt_BR',
          firstDay: DateTime.utc(2022, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: provider.selectedDate,
          selectedDayPredicate: (day) => isSameDay(day, provider.selectedDate),
          calendarFormat: CalendarFormat.month,
          onDaySelected: (selected, focused) {
            provider.selectDate(selected);
          },
          onPageChanged: (focused) {
            provider.loadMonth(focused);
          },
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          eventLoader: (day) {
            final normalized = DateTime(day.year, day.month, day.day);
            final workout = events[normalized];
            if (workout == null) return [];
            return [workout];
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return const SizedBox.shrink();
              return Positioned(
                bottom: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.selectedDate,
    required this.workout,
    required this.isSaving,
    required this.onEdit,
    required this.onCreate,
    required this.onDelete,
  });

  final DateTime selectedDate;
  final Workout? workout;
  final bool isSaving;
  final Future<void> Function() onEdit;
  final Future<void> Function() onCreate;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final dateFormatted = MaterialLocalizations.of(context).formatFullDate(selectedDate);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateFormatted,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (workout != null)
                  FilledButton.icon(
                    onPressed: isSaving ? null : onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar'),
                  )
                else
                  FilledButton.icon(
                    onPressed: isSaving ? null : onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('Novo treino'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (workout == null)
              const Text('Nenhum treino registrado para este dia.')
            else
              Builder(
                builder: (context) {
                  final currentWorkout = workout!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Volume total: ${currentWorkout.totalVolume.toStringAsFixed(0)} kg'),
                      const SizedBox(height: 12),
                      ...currentWorkout.exercises.map(
                        (exercise) => Card(
                          child: ListTile(
                            title: Text(exercise.name),
                            subtitle: Text('${exercise.muscleGroup} • ${exercise.sets}x${exercise.reps} • ${exercise.weightKg}kg'),
                            trailing: Text('${exercise.restSeconds}s'),
                          ),
                        ),
                      ),
                      if (onDelete != null) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Remover treino'),
                                      content: const Text('Tem certeza que deseja remover este treino?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        FilledButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Remover'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await onDelete!();
                                  }
                                },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remover treino'),
                        ),
                      ],
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
