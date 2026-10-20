import 'chains.dart';
import 'full_house.dart';
import 'hidden_single.dart';
import 'coloring.dart';
import 'fish.dart';
import 'hidden_subset.dart';
import 'locked_candidates.dart';
import 'naked_subset.dart';
import 'naked_single.dart';
import 'technique.dart';
import 'uniqueness.dart';
import 'wings.dart';

/// The techniques the app had before chains. The daily puzzle is rated with
/// these, so it does not change for players when techniques are added.
const List<SolvingTechnique> legacyTechniques = [
  FullHouse(),
  NakedSingle(),
  HiddenSingle(),
  PointingPair(),
  BoxLineReduction(),
  NakedSubset(2),
  HiddenSubset(2),
  NakedSubset(3),
  HiddenSubset(3),
  Fish(2),
  Skyscraper(),
  YWing(),
  Fish(3),
  NakedSubset(4),
  HiddenSubset(4),
  XYZWing(),
  UniqueRectangle(),
  WWing(),
  SimpleColoring(),
  Fish(4),
];

/// All implemented techniques, easiest first. The solver always tries them in
/// this order.
const List<SolvingTechnique> defaultTechniques = [
  ...legacyTechniques,
  XChain(),
  XYChain(),
];
