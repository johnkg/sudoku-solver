import '../board.dart';
import '../step.dart';

/// A single solving technique. [find] looks for one application of the
/// technique on [board] and returns it as a [Step], or null if none exists.
/// It must not modify [board].
abstract class SolvingTechnique {
  const SolvingTechnique();

  Technique get technique;

  Step? find(Board board);
}
