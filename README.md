# Sudoku Technique Teacher

A Flutter app that teaches Sudoku by solving it the way a person does: one
named technique at a time, with a plain-language explanation of every step. It
is not a black-box solver. Puzzles are rated by the hardest technique they
need, so the app can pick the right puzzle for each lesson.

It runs on-device and offline. The engine is pure Dart with no server.

## What is in it

- **Learn**: 22 lessons, one per technique, from Full House to XY-Chain. Each
  has a worked before/after example drawn on the board, plus a quiz.
- **Practice**: curated puzzles per level, a daily puzzle (same for everyone,
  with a streak), random puzzles at a chosen level, and a puzzle built around a
  technique you pick.
- **Solve**: play with notes, mistakes checked against the unique solution, a
  three-step hint ladder (where to look, which technique, the move), undo, and
  a step-by-step guide.
- **Solver**: paste or type any puzzle, or scan one from a photo (web only), and
  watch the walkthrough.
- **Progress**: stars, unlocking by level, achievements, stats and weak spots,
  saved on the device.

The technique ladder is in [PLAN.md](PLAN.md).

## Run it

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(stable; CI pins the version in
[`.github/actions/setup-flutter/action.yml`](.github/actions/setup-flutter/action.yml)).

```sh
flutter pub get
flutter run -d chrome          # or any device
dart run tool/solve.dart <81-digit puzzle>   # walkthrough in the terminal
```

## Check it

CI runs the same four steps on every pull request:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart coverage/lcov.info 90   # needs 90% of lines
```

Format with `dart format .`. Lints are set in `analysis_options.yaml`.

## Layout

```
lib/
  engine/     pure Dart, no Flutter: board, techniques, solver, rater,
              generator, daily puzzle. Fully testable with plain `dart test`.
    techniques/   one file per family (singles, subsets, fish, wings, chains…)
  lessons/    lesson text and worked examples (found by the real engine)
  progress/   saved games, stars, streaks (shared_preferences)
  settings/   player settings
  scan/       photo scan bridge (web only; a stub elsewhere)
  ui/         screens and widgets
    solve/        the parts of the Solve screen (board tools, pad, stats, summary)
  util/       small shared helpers: text, clock and day-key formatting
tool/         command-line scripts (solve, curate puzzles, coverage check)
test/         engine, progress and UI tests
web/scan/     browser OCR for the photo scan (see web/scan/README.md)
```

Shared UI helpers worth reusing instead of copying:

| Need | Use |
| --- | --- |
| Open a screen | `pushScreen` / `openScreen` in `ui/navigation.dart` |
| A card on the Practice tab | `PracticeCard` in `ui/practice_card.dart` |
| "1 hint", "3 hints" | `plural` in `util/text.dart` |
| `m:ss` timer text | `formatClock` in `util/text.dart` |
| `yyyy-MM-dd` storage key | `formatDayKey` in `util/text.dart` |
| A puzzle as 81 digits | `Board.toDigits()` / `FoundPuzzle.text` |

## Deploy

Pushing to `main` runs the checks, builds the web app and publishes it to
GitHub Pages (`.github/workflows/pages.yml`).

## More

- [PLAN.md](PLAN.md): design, technique ladder and project history.
- [tool/scan/README.md](tool/scan/README.md): measuring photo-scan accuracy.
- [web/scan/README.md](web/scan/README.md): the vendored OCR files.
