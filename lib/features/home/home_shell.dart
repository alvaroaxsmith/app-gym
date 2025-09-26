import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui_helpers.dart';
import '../auth/auth_provider.dart';
import '../dashboard/dashboard_page.dart';
import '../imports/import_workouts_page.dart';
import '../ranking/ranking_page.dart';
import '../workouts/workouts_calendar_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    WorkoutsCalendarPage(),
    DashboardPage(),
    RankingPage(),
    ImportWorkoutsPage(),
  ];

  final _titles = const [
    'Calendário',
    'Dashboard',
    'Ranking',
    'Importar',
  ];

  void _onItemTapped(int newIndex) {
    setState(() {
      _index = newIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              await auth.signOut();
              if (context.mounted) {
                showSnack(context, 'Sessão encerrada');
              }
            },
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendário'),
          NavigationDestination(icon: Icon(Icons.leaderboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.emoji_events), label: 'Ranking'),
          NavigationDestination(icon: Icon(Icons.upload_file), label: 'Importar'),
        ],
        onDestinationSelected: _onItemTapped,
      ),
    );
  }
}
