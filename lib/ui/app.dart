import 'package:flutter/material.dart';

import '../progress/progress_scope.dart';
import '../progress/progress_store.dart';
import 'learn_tab.dart';
import 'practice_tab.dart';
import 'stats_screen.dart';

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key, required this.store});

  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3F51B5),
        brightness: brightness,
      ),
      appBarTheme: const AppBarTheme(centerTitle: true),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    return ProgressScope(
      store: store,
      child: MaterialApp(
        title: 'Sudoku Technique Teacher',
        debugShowCheckedModeBanner: false,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        home: const AppShell(),
      ),
    );
  }
}

enum _MenuAction { stats, unlockAll, reset }

/// Two tabs: lessons to learn from, puzzles to practise on.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  Future<void> _onMenu(_MenuAction action) async {
    final store = ProgressScope.read(context);
    switch (action) {
      case _MenuAction.stats:
        await Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const StatsScreen()));
      case _MenuAction.unlockAll:
        store.unlockAllLevels();
      case _MenuAction.reset:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reset progress?'),
            content: const Text(
              'This forgets every solved puzzle, every game in progress, and '
              'locks the levels again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reset'),
              ),
            ],
          ),
        );
        if (confirmed ?? false) store.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku Technique Teacher'),
        actions: [
          PopupMenuButton<_MenuAction>(
            tooltip: 'Progress options',
            onSelected: _onMenu,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _MenuAction.stats,
                child: Text('Statistics'),
              ),
              PopupMenuItem(
                value: _MenuAction.unlockAll,
                enabled: !store.unlockedAll,
                child: const Text('Unlock all levels'),
              ),
              const PopupMenuItem(
                value: _MenuAction.reset,
                child: Text('Reset progress'),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: const [LearnTab(), PracticeTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_on_outlined),
            selectedIcon: Icon(Icons.grid_on),
            label: 'Practice',
          ),
        ],
      ),
    );
  }
}
