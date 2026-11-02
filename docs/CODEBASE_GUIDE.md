# Codebase guide

A tour of the Sudoku Technique Teacher code: what the app does in plain words,
what every file is for, and how to change things without breaking them.

- [1. The app in plain words](#1-the-app-in-plain-words)
- [2. The flow, step by step](#2-the-flow-step-by-step)
- [3. How the code is organised](#3-how-the-code-is-organised)
- [4. File by file](#4-file-by-file)
- [5. How to maintain it](#5-how-to-maintain-it)

---

## 1. The app in plain words

Imagine a friend who is really good at Sudoku and sits next to you. They never
just say "the answer is 7". Instead they say: "Look at this row. Only one
square can hold a 7, because all the other squares are already taken. That
trick is called a **Hidden Single**."

That is this app. It knows 22 tricks (called **techniques**), sorted from
easiest to hardest. It has four parts, which you reach from the bottom bar:

| Tab | What it is, for a 10 year old |
| --- | --- |
| **Learn** | A set of lessons, one per trick. Each lesson shows a small board "before" and "after" so you can see the trick work, then a short quiz. |
| **Practice** | Puzzles to play. Some are picked because they need a particular trick. There is also a **daily puzzle** that is the same for everyone, and random puzzles. |
| **Solver** | Type in (or paste, or photograph) any Sudoku and watch the app solve it one trick at a time, explaining each move. |
| **Menu (top right)** | Cheat sheet of all tricks, your stats and awards, settings, and a reset button. |

Everything runs on your own device. There is no server, no account and no
internet needed. Your progress is saved on the device.

### The two big ideas

1. **The engine is a brain with no face.** It knows the rules and the tricks,
   but it cannot draw anything. It lives in `lib/engine/`.
2. **The screens are a face with no brain.** They draw boards and buttons and
   ask the engine what to do. They live in `lib/ui/`.

Keeping those apart is why the engine can be tested quickly and why changing a
button never breaks a Sudoku rule.

---

## 2. The flow, step by step

### Opening the app

1. `main.dart` starts. It loads your saved progress (`ProgressStore`) and your
   settings (`Settings`). If you opened a shared link with a puzzle in it, it
   remembers that too.
2. It starts `SudokuApp` (`ui/app.dart`), which shows the bottom bar with
   **Learn**, **Practice** and **Solver**.
3. `ProgressScope` hands the progress to every screen, so any screen can ask
   "did the player solve this?" without passing it around by hand.

### Learning a trick

1. **Learn tab** (`learn_tab.dart`) lists lessons grouped into 5 levels. A level
   is locked until you have solved a practice puzzle for the level below
   (`unlocking.dart`).
2. Tap a lesson: **Lesson screen** (`lesson_screen.dart`) shows the idea, how to
   spot it, and a before/after board. The board is drawn by `BoardView`.
3. The example board is built by hand in `lessons/lessons.dart`, but the move
   shown on it is **found by the real engine**, so a lesson can never disagree
   with the solver.
4. Tap the quiz: **Quiz screen** shows boards where the trick applies and asks
   you to spot it. Your answers are saved as "right" or "wrong" per technique.
   The Practice tab later uses those to show your **weak spots**.

### Playing a puzzle

1. **Practice tab** (`practice_tab.dart`) lists puzzles from the library
   (`puzzle_library.dart`), the daily puzzle, a random-puzzle card and a
   "practise a technique" card.
2. Tapping a puzzle opens the **Solve screen** (`solve_screen.dart`). The screen
   itself is small. The real game state lives in `SolveController`
   (`solve_controller.dart`): the board, your notes, mistakes, hints and the undo
   history.
3. You tap a cell, then a digit. The controller checks it against the puzzle's
   one true solution:
   - Wrong digit: it is shown in red, counted as a mistake, and kept off the
     board.
   - Right digit: it is placed, your notes around it are cleaned up, and a
     finished row, column or box flashes.
4. **Hints come in three steps** (`hint_ladder.dart`): first *where to look*, then
   *which technique*, then *the exact move*. Asking for a hint counts against
   your stars.
5. Every change goes to `SolveRecorder` (`solve/solve_recorder.dart`). While you
   play, it saves the game so you can leave and come back. When you finish, it
   records stars, unlocks levels and checks for new achievements.
6. Random, technique and custom puzzles are *practice only*: they are not saved
   and do not unlock anything.

### The daily puzzle

The date is turned into a number (`dailySeed`), which seeds a random number
generator that gives the same numbers on every device (`SeededRandom`). So
everybody gets the same puzzle on the same day, with no server. The weekday
sets the difficulty: easy on Monday, hardest on the weekend.

### Using the Solver tab

1. You type digits, paste 81 characters, open a shared link, or (web only) scan
   a photo.
2. **Teach me** counts the solutions (`countSolutions`). Zero solutions: it tells
   you. More than one: it warns you. Then it opens the **Walkthrough screen**.
3. The walkthrough asks the engine for the next step, applies it, and repeats
   until the board is solved or no technique helps. You can **watch**, or switch
   to **Your turn** and try to find each move first.
4. **Play this puzzle myself** opens the normal Solve screen instead.

### How the engine solves like a person

```
Board with pencil marks (candidates)
        |
        v
 try technique 1 (easiest) -> found something? -> make a Step, apply it, start over
        | no
        v
 try technique 2 ... and so on up to technique 22
        | none worked
        v
 "stuck": the puzzle needs something harder than this app knows
```

A puzzle's **difficulty** is the hardest technique it truly needs
(`rater.dart`). A plain brute-force solver (`backtracking.dart`) exists only to
check that a puzzle has exactly one solution. It never teaches.

---

## 3. How the code is organised

```
 main.dart
    |
    v
 ui/  (screens and widgets, Flutter)  --reads/writes-->  progress/  settings/
    |                                                       (saved on device)
    | asks
    v
 engine/  (pure Dart, no Flutter)  <--used by--  lessons/
    |
    v
 engine/techniques/  (one class per trick)
```

Rules that keep it tidy:

- `engine/` never imports Flutter. It stays testable with plain Dart.
- `ui/` never contains Sudoku logic. If a screen needs to know "is this move
  right?", it asks the engine.
- Screens are thin. Real logic goes in a controller or helper (for example
  `SolveController`, `SolveRecorder`, `SavedGame`), and each widget gets its
  own small file.
- Shared pieces live in one place and are reused, never copied (see
  [section 5](#shared-helpers-reuse-these)).

---

## 4. File by file

Paths are relative to the repository root. "Public" names are the ones other
files use.

### Top level

| File | What it is for |
| --- | --- |
| `README.md` | Start here: what the app is, how to run and check it. |
| `PLAN.md` | Design, the technique ladder, history and what is next. |
| `CLAUDE.md` | Instructions for the Claude Code assistant working in this repo. |
| `docs/CODEBASE_GUIDE.md` | This file. |
| `pubspec.yaml`, `pubspec.lock` | The package list and its pinned versions. |
| `analysis_options.yaml` | The lint rules `flutter analyze` enforces. |
| `.metadata`, `android/`, `ios/`, `windows/` | Generated platform folders from Flutter. Rarely edited by hand. |
| `web/` | The web build: `index.html`, `manifest.json`, and `web/scan/` (the in-browser photo reader, see below). |

### `lib/engine/`: the brain (pure Dart)

| File | What it does |
| --- | --- |
| `engine.dart` | One import that exports everything in the engine. UI files import this. |
| `bits.dart` | Tiny helpers for candidate **bitmasks**. A cell's pencil marks are stored as nine on/off switches in one number. `digitBit`, `hasDigit`, `popCount`, `digitsOf`, `maxDigit`, `allDigitsMask`. |
| `board.dart` | `Board`: 81 cells, each with a value or a set of candidates. Knows rows, columns, boxes (`Unit`), peers (cells that "see" each other), how to parse text, place a digit, apply a `Step`, and copy itself. `Board.size`, `Board.cellAt`, `Board.clampedCellAt`. |
| `step.dart` | The vocabulary of a solve. `Technique` (the 22 tricks with their level and name), `Step` (one move: which technique, which cells, which digits placed or removed, and the plain-language explanation), `Placement`, `Elimination`, `ChainLink`. |
| `solver.dart` | `Solver`: tries the techniques easiest-first, returns the next `Step`, or runs all the way to a `SolveResult`. |
| `backtracking.dart` | Brute-force search. Counts solutions (`countSolutions`) and finds the answer (`solveByBacktracking`). Used to check puzzles, never to teach. |
| `rater.dart` | `ratePuzzle`: finds the shortest easiest-first set of techniques that solves a puzzle. The last one is what the puzzle truly needs, and gives its level 1-5. |
| `generator.dart` | Makes random full grids and removes clues to make puzzles. Has its own shuffle so results never change between Dart versions. |
| `puzzle_finder.dart` | Keeps generating puzzles until one is right: `findPuzzleOfLevel` (a level), `findPuzzleRequiring` (built around a technique), `findMomentOf` (a board partway through a solve where a technique is next). Shares one attempt loop and supports cancelling. |
| `daily.dart` | `SeededRandom` (same numbers on every device), `dailyLevel`, `dailySeed`, `findDailyPuzzle`. **Changing this changes everyone's daily puzzle.** See [section 5](#the-daily-puzzle-is-pinned). |

### `lib/engine/techniques/`: one file per family of tricks

| File | Techniques inside |
| --- | --- |
| `technique.dart` | `SolvingTechnique`, the interface every trick implements: `find(board)` returns one `Step` or null, and must not change the board. |
| `techniques.dart` | The ordered lists. `legacyTechniques` (the original set, used to rate the daily puzzle so it never changes) and `defaultTechniques` (everything, easiest first, which the solver uses). **Order matters.** |
| `full_house.dart` | Full House: a unit with one empty cell. |
| `naked_single.dart` | Naked Single: a cell with one candidate left. |
| `hidden_single.dart` | Hidden Single: a digit that fits only one cell in a unit. |
| `locked_candidates.dart` | Pointing Pair/Triple and Box/Line Reduction. |
| `naked_subset.dart` | Naked Pair, Triple, Quad (size is a parameter). |
| `hidden_subset.dart` | Hidden Pair, Triple, Quad. |
| `fish.dart` | X-Wing, Swordfish, Jellyfish (size is a parameter). |
| `wings.dart` | Y-Wing, XYZ-Wing, W-Wing. |
| `coloring.dart` | Skyscraper and Simple Coloring. |
| `uniqueness.dart` | Unique Rectangle (types 1 and 2). |
| `chains.dart` | X-Chain and XY-Chain. |
| `strong_links.dart` | Helper: finds the "exactly one of these two cells" pairs that chains and colouring use. |
| `subsets.dart` | Helpers: all ways to pick *n* items, shared group sizes (`pairSize`, `tripleSize`, `quadSize`), `joinCells`. |

### `lib/lessons/`

| File | What it does |
| --- | --- |
| `lessons.dart` | `Lesson` (idea, how to spot it, tagline, and a function that builds the example board), the list of all 22 lessons, and `lessonFor(technique)`. |

### `lib/progress/` and `lib/settings/`: what is remembered

| File | What it does |
| --- | --- |
| `progress/progress_store.dart` | `ProgressStore`: everything saved about the player: solved puzzles and stars (`PuzzleRecord`), games in progress, daily results and streak, right/wrong counts per technique (`TechniqueStat`), whether levels were unlocked. Saved with `shared_preferences`. `ProgressStore.memory()` is the in-memory version for tests. |
| `progress/progress_scope.dart` | `ProgressScope`: makes the store available to every widget and rebuilds screens when it changes. Use `ProgressScope.of(context)` to watch, `.read(context)` to just use. |
| `settings/settings.dart` | `Settings` and `SettingsScope`: haptics, mistake limit, show clock, patterns on the board. Saved to the device. |

### `lib/scan/`: photo to puzzle (web only)

| File | What it does |
| --- | --- |
| `photo_scan.dart` | Picks the right implementation: the web one in a browser, the stub elsewhere. |
| `photo_scan_web.dart` | Calls the JavaScript in `web/scan/scan.js` to read a photo. |
| `photo_scan_stub.dart` | Does nothing on phones and desktop, so the button is hidden there. |
| `scan_result.dart` | `ScanResult` (the 81 characters plus which cells were uncertain) and `ScanFailure`. |

### `lib/util/`

| File | What it does |
| --- | --- |
| `text.dart` | Small formatters used everywhere: `plural`, `formatClock`, `formatDayKey`, `monthName`, `shortMonthName`. |

### `lib/ui/`: the face

**App shell and look**

| File | What it does |
| --- | --- |
| `app.dart` | `SudokuApp`: theme, bottom bar (Learn, Practice, Solver), and the menu (cheat sheet, stats, settings, unlock all, reset). |
| `theme.dart` | `buildTheme`: all colours and component styles, light and dark. |
| `layout.dart` | Named sizes: the `Space` scale, radii, icon sizes, breakpoints, and `useSideBySide` (wide screens show the board next to its panel). |
| `levels.dart` | Level names (Beginner to Expert) and one-line blurbs. |
| `navigation.dart` | `pushScreen` and `openScreen`: the one way to open a screen. |
| `section.dart` | `SectionTitle` and the small icon tile used on long screens. |
| `level_header.dart` | The numbered level heading with a lock, shared by Learn and Practice. |
| `stars.dart` | `Stars`: the 1-3 star row. |

**Learn**

| File | What it does |
| --- | --- |
| `learn_tab.dart` | The lesson list by level, with a "next up" card. |
| `learn_progress.dart` | Whether a lesson's technique has been practised (`isPractised`) and per-level counts. |
| `lesson_screen.dart` | One lesson: idea, how to spot it, before/after board toggle, practice and quiz buttons. |
| `quiz.dart` | Builds quiz questions (a board where a step is available). |
| `quiz_screen.dart` | The quiz UI: spot the technique, get feedback, see a score. |
| `technique_choices.dart` | Picks the wrong answers shown beside the right one in quizzes and "your turn". |
| `cheat_sheet_screen.dart` | Searchable list of every technique (`lessonMatches` does the search). |
| `board_legend.dart` | Explains what the board colours mean. |
| `link_legend.dart` | Explains the lines drawn for chains and colouring. |
| `step_text.dart` | `describeResult`: "Places 5 in R3C4" style summary of a step. |

**Practice**

| File | What it does |
| --- | --- |
| `practice_tab.dart` | The Practice list: daily card, weak spots, random card, technique card, then curated puzzles by level. |
| `puzzle_library.dart` | `PuzzleEntry` and the 42 curated puzzles, at least one per technique. |
| `practice_card.dart` | `PracticeCard` (the card layout) and `openPracticePuzzle` (opens a practice-only solve screen). |
| `random_puzzle.dart` | The random-puzzle card and `playRandomPuzzle`. |
| `technique_puzzle.dart` | The "practise a technique" card and `playTechniquePuzzle`. |
| `daily_puzzle.dart` | The daily card, `playDailyPuzzle`, and `dailyDateLabel`. |
| `daily_calendar.dart` | Month calendar with solved days filled in (on the stats screen). |
| `search_dialog.dart` | `runSearchWithDialog`: shows "Looking for a puzzle…" with Cancel while a search runs. |
| `weak_spots.dart` | `weakSpots`: techniques you get wrong most, with thresholds as named constants. |
| `weak_spots_card.dart` | The card that shows them. |
| `unlocking.dart` | `isLevelUnlocked` and related rules. |

**The board**

| File | What it does |
| --- | --- |
| `board_view.dart` | `BoardView`: the widget. Handles taps and sizing, and hands drawing to the painter. |
| `board/board_painter.dart` | `BoardPainter`: paints cell colours, digits, pencil marks, flashes and screen-reader labels. |
| `board/step_markup.dart` | `StepMarkup`: turns a `Step` into "which cells, which digits, which candidates" for the painter. |
| `board/board_drawing.dart` | Drawing helpers: grid lines, hatching, chain links, centred text, and where a pencil mark sits in a cell. |
| `board_with_panel.dart` | `BoardWithPanel`: board beside its panel on wide screens, above it on narrow ones. |

**Solve screen**

| File | What it does |
| --- | --- |
| `solve_screen.dart` | `SolveScreen`: wires the controller, clock, recorder and dialogs together. |
| `solve_controller.dart` | `SolveController`: the game's state and rules (see the flow above). |
| `saved_game.dart` | `SavedGame` and `Move`: how a game is written to and read back from storage, with checks that reject corrupt data. |
| `hint_ladder.dart` | The three hint stages: `nudgeView`, `patternView`, then the full step. |
| `solve/solve_recorder.dart` | Saves the game and records the result, unlocks and achievements. |
| `solve/move_feedback.dart` | Haptic buzz for mistakes, completed units and moves. |
| `solve/board_keys.dart` | Keyboard play: digits enter, arrows move. |
| `solve/solve_app_bar.dart` | Title plus guide, pause, pencil-marks and start-over buttons. |
| `solve/solve_layout.dart` | Arranges stats, board, tools, pad and panel for wide or narrow screens. |
| `solve/share_daily_result.dart` | Copies the daily result text to the clipboard. |
| `solve/stats_row.dart` | Level, mistakes, hints and clock. |
| `solve/status_line.dart` | One line of feedback for the last move. |
| `solve/tool_bar.dart` | Undo, notes, auto-notes, hint buttons. |
| `solve/number_pad.dart` | The 1-9 keys; a digit placed nine times is dimmed. |
| `solve/step_panel.dart` | Shows the hint at its current stage, or the summary when solved. |
| `solve/summary.dart` | The solved screen: stars, time, next puzzle, share. |
| `solve/paused_board.dart` | Hides the board while paused so you cannot peek. |
| `solve/disabled.dart` | Greys out and blocks its child. |
| `share_result.dart` | Builds the shareable daily text and `appHome` link. |

**Solver tab and walkthrough**

| File | What it does |
| --- | --- |
| `solver_tab.dart` | The type-in grid: selection, keyboard, validation, teach and play actions. |
| `solver/entry_controls.dart` | Everything under the grid: status text, digit keys, paste, clear, scan, link, teach, play. |
| `solver/puzzle_text.dart` | `parsePuzzleText`: 81 characters to cells (blanks are `0 . - _ *`). |
| `solver/import_dialog.dart` | The "Paste a puzzle" dialog. |
| `solver/scan_photo.dart` | Runs the photo scan behind a "Reading the photo…" dialog. |
| `puzzle_link.dart` | Makes and reads shareable links (`?puzzle=…`). |
| `walkthrough_screen.dart` | Steps through a solve; holds watch/your-turn state. |
| `walkthrough/step_panel.dart` | The explanation of the current step. |
| `walkthrough/question.dart` | The "your turn" question: pick a cell and digit, or a technique. |
| `walkthrough/controls.dart` | Watch/Your turn toggle, back/next buttons and slider. |
| `walkthrough/end_panel.dart` | How it ended, your score, techniques used. |
| `walkthrough/technique_link.dart` | A chip that opens a technique's lesson. |

**Shared widgets and other screens**

| File | What it does |
| --- | --- |
| `confirm_dialog.dart` | `confirm`: any two-button question, returns true or false. |
| `digit_keys.dart` | `DigitKeyRow` (the 1-9 buttons) and `digitOfKey` (keyboard digit). |
| `stats_screen.dart` | Totals, streak, fastest times, calendar and achievements. |
| `achievements.dart` | The list of awards; whether each is earned is computed from progress, never stored. |
| `settings_screen.dart` | The settings page. |

### `tool/`: command-line helpers

| File | What it does |
| --- | --- |
| `solve.dart` | `dart run tool/solve.dart <puzzle>` prints a walkthrough in the terminal. |
| `curate.dart` | Searches for new practice puzzles per technique and checks every step is sound. |
| `check_coverage.dart` | Fails if line coverage is under a minimum. CI uses 90%. |
| `scan/` | Scripts for measuring photo-scan accuracy. |

### `web/scan/`: the photo reader

Vendored browser OCR (`tesseract*`, `eng.traineddata.gz`, `worker.min.js`)
plus `scan.js`, which finds the grid in a photo and reads the digits.
`SHA256SUMS` lets CI confirm the vendored files were not changed by accident.
See `web/scan/README.md`.

### `test/`

| Folder | What it covers |
| --- | --- |
| `test/engine/` | Each technique on a hand-built board, soundness (no step may remove the true solution), the rater, the finder, the daily puzzle. |
| `test/progress/` | Saving, loading and statistics. |
| `test/ui/` | Real widgets driven like a user: entry, hints, daily puzzle, quizzes, save and restore, share links, the Solver tab. |
| `test/*.dart` | Accessibility at big text sizes, achievements, lessons, settings, weak spots. |
| `test/support.dart` | Shared test setup (a ready-made app to pump). |

### `.github/`

| File | What it does |
| --- | --- |
| `actions/setup-flutter/action.yml` | The one place that names the Flutter version. |
| `workflows/checks.yml` | Format, analyze, test, coverage (reused by the others). |
| `workflows/ci.yml` | Runs checks and a web build on every pull request. |
| `workflows/pages.yml` | On push to `main`: run checks, build the web app, publish to GitHub Pages. |

---

## 5. How to maintain it

### Before every commit

```sh
dart format .
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart coverage/lcov.info 90
```

CI runs exactly these. Fix problems at the source: never skip or delete a test
to get green.

### Shared helpers: reuse these

| Need | Use |
| --- | --- |
| Open a screen | `pushScreen` / `openScreen` (`ui/navigation.dart`) |
| Ask a yes/no question | `confirm` (`ui/confirm_dialog.dart`) |
| Board plus a panel, responsive | `BoardWithPanel` (`ui/board_with_panel.dart`) |
| Digit buttons 1-9 | `DigitKeyRow` (`ui/digit_keys.dart`) |
| A key press to a digit | `digitOfKey` (`ui/digit_keys.dart`) |
| A card on the Practice tab | `PracticeCard` (`ui/practice_card.dart`) |
| A practice-only solve | `openPracticePuzzle` (`ui/practice_card.dart`) |
| A search with Cancel | `runSearchWithDialog` (`ui/search_dialog.dart`) |
| "3 hints", `m:ss`, month names | `plural`, `formatClock`, `monthName` (`util/text.dart`) |
| Spacing and sizes | `Space.*` and constants in `ui/layout.dart` |
| A puzzle as 81 digits | `Board.toDigits()` / `FoundPuzzle.text` |

If you are about to copy a block of code, stop and look here first. If the
shared piece does not exist yet, create it and use it in both places.

### House rules

- **No magic numbers.** Give every number a named `const` with a short comment
  saying what it means (see `layout.dart`, `board_drawing.dart`).
- **Descriptive names.** `clampedCellAt` beats `cell2`.
- **Small files, one job.** A file past about 300 lines is a hint to split it by
  responsibility. Put a screen's parts in a folder next to it (as `solve/`,
  `solver/`, `walkthrough/` and `board/` do).
- **No Sudoku logic in `ui/`**, and no Flutter in `engine/`.
- **Don't build features nobody uses yet.** Remove dead code instead of leaving
  it "just in case".
- **Keep it readable first.** Only optimise a hot path (the engine) and say why
  in a comment.

### Recipes

**Add a new technique**

1. Add it to the `Technique` enum in `engine/step.dart` with its level and name.
   Enum order is the difficulty order, and `removesCandidates` in
   `ui/technique_choices.dart` relies on it (everything from `pointingPair` on
   removes candidates rather than placing).
2. Write a class that extends `SolvingTechnique` in `engine/techniques/`. It
   returns a `Step` with a plain-language explanation, and must not change the
   board.
3. Add it to `defaultTechniques` in `techniques.dart` at the right position.
   Do **not** add it to `legacyTechniques` (see the daily puzzle warning).
4. Add a lesson in `lessons/lessons.dart` with a hand-built example board.
5. Add a minimal hand-built board test in `test/engine/technique_test.dart`
   where exactly that technique applies.
6. Add at least one practice puzzle (use `tool/curate.dart` to find one) to
   `ui/puzzle_library.dart`. A technique with no puzzle does not hold up level
   unlocking, but players cannot practise it.
7. Run the soundness tests: no step may ever remove the true solution digit.

**Add a practice puzzle**

Find it with `dart run tool/curate.dart <count> <seed>`, which prints
`<technique> <81 digits> <clues> <steps>` and checks every step is sound. Add
the entry to `puzzle_library.dart`; the library tests in `test/ui/solve_flow_test.dart` check its rating.

**Add a setting**

Add the field, its saved key and getter/setter in `settings/settings.dart`,
a control in `ui/settings_screen.dart`, and a test in `test/settings_test.dart`.

**Add a screen**

Put the screen in `ui/`, its sub-widgets in a folder named after it. Open it
with `pushScreen`. If it shows a board next to controls, use `BoardWithPanel`.
Keep state and rules in a controller or helper class, not in the widget.

**Change something about saved data**

`ProgressStore` and `SavedGame` read data written by older versions of the
app. Adding a field? Give it a default when missing. Changing a meaning? Keep
reading the old form. `SavedGame.fromJson` throws on bad data and the Solve
screen then starts fresh, so old or corrupt saves never crash the app.

**Update Flutter**

Change the version in `.github/actions/setup-flutter/action.yml` only, run the
full checks on the new version, then merge.

### Things that bite

<a id="the-daily-puzzle-is-pinned"></a>

- **The daily puzzle is pinned.** It is made from the date with a seeded
  generator and rated with `legacyTechniques`, and tests pin specific dates. If
  you change the generator, `SeededRandom`, the clue floors or the legacy
  techniques, everybody's daily puzzle changes. Only do that on purpose, then
  update the pinned dates in `test/engine/daily_test.dart`.
- **`defaultTechniques` order is the difficulty order.** Changing it changes
  ratings, and which hints players see.
- **Practice-only puzzles must not record progress.** Random, technique and
  custom puzzles pass `recordProgress: false` to `SolveScreen`.
- **Achievements are computed, not stored.** Reset clears them for free; to add
  one, add it to the list in `ui/achievements.dart`.
- **About 15% of random unique puzzles stall after level 5.** They need forcing
  chains (level 6, not built yet). `findPuzzleOfLevel` simply tries again.
- **The photo scan is web only.** Anything that touches it must work with the
  stub, which returns nothing, so `scan/photo_scan.dart` picks the file by
  platform.
- **Vendored files in `web/scan/`** are checked by `SHA256SUMS`. If you update
  them on purpose, regenerate the sums.

### Where to look when something breaks

| Symptom | Start here |
| --- | --- |
| A hint or explanation is wrong | The technique file in `engine/techniques/`, then `ui/hint_ladder.dart` |
| A puzzle gets the wrong level | `engine/rater.dart` and the order in `techniques.dart` |
| Board draws wrongly | `ui/board/board_painter.dart` (colours, marks), `step_markup.dart` (what to show) |
| Game does not resume or save | `ui/solve/solve_recorder.dart`, `ui/saved_game.dart`, `progress/progress_store.dart` |
| A mistake is not counted or a digit is accepted wrongly | `ui/solve_controller.dart` (`_place`) |
| Layout broken on a small phone or with big text | `ui/layout.dart`, `ui/board_with_panel.dart`, `ui/solve/solve_layout.dart`, `test/accessibility_test.dart` |
| Daily puzzle differs between devices | `engine/daily.dart` and the pinned test |
| Photo scan fails | `web/scan/scan.js`, `lib/scan/`, `tool/scan/README.md` |
