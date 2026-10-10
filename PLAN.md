# Sudoku Technique Teacher: Plan

## Goal

Teach players how to solve Sudoku by showing real solving techniques, from the most basic ones for easy puzzles to advanced ones for hard puzzles. The solver is not a black box that outputs an answer. It solves the way a human does, one named technique at a time, and explains each step.

## Location and language

All work happens in this Flutter project: `/Users/apple/Source/flutter/sudoku_solver/` (fresh `flutter create` app, no code yet beyond the template).

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
| 5 Expert | XYZ-Wing, W-Wing, Unique Rectangle, Simple Coloring, Jellyfish |
| 6 Master (stretch) | Forcing chains, Alternating Inference Chains (AIC), Nishio |

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

## Project layout

```
sudoku_solver/
  PLAN.md
  pubspec.yaml
  lib/
    main.dart
    engine/                     pure Dart, no Flutter imports
      board.dart                grid, candidates, peers, units
      step.dart                 Step, Technique enum
      parser.dart               81-char string <-> Board
      solver.dart               runs techniques easiest first
      rater.dart                difficulty = hardest technique used
      backtracking.dart         uniqueness check and fallback
      techniques/
        full_house.dart
        naked_single.dart
        hidden_single.dart
        locked_candidates.dart
        naked_subset.dart       pair, triple, quad
        hidden_subset.dart
        fish.dart               X-Wing, Swordfish, Jellyfish
        wings.dart              Y-Wing, XYZ-Wing, W-Wing
        uniqueness.dart         Unique Rectangle
        coloring.dart           Simple Coloring, Skyscraper
        chains.dart             stretch goal
    ui/                         board widget, hint, lesson screens (later)
  tool/
    solve.dart                  CLI: print walkthrough of a puzzle
  test/
    engine/
      technique_test.dart       one tiny hand-built board per technique
      solver_test.dart          known puzzles per level
  assets/puzzles/
    level1.txt ... level6.txt   curated puzzles requiring each level
```

## Status

