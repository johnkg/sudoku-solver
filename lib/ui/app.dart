import 'package:flutter/material.dart';

import '../progress/progress_scope.dart';
import '../progress/progress_store.dart';
import '../settings/settings.dart';
import 'cheat_sheet_screen.dart';
import 'confirm_dialog.dart';
import 'learn_tab.dart';
import 'navigation.dart';
import 'practice_tab.dart';
import 'settings_screen.dart';
import 'solver_tab.dart';
import 'stats_screen.dart';
import 'theme.dart';

class SudokuApp extends StatelessWidget {
  SudokuApp({
    super.key,
    required this.store,
    this.initialPuzzle,
    Settings? settings,
  }) : settings = settings ?? Settings.memory();

  final ProgressStore store;
  final Settings settings;

  /// A puzzle from a shared link. The app opens on the Solver tab with it.
  final List<int>? initialPuzzle;

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      settings: settings,
      child: ProgressScope(
        store: store,
        child: MaterialApp(
          title: 'Sudoku Technique Teacher',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: AppShell(initialPuzzle: initialPuzzle),
        ),
      ),
    );
  }
}

enum _MenuAction { cheatSheet, stats, settings, unlockAll, reset }

/// Two tabs: lessons to learn from, puzzles to practise on.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialPuzzle});

  final List<int>? initialPuzzle;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int index = widget.initialPuzzle == null ? 0 : 2;

  Future<void> _onMenu(_MenuAction action) async {
    final store = ProgressScope.read(context);
    switch (action) {
      case _MenuAction.cheatSheet:
        await pushScreen(context, (_) => const CheatSheetScreen());
      case _MenuAction.stats:
        await pushScreen(context, (_) => const StatsScreen());
      case _MenuAction.settings:
        await pushScreen(context, (_) => const SettingsScreen());
      case _MenuAction.unlockAll:
        store.unlockAllLevels();
      case _MenuAction.reset:
        final confirmed = await confirm(
          context,
          title: 'Reset progress?',
          message:
              'This forgets every solved puzzle, every game in progress, and '
              'locks the levels again.',
          confirmLabel: 'Reset',
        );
        if (confirmed) store.reset();
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
                value: _MenuAction.cheatSheet,
                child: Text('Technique cheat sheet'),
              ),
              const PopupMenuItem(
                value: _MenuAction.stats,
                child: Text('Statistics'),
              ),
              const PopupMenuItem(
                value: _MenuAction.settings,
                child: Text('Settings'),
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
        children: [
          const LearnTab(),
          const PracticeTab(),
          SolverTab(initialCells: widget.initialPuzzle),
        ],
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
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: 'Solver',
          ),
        ],
      ),
    );
  }
}
