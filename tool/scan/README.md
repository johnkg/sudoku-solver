# Checking the photo scan

`web/scan/scan.js` reads a Sudoku from a photo. These two scripts measure how
well, on generated photos with known answers. They are not part of the app or
of `flutter test`.

```sh
pip install pillow numpy
npm install playwright-core            # any folder; needs a Chromium binary
SEED=11 OUT=images python3 tool/scan/gen_images.py
CHROME=/path/to/chrome node tool/scan/run.js images
```

`gen_images.py` makes 12 variants of each of 4 puzzles: rotation, perspective,
shadows, glare, a curved page, low resolution, heavy JPEG, faint print and a
mix. Change `SEED` and the font list for a fresh set.

`run.js` prints, per image, digits read right, wrong (and how many of those
the scanner did not flag as unsure) and missed. A wrong digit that is *not*
flagged is the failure that matters: the player is not told to check it.

Results when this was written: three sets from `gen_images.py` (different
seeds, puzzles and fonts; 144 images) plus an earlier, simpler set (18
images): 4 566 digits, 4 557 read right, 8 wrong and all 8 flagged as unsure,
1 missed. These are generated images, not phone photos.