- Done: build steps 1-3 (engine foundation, level 1 techniques, solver loop, backtracking, CLI) and level 2 (pointing pairs/triples, box-line reduction) level 3 (naked and hidden pairs/triples), level 4 (X-Wing, Swordfish, Y-Wing, Skyscraper, naked/hidden quads), and level 5 (XYZ-Wing, W-Wing, Unique Rectangle types 1-2, Simple Coloring, Jellyfish). The engine milestone for levels 1-5 is complete. Tests pass, analyzer clean, and a soundness test replays puzzles against the true solution.
- Scope decision: stop at level 5. Chains (level 6) come later.
- UI slice 1 done (`lib/ui/`): puzzle picker grouped by level, board with pencil marks, "Show next step" preview with highlighted pattern and struck-through eliminations, Apply/Hide, undo, restart, solved summary, stuck message. Works on phone and wide layouts. Run with `flutter run` (or `flutter build web`).
- UI slice 2 done: Learn tab with a lesson per technique (`lib/lessons/lessons.dart`, 20 lessons). Each has the idea, how to spot it, a Before/After worked example drawn on the board with only the relevant pencil marks, and links to practice puzzles. The example move is found by the real engine, and a test checks every lesson's example is found by its own technique. The solver's step panel has a "How it works" link to the lesson.
- UI slice 3 done: the player can play. Tap a cell (or use arrow keys), then pick a digit with the on-screen pad or the keyboard. Two modes: place a digit, or remove a candidate (needed to carry out techniques like pointing pairs). Moves are checked against the puzzle's unique solution. A wrong digit or an unsafe candidate removal is rejected with an explanation and counted as a mistake, so the board never goes wrong and "Show next step" keeps working. The summary shows moves, mistakes and hints.
- UI slice 4 done: the hint ladder (`lib/ui/hint_ladder.dart`). "Get a hint" goes 1) where to look (the unit is tinted, the digit is named unless it would give away the answer), 2) which technique (name, level, one-line description, pattern cells highlighted), 3) the full move with Apply. "Show the move" skips ahead and "Hide" stops. The summary says how many hints showed the full move.
- UI slice 5 done: progress and saving (`lib/progress/`). Level 1 is open; a level (its lessons and puzzles) unlocks when every puzzle of the level below is solved. Each solve earns up to 3 stars (minus one for any mistakes, minus one for any hints) and the best result is kept. Games in progress are saved after every move and resumed on return, with undo history intact. Saved with `shared_preferences` (works on phone, desktop and web). Saved games are checked against the puzzle's solution when loaded, and a bad save is dropped. Menu: "Unlock all levels" and "Reset progress".
- Rater and curation done. `ratePuzzle` (`lib/engine/rater.dart`) finds the shortest easiest-first set of techniques that solves a puzzle; the last one is what the puzzle truly needs (this caught a mislabelled "X-Wing" puzzle that really needed a Skyscraper too). `lib/engine/generator.dart` makes random unique puzzles. `tool/curate.dart` searches for puzzles per technique and checks every step against the true solution (about 100k puzzles searched; Jellyfish took ~14 minutes on 8 cores). The library now has 38 puzzles covering all 20 techniques. Unlocking now needs one solved puzzle per technique of the level below. A test replays every library puzzle step by step against its true solution.
- Random puzzle button done. The Practice tab has a "Random puzzle" card: choose an unlocked level (1-5) and play. `findPuzzleOfLevel` (`lib/engine/puzzle_finder.dart`) generates puzzles and rates each until one needs exactly that level, yielding between attempts so the app stays responsive, with a Cancel button. Random puzzles are not saved and do not count towards unlocking. The solved screen offers "New random puzzle".
- Daily puzzle done. A card at the top of the Practice tab offers one puzzle per calendar day, the same for everyone: the level follows the weekday (Mon 1, Tue 2, Wed 3, Thu 4, Fri 4, Sat 5, Sun 5). It is generated from the date with `SeededRandom`, a small xorshift generator whose output is pinned by tests, so every device and platform (checked on the VM and in Chrome) gets the same puzzle. Results count towards a "days in a row" streak, not towards unlocking. Today's puzzle and game are saved; older ones are dropped, but results stay for the streak. The generator now uses its own shuffle for the same reason. A test pins two dates' puzzles: if you change the generator or rater on purpose, update them (it changes everyone's daily puzzle).
- Next: chains (level 6) if wanted, more puzzles per technique, sharing results.
- Practice puzzles are missing for Full House, Hidden Single, Box/Line Reduction, triples, Swordfish, quads and Jellyfish (the lesson says so). Needs the rater and curation work.
- Still to do in the engine: rater and puzzle curation (about 15% of random unique puzzles still stall after level 5, they need chains).
- `tool/find_puzzles.dart [count] [seed]` generates random unique puzzles and prints an example per hardest technique, for curating fixtures.
- Run: `dart run tool/solve.dart <puzzle>` and `flutter test test/engine` (Flutter SDK is at `~/flutter/bin`, not on PATH).

## Build order

1. **Engine foundation:** `Board`, units/peers, parser, pretty-printer, candidate setup.
2. **Level 1 techniques** (full house, naked single, hidden single) plus the `Solver` loop and `tool/solve.dart` CLI. At this point easy puzzles solve end to end with explanations.
3. **Backtracking fallback** and uniqueness checker, so puzzles can be validated.
4. **Level 2 and 3 techniques** (locked candidates, subsets). Add the rater.
5. **Level 4 techniques** (fish, Y-Wing, Skyscraper).
6. **Level 5 techniques.** Stretch: level 6.
7. **Curate puzzles**: for each technique, find a puzzle that *requires* it (solver stuck without it). Use this as the test suite.
8. **Flutter integration:** hint button ("which technique applies here?"), step-by-step replay with highlighted cells, a lesson per technique with practice puzzles.

## Testing approach

- For each technique: a minimal hand-built board where exactly that technique applies, with an assertion on the expected placements/eliminations. This is also the example shown in that technique's lesson.
- For the solver: run the curated puzzles, assert the rating and that the final board is valid and matches the backtracking solution.
- Safety check: no technique may ever eliminate the true solution digit. Run it against many puzzles to prove the techniques are sound.

## Game and teaching features (after the engine works)

- **Hint system:** nudge first ("look at box 5"), then name the technique, then show the exact move.
- **Technique lessons:** short explanation, animated example, then 3 practice puzzles that need it.
- **Puzzle generator:** build a puzzle, check uniqueness, rate it, keep it if it matches the target level.
- **Progress:** unlock the next technique after the player solves practice puzzles with the current one.

## Definition of done (engine milestone)

- The engine solves puzzles for levels 1-5 using only named techniques, with a readable explanation for every step.
- Each technique has a unit test and a worked example.
- The rater classifies the curated puzzles correctly.
- The CLI prints a full walkthrough for any puzzle.
- No technique is ever unsound (never removes the true answer).

## Open questions

- Where do curated puzzles come from: hand-picked from public collections, or generated by our own generator?
