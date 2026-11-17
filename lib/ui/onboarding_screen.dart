import 'package:flutter/material.dart';

import '../settings/settings.dart';
import 'layout.dart';

/// One screen of the intro: a picture, a heading and a few words.
class _IntroPage {
  const _IntroPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

const _pages = [
  _IntroPage(
    icon: Icons.psychology_outlined,
    title: 'Solve like a person, not a computer',
    body:
        'Every Sudoku can be solved by logic alone. This app teaches the '
        'named tricks, called techniques, one at a time, from the easiest to '
        'the hardest. No guessing.',
  ),
  _IntroPage(
    icon: Icons.school_outlined,
    title: 'Learn a trick, then use it',
    body:
        'Learn has a short lesson for each technique, with a worked example '
        'and a quiz. Practice has puzzles built around each one, and a new '
        'daily puzzle every day.',
  ),
  _IntroPage(
    icon: Icons.lightbulb_outline,
    title: 'Stuck? Ask for a hint',
    body:
        'In a puzzle, Hint shows where to look, then the technique, then its '
        'cells, then the move. On the Solver tab you can type in any puzzle '
        'and watch it solved step by step.',
  ),
];

/// A short first-run tour of what the app is and how to use it. Leaving it,
/// by finishing or skipping, remembers that the player has seen it.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageTurn = Duration(milliseconds: 250);

  final controller = PageController();
  int page = 0;

  bool get _isLast => page == _pages.length - 1;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _finish() {
    SettingsScope.read(context).introSeen = true;
    Navigator.of(context).pop();
  }

  void _next() {
    if (_isLast) return _finish();
    controller.nextPage(duration: _pageTurn, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: contentMaxWidth),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const Key('intro-skip'),
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: controller,
                    onPageChanged: (i) => setState(() => page = i),
                    children: [for (final p in _pages) _PageContent(page: p)],
                  ),
                ),
                _Dots(count: _pages.length, current: page),
                Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('intro-next'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, largeButtonHeight),
                      ),
                      onPressed: _next,
                      child: Text(_isLast ? 'Start learning' : 'Next'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent({required this.page});

  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        children: [
          Icon(page.icon, size: iconHero, color: theme.colorScheme.primary),
          const SizedBox(height: Space.xl),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: Space.md),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// A row of dots showing which page is current.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  static const _dotSize = 8.0;

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Page ${current + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: _dotSize,
              height: _dotSize,
              margin: const EdgeInsets.symmetric(horizontal: Space.hair),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == current ? scheme.primary : scheme.outlineVariant,
              ),
            ),
        ],
      ),
    );
  }
}
