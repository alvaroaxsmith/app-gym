import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/exercise_entry.dart';

class ExerciseTimerModal extends StatefulWidget {
  final ExerciseEntry exercise;

  const ExerciseTimerModal({super.key, required this.exercise});

  @override
  State<ExerciseTimerModal> createState() => _ExerciseTimerModalState();
}

class _ExerciseTimerModalState extends State<ExerciseTimerModal> {
  late int _currentSet;
  late int _totalSets;
  late TextEditingController _restController;
  
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _currentSet = 1;
    _totalSets = widget.exercise.sets > 0 ? widget.exercise.sets : 3;
    _restController = TextEditingController(text: widget.exercise.restSeconds.toString());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restController.dispose();
    super.dispose();
  }

  void _startRest() {
    final restTime = int.tryParse(_restController.text) ?? 60;
    
    setState(() {
      _remainingSeconds = restTime;
      _isRunning = true;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        _finishSet();
      }
    });
  }

  void _finishSet() {
    setState(() {
      _isRunning = false;
      if (_currentSet < _totalSets) {
        _currentSet++;
        // Show message?
      } else {
        _isFinished = true;
      }
    });
  }

  void _close() {
    Navigator.of(context).pop(_isFinished);
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              '${widget.exercise.name} Concluído!',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _close,
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.exercise.name,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Série $_currentSet de $_totalSets',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          if (_isRunning)
            Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: (int.tryParse(_restController.text) ?? 60) > 0 
                            ? _remainingSeconds / (int.tryParse(_restController.text) ?? 60)
                            : 0,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    Text(
                      '$_remainingSeconds',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () {
                    _timer?.cancel();
                    setState(() => _isRunning = false);
                  },
                  child: const Text('Cancelar Descanso'),
                ),
              ],
            )
          else
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Tempo de Descanso (s): '),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _restController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _startRest,
                  icon: const Icon(Icons.timer),
                  label: const Text('Iniciar Descanso'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
                 const SizedBox(height: 12),
                 TextButton(
                   onPressed: _finishSet, 
                   child: const Text('Pular Descanso (Marcar Série)')
                 ),
              ],
            ),
        ],
      ),
    );
  }
}
