import 'package:flutter/material.dart' hide Step;

import '../engine/engine.dart';
import 'board_view.dart';
import 'quiz.dart';

/// Shows boards where [technique] applies and asks the player to spot it.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.technique});

  final Technique technique;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<QuizQuestion> questions = quizQuestions(widget.technique);
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
        onRetry: _restart,
      );
    } else {
      final q = question;
      final answered = correct != null;
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Question ${index + 1} of ${questions.length} · $score right',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            q.placesDigit
                ? 'A $label is available. Tap the cell it lets you fill.'
                : 'A $label is available. Tap the ${q.targets.length} cells '
                      'that form it.',
            key: const Key('quiz-prompt'),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          BoardView(
            board: q.board,
            givens: {
              for (var i = 0; i < 81; i++)
                if (q.board.values[i] != 0) i,
            },
            showCandidates: true,
            step: answered ? q.step : null,
            candidateFocus: answered ? q.step : null,
            marked: answered ? const {} : marked,
            onCellTap: _tap,
          ),
          const SizedBox(height: 12),
          if (!answered && !q.placesDigit)
            FilledButton(
              key: const Key('quiz-check'),
              onPressed: marked.isEmpty ? null : _check,
              child: Text('Check (${marked.length} of ${q.targets.length})'),
            ),
          if (answered) ...[
            Text(
              correct! ? 'Correct!' : 'Not quite.',
              key: const Key('quiz-result'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: correct!
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 4),
            Text(q.step.explanation, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
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
            constraints: const BoxConstraints(maxWidth: 560),
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
    required this.onRetry,
  });

  final String label;
  final int score;
  final int total;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'You spotted $score of $total.',
          key: const Key('quiz-score'),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          score == total
              ? 'Perfect. You can spot a $label.'
              : 'Re-read the lesson, then try again.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('quiz-retry'),
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to the lesson'),
        ),
      ],
    );
  }
}
