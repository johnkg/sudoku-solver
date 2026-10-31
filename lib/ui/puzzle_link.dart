import 'solver/puzzle_text.dart';

/// A link to [base]'s page that opens with [cells] already entered on the
/// Solver tab. Blanks are written as dots, so the link reads like the
/// 81-character form puzzle sites use.
Uri puzzleLink(Uri base, List<int> cells) => base.removeFragment().replace(
  queryParameters: {
    ...base.queryParameters,
    'puzzle': cells.map((v) => v == 0 ? '.' : '$v').join(),
  },
);

/// The puzzle in [uri]'s `puzzle` parameter, or null if there is none or it
/// is not a valid puzzle.
List<int>? puzzleFromUri(Uri uri) {
  final text = uri.queryParameters['puzzle'];
  return text == null ? null : parsePuzzleText(text);
}
