import 'dart:math';

/// Days until the next review after the first right answer.
const firstReviewIntervalDays = 1;

/// A wrong answer brings the review back this soon.
const missedReviewIntervalDays = 1;

/// The longest the gap between reviews grows to.
const maxReviewIntervalDays = 32;

/// How many days to wait before reviewing a technique again, after an answer
/// that was [right] or not. Each right answer doubles the gap, up to
/// [maxReviewIntervalDays]; a wrong one resets it. [current] is the gap used
/// so far, 0 for a technique not yet reviewed.
int reviewIntervalAfter({required int current, required bool right}) {
  if (!right) return missedReviewIntervalDays;
  if (current == 0) return firstReviewIntervalDays;
  return min(current * 2, maxReviewIntervalDays);
}
