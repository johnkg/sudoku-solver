import 'package:flutter/material.dart';

import '../settings/settings.dart';

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
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
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
              ListTile(
                title: const Text('Mistake limit'),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'After this many mistakes the game offers to start the '
                    'puzzle over.',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  onSelectionChanged: (s) => settings.mistakeLimit = s.first,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
