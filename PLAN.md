# Sudoku Technique Teacher: Plan

## Goal

Teach players how to solve Sudoku by showing real solving techniques, from the most basic ones for easy puzzles to advanced ones for hard puzzles. The solver is not a black box that outputs an answer. It solves the way a human does, one named technique at a time, and explains each step.

## Location and language

All work happens in this Flutter project (the repository root).

Language is **Dart**, because the app is Flutter. The engine runs on-device and offline, needs no bridge or server, and sealed classes, enums, and pattern matching suit "a technique produces a typed step".

The engine lives in `lib/engine/` and imports nothing from Flutter, so it can be tested with plain `dart test`/`flutter test` and kept separate from the UI in `lib/ui/`.

## Core design idea

A technique-based solver, not brute force.

1. Keep a board with **candidates** (pencil marks) for every empty cell.
2. Run techniques **from easiest to hardest**. Use the first one that finds something.
3. Each technique returns a **Step**: what technique, which cells are involved, which digits get placed or eliminated, and a plain-language explanation.
4. Apply the step, then restart from the easiest technique.
5. If no technique applies, the puzzle is stuck at the current skill level.

Difficulty of a puzzle = the hardest technique the solver needed. This gives honest ratings (Easy, Medium, Hard, Expert) and lets the game pick puzzles for a lesson.

A plain backtracking solver is still included, but only for: checking a puzzle has exactly one solution, and as a fallback to confirm answers. It is never used to teach.

## Technique ladder

| Level | Techniques |
|-------|-----------|
| 1 Beginner | Full house (last cell in a unit), Naked single (cell has one candidate), Hidden single (digit has one spot in a row/column/box) |
| 2 Easy+ | Locked candidates: pointing pairs/triples, box-line reduction |
| 3 Medium | Naked pair/triple, Hidden pair/triple |
| 4 Hard | Naked/Hidden quad, X-Wing, Swordfish, Y-Wing (XY-Wing), Skyscraper |
| 5 Expert | XYZ-Wing, W-Wing, Unique Rectangle, Simple Coloring, Jellyfish, X-Chain, XY-Chain |
| 6 Master (not built) | Forcing chains, Alternating Inference Chains (AIC), Nishio |

Each level builds on ideas from the one before: first "only one place left", then "these digits are locked into a line", then "a group of cells shares a group of digits", then "patterns across rows and columns", then "chains of cause and effect".

## Data model (sketch)

- `Board`: 81 cells, each with a value or a set of candidates (bitmask of 9 bits is fast and simple).
- `Unit`: a row, column, or box (27 units total); helper to get each cell's peers.
- `Step`:
  - `technique` (enum)
  - `placements` (cell and digit)
  - `eliminations` (cell and digits removed)
  - `highlightCells`, `highlightDigits` (for the UI to draw the pattern)
  - `explanation` (template text filled with real cell and digit names)
- `SolvingTechnique` interface: `Step? find(Board board)`.
- `Solver`: runs the technique list in order and produces a list of steps (a full "solution walkthrough").

## Status

Where things stand. The README has the how-to-run and the file layout.

**Engine (`lib/engine/`)**: done for levels 1-5, 22 techniques, including
X-Chain and XY-Chain. Every step carries a plain-language explanation. Also
done: the backtracking checker, the rater (`ratePuzzle` finds the shortest
easiest-first set of techniques that solves a puzzle; the last one is what the
puzzle truly needs), the random puzzle generator, `puzzle_finder.dart`, and the
daily puzzle. Soundness tests replay puzzles against the true solution.

**App (`lib/ui/` and friends)**:
- Learn tab: a lesson per technique (`lib/lessons/lessons.dart`) with a worked
  before/after example found by the real engine, plus a quiz.
- Practice tab: 42 curated puzzles (every technique has at least one), a daily
  puzzle with a streak, random puzzles by level, and a puzzle built around a
  chosen technique.
- Solve screen: play with notes, moves checked against the unique solution, a
  three-step hint ladder, undo, pause, a step-by-step guide, mistake limit.
- Solver tab: paste or type a puzzle, or scan one from a photo (web), and watch
  the walkthrough.
- Progress (`lib/progress/`): stars (3 max, minus one for mistakes, one for
  hints), unlocking by level, achievements, stats, weak spots. Saved with
  `shared_preferences`.
- Web build published to GitHub Pages on every push to `main`.

**Things to remember**
- The daily puzzle is generated from the date with a seeded generator whose
  output is pinned by tests, and rated with `legacyTechniques` so it does not
  change when techniques are added. If you change the generator or the legacy
  rater on purpose, update the pinned dates in `test/engine/daily_test.dart`;
  that changes everyone's daily puzzle.
- Random, technique and custom puzzles are practice only: not saved, and they do
  not count towards unlocking.
- About 15% of random unique puzzles still stall after level 5. They need
  forcing chains or Nishio (level 6).

## Next

- Level 6: forcing chains, AIC, Nishio.
- More curated puzzles per technique (Hidden Quad and Jellyfish have one each,
  the rest two).
- Sharing results beyond the daily puzzle.
- Release hygiene: a real Android/iOS application id (still `com.example`).

## Testing approach

- Each technique has a minimal hand-built board where exactly that technique
  applies; the lesson reuses it as its example.
- The solver is run on the curated puzzles, checking the rating and that the
  final board matches the backtracking solution.
- Soundness: no technique may ever eliminate the true solution digit.
- UI tests drive the real widgets (entry, hints, daily puzzle, progress).
- CI needs 90% line coverage (`tool/check_coverage.dart`).

## Tools

- `dart run tool/solve.dart <puzzle>`: print a walkthrough.
- `dart run tool/curate.dart <count> <seed>`: search for puzzles per technique
  and check every step against the true solution. Jellyfish is slow to find.
- `dart run tool/check_coverage.dart`: coverage gate used by CI.
- `tool/scan/`: accuracy checks for the photo scan.
