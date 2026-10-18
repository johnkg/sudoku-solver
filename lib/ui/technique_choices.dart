import '../engine/engine.dart';

/// Techniques that remove candidates rather than place a digit.
bool removesCandidates(Technique t) => t.index >= Technique.pointingPair.index;

/// Four techniques to pick from for a question about [board], one of which is
/// [correct]. The others are candidate-removing techniques that find nothing
/// on [board], so exactly the right answers are right. In enum order.
List<Technique> techniqueChoices(Board board, Technique correct) {
  final others =
      defaultTechniques
          .where(
            (t) =>
                t.technique != correct &&
                removesCandidates(t.technique) &&
                t.find(board) == null,
          )
          .map((t) => t.technique)
          .toList()
        ..sort(
          (a, b) => (a.level - correct.level).abs().compareTo(
            (b.level - correct.level).abs(),
          ),
        );
  return [correct, ...others.take(3)]
    ..sort((a, b) => a.index.compareTo(b.index));
}
