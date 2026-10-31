import 'package:flutter/material.dart';

import '../settings/settings.dart';
import 'layout.dart';
import 'section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: contentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.sm,
              Space.lg,
              Space.xxl,
            ),
            children: [
              const SectionTitle('Feedback'),
              _Group(
                children: [
                  SwitchListTile(
                    key: const Key('setting-haptics'),
                    title: const Text('Vibration'),
                    subtitle: const Text(
                      'A tap for each digit, and a stronger one for a mistake. '
                      'Only on phones that can vibrate.',
                    ),
                    value: settings.haptics,
                    onChanged: (v) => settings.haptics = v,
                  ),
                  SwitchListTile(
                    key: const Key('setting-clock'),
                    title: const Text('Show the clock'),
                    subtitle: const Text(
                      'Hide the timer while you play. Your time is still '
                      'recorded when you finish.',
                    ),
                    value: settings.showClock,
                    onChanged: (v) => settings.showClock = v,
                  ),
                ],
              ),
              const SectionTitle('Accessibility'),
              _Group(
                children: [
                  SwitchListTile(
                    key: const Key('setting-patterns'),
                    title: const Text('Extra markings'),
                    subtitle: const Text(
                      'Mark mistakes and hints with hatching and outlines, not '
                      'only colour. Helps if reds and greens look alike.',
                    ),
                    value: settings.patterns,
                    onChanged: (v) => settings.patterns = v,
                  ),
                ],
              ),
              const SectionTitle('Game'),
              _Group(
                children: [
                  const ListTile(
                    title: Text('Mistake limit'),
                    subtitle: Padding(
                      padding: EdgeInsets.only(top: Space.xs),
                      child: Text(
                        'After this many mistakes the game offers to start the '
                        'puzzle over.',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [
                        for (final limit in Settings.mistakeLimits)
                          ButtonSegment(
                            value: limit,
                            label: Text(
                              limit == 0 ? 'No limit' : '$limit',
                              key: Key('limit-$limit'),
                            ),
                          ),
                      ],
                      selected: {settings.mistakeLimit},
                      onSelectionChanged: (s) =>
                          settings.mistakeLimit = s.first,
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: Space.lg),
                child: Text(
                  'Changes apply the next time you open a puzzle.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card holding a few related settings.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}
