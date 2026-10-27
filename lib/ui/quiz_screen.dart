import 'package:flutter/material.dart' hide Step;

import 'dart:math';

import '../engine/engine.dart';
import '../progress/progress_scope.dart';
import 'board_view.dart';
import 'layout.dart';
import 'quiz.dart';
import 'section.dart';
import 'search_dialog.dart';

/// Shows boards where [technique] applies and asks the player to spot it.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.technique, this.freshQuestions});

  final Technique technique;

  /// Finds a round of new questions, stopping when told to. Defaults to
  /// generating boards; tests pass their own.
  final Future<List<QuizQuestion>?> Function(bool Function() isCancelled)?
  freshQuestions;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late List<QuizQuestion> questions = quizQuestions(widget.technique);
  int round = 1;
  int index = 0;
  int score = 0;
  final marked = <int>{};
  bool? correct;

  bool get finished => index >= questions.length;
  QuizQuestion get question => questions[index];

  void _check() {
    final right =
        marked.length == question.targets.length &&
        marked.containsAll(question.targets);
    ProgressScope.read(context)
        .recordTechnique(widget.technique.name, right: right);
    setState(() {
      correct = right;
      if (right) score++;
    });
  }

  void _tap(int cell) {
    if (correct != null) return;
    if (question.placesDigit) {
      setState(() => marked.add(cell));
      _check();
    } else {
      setState(
        () => marked.contains(cell) ? marked.remove(cell) : marked.add(cell),
      );
    }
  }

  void _next() => setState(() {
    index++;
    marked.clear();
    correct = null;
  });

  Future<List<QuizQuestion>?> _generate(bool Function() isCancelled) async {
    final random = Random();
    final found = <QuizQuestion>[];
    for (var i = 0; i < questionsPerRound; i++) {
      final moment = await findMomentOf(
        widget.technique,
        random,
        isCancelled: isCancelled,
      );
      if (moment == null) break;
      found.add(QuizQuestion(moment.board, moment.step));
    }
    return found.isEmpty ? null : found;
  }

  /// Swaps in a round of freshly generated boards.
  Future<void> _more() async {
    final found = await runSearchWithDialog<List<QuizQuestion>>(
      context,
      message: 'Finding fresh ${widget.technique.label} boards…',
      notFound: 'No fresh boards this time. Try again.',
      search: widget.freshQuestions ?? _generate,
    );
    if (found == null || !mounted) return;
    setState(() {
      questions = found;
      round++;
      index = 0;
      score = 0;
      marked.clear();
      correct = null;
    });
  }

  void _restart() => setState(() {
    index = 0;
    score = 0;
    marked.clear();
    correct = null;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.technique.label;

    final Widget body;
    if (finished) {
      body = _Results(
        label: label,
        score: score,
        total: questions.length,
        round: round,
        onRetry: _restart,
        onMore: _more,
      );
    } else {
      final q = question;
      final answered = correct != null;
      body = ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          Text(
            '${round > 1 ? 'Round $round · ' : ''}Question ${index + 1} of '
            '${questions.length} · $score right',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: Space.sm),
          StepDots(total: questions.length, done: index + (answered ? 1 : 0)),
          const SizedBox(height: Space.md),
          Text(
            q.placesDigit
                ? 'A $label is available. Tap the cell it lets you fill.'
                : 'A $label is available. Tap the ${q.targets.length} cells '
                      'that form it.',
            key: const Key('quiz-prompt'),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: Space.md),
          BoardView(
            board: q.board,
            givens: {
              for (var i = 0; i < Board.cellCount; i++)
                if (q.board.values[i] != 0) i,
            },
            showCandidates: true,
            step: answered ? q.step : null,
            candidateFocus: answered ? q.step : null,
            marked: answered ? const {} : marked,
            onCellTap: _tap,
          ),
          const SizedBox(height: Space.md),
          if (!answered && !q.placesDigit)
            FilledButton(
              key: const Key('quiz-check'),
              onPressed: marked.isEmpty ? null : _check,
              child: Text('Check (${marked.length} of ${q.targets.length})'),
            ),
          if (answered) ...[
            Card(
              margin: EdgeInsets.zero,
              color: correct!
                  ? theme.colorScheme.tertiaryContainer
                  : theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      correct! ? 'Correct!' : 'Not quite.',
                      key: const Key('quiz-result'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: correct!
                            ? theme.colorScheme.onTertiaryContainer
                            : theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      q.step.explanation,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: correct!
                            ? theme.colorScheme.onTertiaryContainer
                            : theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            FilledButton(
              key: const Key('quiz-next'),
              onPressed: _next,
              child: Text(
                index == questions.length - 1 ? 'See results' : 'Next question',
              ),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Quiz: $label')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: boardScreenMaxWidth),
            child: body,
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.label,
    required this.score,
    required this.total,
    required this.round,
    required this.onRetry,
    required this.onMore,
  });

  final String label;
  final int score;
  final int total;
  final int round;
  final VoidCallback onRetry;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(Space.xl),
      children: [
        Card(
          margin: EdgeInsets.zero,
          color: score == total
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You spotted $score of $total.',
                  key: const Key('quiz-score'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: score == total
                        ? theme.colorScheme.onTertiaryContainer
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: Space.sm),
                Text(
                  score == total
                      ? 'Perfect. You can spot a $label.'
                      : 'Re-read the lesson, then try again.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: score == total
                        ? theme.colorScheme.onTertiaryContainer
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        FilledButton(
          key: const Key('quiz-retry'),
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
        const SizedBox(height: Space.sm),
        FilledButton.tonal(
          key: const Key('quiz-more'),
          onPressed: onMore,
          child: const Text('Fresh boards'),
        ),
        const SizedBox(height: Space.sm),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to the lesson'),
        ),
      ],
    );
  }
}
