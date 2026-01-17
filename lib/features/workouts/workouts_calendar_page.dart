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
      elevation: 0, // Remove elevation to blend better or keep it if desired
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      margin: EdgeInsets.zero, // Controlled by parent
      child: Padding(
        padding: const EdgeInsets.all(8), // Reduced padding inside card
        child: TableCalendar<Workout>(
          locale: 'pt_BR',
          firstDay: DateTime.utc(2022, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: provider.focusedDate,
          selectedDayPredicate: (day) => isSameDay(day, provider.selectedDate),
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {
            CalendarFormat.month: 'Mês',
          },
          onDaySelected: (selected, focused) {
            provider.selectDate(selected);
          },
          onPageChanged: (focused) {
            provider.loadMonth(focused);
          },
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          calendarStyle: CalendarStyle(
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
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
                bottom: 8,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSameDay(day, provider.selectedDate)
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.primary,
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
    // Format: "Segunda-feira, 12 de janeiro de 2024"
    final dateFormatted = MaterialLocalizations.of(context).formatFullDate(selectedDate);
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detalhes do Dia',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormatted,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (workout != null)
                  IconButton.filled(
                    onPressed: isSaving ? null : onEdit,
                    icon: const Icon(Icons.edit),
                    tooltip: 'Editar Treino',
                  )
                else
                  FilledButton.icon(
                    onPressed: isSaving ? null : onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('Novo'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
              ],
            ),
            const Divider(height: 32),
            if (workout == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nenhum treino registrado',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              Builder(
                builder: (context) {
                  final currentWorkout = workout!;
                  final dailyVolume = currentWorkout.exercises.fold<double>(
                    0,
                    (acc, exercise) => acc + exercise.volume,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Stat Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.monitor_weight_outlined, 
                              color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Volume Total',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  '${dailyVolume.toStringAsFixed(0)} kg',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Exercícios Realizados',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      ...currentWorkout.exercises.map(
                        (exercise) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).dividerColor.withOpacity(0.2),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                              child: Text(
                                exercise.sets.toString(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            title: Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${exercise.reps} reps • ${_formatWeight(exercise.weightKg)}kg',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            trailing: Text(
                              '${exercise.volume.toStringAsFixed(0)}kg',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      if (onDelete != null) ...[
                        const SizedBox(height: 24),
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
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Remover Registro'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error,
                            side: BorderSide(color: Theme.of(context).colorScheme.error),
                          ),
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

String _formatWeight(double weight) {
  if (weight >= 1) {
    return weight.toStringAsFixed(0);
  }
  return weight.toStringAsFixed(1);
}
