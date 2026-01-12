
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/training_plan.dart';
import 'create_plan_page.dart';
import 'plan_detail_page.dart';
import 'training_plan_repository.dart';

class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  late final TrainingPlanRepository _repository;
  bool _isLoading = true;
  List<TrainingPlan> _plans = [];

  @override
  void initState() {
    super.initState();
    _repository = TrainingPlanRepository(Supabase.instance.client);
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans = await _repository.fetchPlans();
      if (mounted) {
        setState(() {
          _plans = plans;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar planos: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum plano criado',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text('Planeje seu mesociclo para evoluir.'),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _navigateToCreate,
                        icon: const Icon(Icons.add),
                        label: const Text('Criar Novo Plano'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _plans.length,
                  itemBuilder: (context, index) {
                    final plan = _plans[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: plan.goal == TrainingGoal.hypertrophy
                              ? Colors.purple.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.2),
                          child: Icon(
                            plan.goal == TrainingGoal.hypertrophy
                                ? Icons.fitness_center
                                : Icons.bolt,
                            color: plan.goal == TrainingGoal.hypertrophy
                                ? Colors.purple
                                : Colors.orange,
                          ),
                        ),
                        title: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${plan.durationWeeks} Semanas • ${plan.goal.label}'),
                            Text(
                              'Início: ${DateFormat('dd/MM/yyyy').format(plan.startDate)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        isThreeLine: true,
                        onTap: () async {
                           await Navigator.push(
                             context,
                             MaterialPageRoute(builder: (_) => PlanDetailPage(planId: plan.id!)),
                           );
                           _loadPlans();
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: _plans.isNotEmpty
          ? FloatingActionButton(
              onPressed: _navigateToCreate,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _navigateToCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePlanPage()),
    );
    if (result == true) {
      _loadPlans();
    }
  }
}
