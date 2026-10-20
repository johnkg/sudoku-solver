// Reads a Sudoku from a photo, entirely in the browser.
//
// 1. Binarise the picture and find the biggest connected blob: the grid lines.
// 2. Take its four extreme corners and warp the grid flat (this undoes
//    rotation and most perspective).
// 3. Cut the flat grid into 81 cells, drop line remnants, and send each cell
//    that holds ink to Tesseract (digits 1-9 only).
//
// The Tesseract files in this folder are loaded on demand, only when someone
// scans, so they cost nothing on a normal visit.
(function () {
  'use strict';

  var BASE = new URL('scan/', document.baseURI).href;
  // Photos are scaled down so their longer side is at most this many pixels.
  var MAX_SIDE = 1200;

  // The grid, and the size of each cell once the grid is flattened.
  var GRID = 9;
  var CELLS = GRID * GRID;
  var CELL = 80;
  var SIZE = CELL * GRID;

  // Greyscale from colour: ITU-R BT.601 luma weights.
  var LUMA_RED = 0.299;
  var LUMA_GREEN = 0.587;
  var LUMA_BLUE = 0.114;
  var CHANNELS = 4; // red, green, blue, alpha
  var ALPHA = 3; // where alpha sits among them
  var WHITE = 255;

  // Finding the grid in the whole photo. Ink is a pixel darker than
  // COARSE_RATIO times its neighbourhood's average, over a window of a
  // twelfth of the shorter side.
  var COARSE_WINDOW_DIVISOR = 12;
  var COARSE_MIN_WINDOW = 15;
  var COARSE_RATIO = 0.85;
  // The grid's outline must be roughly square and fill a fair share of the
  // photo.
  var GRID_MIN_ASPECT = 0.6;
  var GRID_MAX_ASPECT = 1.6;
  var GRID_MIN_SHARE = 0.25;

  // A homography has eight unknowns: the 3x3 matrix with its last entry 1.
  var UNKNOWNS = 8;

  // Reading the flattened grid.
  var FLAT_WINDOW = 51;
  var FLAT_RATIO = 0.82;
  // Pixels trimmed from each side of a cell to drop its grid lines.
  var CELL_MARGIN = 6;
  // Smaller ink blobs are specks; a cell needs this much ink, this tall a
  // share of the cell, to hold a digit.
  var MIN_BLOB = 10;
  var MIN_INK = 40;
  var MIN_DIGIT_HEIGHT = 0.3;
  // A digit is redrawn this tall, centred on a square canvas, for OCR.
  var OCR_DIGIT_HEIGHT = 48;
  var OCR_CANVAS = 96;

  // Tesseract settings. Page segmentation modes: one word, one character,
  // one line. Each digit is read in all three, in that order.
  var DIGITS = '123456789';
  var PSM_WORD = '8';
  var PSM_CHAR = '10';
  var PSM_LINE = '7';
  // Readings below this confidence (out of 100) are flagged for the player
  // to check. A reading another mode disagrees with is capped below it.
  var MIN_CONFIDENCE = 70;
  var DISAGREEMENT_CONFIDENCE = 50;

  // ---------------------------------------------------------------- picking

  function pickFile() {
    return new Promise(function (resolve) {
      var input = document.createElement('input');
      input.type = 'file';
      input.accept = 'image/*';
      input.style.display = 'none';
      document.body.appendChild(input);
      var done = false;
      function finish(file) {
        if (done) return;
        done = true;
        input.remove();
        resolve(file);
      }
      input.addEventListener('change', function () {
        finish(input.files && input.files[0] ? input.files[0] : null);
      });
      input.addEventListener('cancel', function () {
        finish(null);
      });
      input.click();
    });
  }

  // ------------------------------------------------------------- tesseract

  var workerPromise = null;

  function loadScript(src) {
    return new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = src;
      s.onload = resolve;
      s.onerror = function () {
        reject(new Error('Could not load ' + src));
      };
      document.head.appendChild(s);
    });
  }

  function getWorker() {
    if (!workerPromise) {
      workerPromise = loadScript(BASE + 'tesseract.min.js')
        .then(function () {
          return Tesseract.createWorker('eng', 1, {
            workerPath: BASE + 'worker.min.js',
            corePath: BASE,
            langPath: BASE,
            gzip: true,
          });
        })
        .then(function (worker) {
          return worker
            .setParameters({
              tessedit_char_whitelist: DIGITS,
              tessedit_pageseg_mode: PSM_CHAR,
            })
            .then(function () {
              return worker;
            });
        });
      workerPromise.catch(function () {
        workerPromise = null;
      });
    }
    return workerPromise;
  }

  // ------------------------------------------------------------ image maths

  function loadGray(file) {
    return createImageBitmap(file).then(function (bitmap) {
      var scale = Math.min(1, MAX_SIDE / Math.max(bitmap.width, bitmap.height));
      var w = Math.max(1, Math.round(bitmap.width * scale));
      var h = Math.max(1, Math.round(bitmap.height * scale));
      var canvas = document.createElement('canvas');
      canvas.width = w;
      canvas.height = h;
      var ctx = canvas.getContext('2d', { willReadFrequently: true });
      ctx.fillStyle = '#fff';
      ctx.fillRect(0, 0, w, h);
      ctx.drawImage(bitmap, 0, 0, w, h);
      var rgba = ctx.getImageData(0, 0, w, h).data;
      var gray = new Float32Array(w * h);
      for (var i = 0; i < w * h; i++) {
        gray[i] =
          LUMA_RED * rgba[i * CHANNELS] +
          LUMA_GREEN * rgba[i * CHANNELS + 1] +
          LUMA_BLUE * rgba[i * CHANNELS + 2];
      }
      return { w: w, h: h, gray: gray };
    });
  }

  // 1 where a pixel is clearly darker than its neighbourhood.
  function binarise(gray, w, h, win, ratio) {
    var integral = new Float64Array((w + 1) * (h + 1));
    for (var y = 0; y < h; y++) {
      var row = 0;
      for (var x = 0; x < w; x++) {
        row += gray[y * w + x];
        integral[(y + 1) * (w + 1) + x + 1] = integral[y * (w + 1) + x + 1] + row;
      }
    }
    var half = win >> 1;
    var ink = new Uint8Array(w * h);
    for (var y2 = 0; y2 < h; y2++) {
      var y0 = Math.max(0, y2 - half);
      var y1 = Math.min(h, y2 + half + 1);
      for (var x2 = 0; x2 < w; x2++) {
        var x0 = Math.max(0, x2 - half);
        var x1 = Math.min(w, x2 + half + 1);
        var sum =
          integral[y1 * (w + 1) + x1] -
          integral[y0 * (w + 1) + x1] -
          integral[y1 * (w + 1) + x0] +
          integral[y0 * (w + 1) + x0];
        var mean = sum / ((x1 - x0) * (y1 - y0));
        ink[y2 * w + x2] = gray[y2 * w + x2] < mean * ratio ? 1 : 0;
      }
    }
    return ink;
  }

  // Connected components (8-way). Returns the label map and, per label, the
  // pixel count, bounding box and the four extreme corners.
  function components(ink, w, h) {
    var labels = new Int32Array(w * h);
    var info = [null];
    var stack = new Int32Array(w * h);
    for (var start = 0; start < w * h; start++) {
      if (!ink[start] || labels[start]) continue;
      var id = info.length;
      var c = {
        count: 0,
        x0: w, y0: h, x1: 0, y1: 0,
        tl: null, tr: null, bl: null, br: null,
        minSum: Infinity, maxSum: -Infinity, minDiff: Infinity, maxDiff: -Infinity,
      };
      var sp = 0;
      stack[sp++] = start;
      labels[start] = id;
      while (sp > 0) {
        var p = stack[--sp];
        var px = p % w;
        var py = (p - px) / w;
        c.count++;
        if (px < c.x0) c.x0 = px;
        if (px > c.x1) c.x1 = px;
        if (py < c.y0) c.y0 = py;
        if (py > c.y1) c.y1 = py;
        var s = px + py;
        var d = px - py;
        if (s < c.minSum) { c.minSum = s; c.tl = [px, py]; }
        if (s > c.maxSum) { c.maxSum = s; c.br = [px, py]; }
        if (d > c.maxDiff) { c.maxDiff = d; c.tr = [px, py]; }
        if (d < c.minDiff) { c.minDiff = d; c.bl = [px, py]; }
        for (var dy = -1; dy <= 1; dy++) {
          var ny = py + dy;
          if (ny < 0 || ny >= h) continue;
          for (var dx = -1; dx <= 1; dx++) {
            var nx = px + dx;
            if (nx < 0 || nx >= w) continue;
            var q = ny * w + nx;
            if (ink[q] && !labels[q]) {
              labels[q] = id;
              stack[sp++] = q;
            }
          }
        }
      }
      info.push(c);
    }
    return { labels: labels, info: info };
  }

  function findGrid(ink, w, h) {
    var found = components(ink, w, h);
    var best = null;
    for (var i = 1; i < found.info.length; i++) {
      var c = found.info[i];
      var bw = c.x1 - c.x0 + 1;
      var bh = c.y1 - c.y0 + 1;
      var aspect = bw / bh;
      if (aspect < GRID_MIN_ASPECT || aspect > GRID_MAX_ASPECT) continue;
      if (Math.min(bw, bh) < Math.min(w, h) * GRID_MIN_SHARE) continue;
      if (!best || bw * bh > best.area) best = { c: c, area: bw * bh };
    }
    if (!best) throw new Error('I could not find the grid in that photo.');
    var c2 = best.c;
    return [c2.tl, c2.tr, c2.br, c2.bl];
  }

  // Solves the system of UNKNOWNS equations for the homography taking the square's corners to
  // [corners] (TL, TR, BR, BL).
  function homography(corners) {
    var src = [[0, 0], [SIZE, 0], [SIZE, SIZE], [0, SIZE]];
    var a = [];
    for (var i = 0; i < src.length; i++) {
      var x = src[i][0], y = src[i][1], u = corners[i][0], v = corners[i][1];
      a.push([x, y, 1, 0, 0, 0, -u * x, -u * y, u]);
      a.push([0, 0, 0, x, y, 1, -v * x, -v * y, v]);
    }
    for (var col = 0; col < UNKNOWNS; col++) {
      var pivot = col;
      for (var r = col + 1; r < UNKNOWNS; r++) {
        if (Math.abs(a[r][col]) > Math.abs(a[pivot][col])) pivot = r;
      }
      var tmp = a[col]; a[col] = a[pivot]; a[pivot] = tmp;
      for (var r2 = 0; r2 < UNKNOWNS; r2++) {
        if (r2 === col) continue;
        var f = a[r2][col] / a[col][col];
        for (var k = col; k <= UNKNOWNS; k++) a[r2][k] -= f * a[col][k];
      }
    }
    var hm = [];
    for (var j = 0; j < UNKNOWNS; j++) hm.push(a[j][UNKNOWNS] / a[j][j]);
    hm.push(1);
    return hm;
  }

  function warp(gray, w, h, corners) {
    var m = homography(corners);
    var out = new Float32Array(SIZE * SIZE);
    for (var y = 0; y < SIZE; y++) {
      for (var x = 0; x < SIZE; x++) {
        var d = m[6] * x + m[7] * y + m[8];
        var u = (m[0] * x + m[1] * y + m[2]) / d;
        var v = (m[3] * x + m[4] * y + m[5]) / d;
        var ix = Math.floor(u), iy = Math.floor(v);
        if (ix < 0 || iy < 0 || ix >= w - 1 || iy >= h - 1) {
          out[y * SIZE + x] = WHITE;
          continue;
        }
        var fx = u - ix, fy = v - iy;
        var p = iy * w + ix;
        out[y * SIZE + x] =
          gray[p] * (1 - fx) * (1 - fy) +
          gray[p + 1] * fx * (1 - fy) +
          gray[p + w] * (1 - fx) * fy +
          gray[p + w + 1] * fx * fy;
      }
    }
    return out;
  }

  // The digit pixels of one cell as a small canvas ready for OCR, or null if
  // the cell is empty.
  function cellImage(ink, row, col, opt) {
    var height = (opt && opt.height) || OCR_DIGIT_HEIGHT;
    var cw = (opt && opt.cw) || OCR_CANVAS;
    var ch = (opt && opt.ch) || OCR_CANVAS;
    var margin = CELL_MARGIN;
    var x0 = col * CELL + margin;
    var y0 = row * CELL + margin;
    var n = CELL - 2 * margin;
    var sub = new Uint8Array(n * n);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) sub[y * n + x] = ink[(y0 + y) * SIZE + x0 + x];
    }
    var found = components(sub, n, n);
    var keep = [];
    var bx0 = n, by0 = n, bx1 = 0, by1 = 0, total = 0;
    for (var i = 1; i < found.info.length; i++) {
      var c = found.info[i];
      if (c.x0 === 0 || c.y0 === 0 || c.x1 === n - 1 || c.y1 === n - 1) continue;
      if (c.count < MIN_BLOB) continue;
      keep.push(i);
      total += c.count;
      bx0 = Math.min(bx0, c.x0); by0 = Math.min(by0, c.y0);
      bx1 = Math.max(bx1, c.x1); by1 = Math.max(by1, c.y1);
    }
    var bh = by1 - by0 + 1;
    if (!keep.length || total < MIN_INK || bh < n * MIN_DIGIT_HEIGHT) {
      return null;
    }

    var bw = bx1 - bx0 + 1;
    var scale = height / bh;
    var canvas = document.createElement('canvas');
    canvas.width = cw;
    canvas.height = ch;
    var ctx = canvas.getContext('2d');
    ctx.fillStyle = '#fff';
    ctx.fillRect(0, 0, cw, ch);
    var tiny = document.createElement('canvas');
    tiny.width = bw;
    tiny.height = bh;
    var tctx = tiny.getContext('2d');
    var data = tctx.createImageData(bw, bh);
    for (var yy = 0; yy < bh; yy++) {
      for (var xx = 0; xx < bw; xx++) {
        var lab = found.labels[(by0 + yy) * n + bx0 + xx];
        var on = lab && keep.indexOf(lab) >= 0;
        var o = (yy * bw + xx) * CHANNELS;
        var val = on ? 0 : WHITE;
        data.data[o] = val; data.data[o + 1] = val; data.data[o + 2] = val;
        data.data[o + ALPHA] = WHITE;
      }
    }
    tctx.putImageData(data, 0, 0);
    ctx.imageSmoothingEnabled = true;
    ctx.drawImage(tiny, (cw - bw * scale) / 2, (ch - bh * scale) / 2, bw * scale, bh * scale);
    return canvas;
  }

  // ------------------------------------------------------------------ read

  function readFile(file, options) {
    return loadGray(file).then(function (img) {
      var coarseWindow = Math.max(
        COARSE_MIN_WINDOW,
        (Math.min(img.w, img.h) / COARSE_WINDOW_DIVISOR) | 1,
      );
      var coarse = binarise(img.gray, img.w, img.h, coarseWindow, COARSE_RATIO);
      var corners = findGrid(coarse, img.w, img.h);
      var flat = warp(img.gray, img.w, img.h, corners);
      var ink = binarise(flat, SIZE, SIZE, FLAT_WINDOW, FLAT_RATIO);

      var cells = [];
      for (var i = 0; i < CELLS; i++) {
        cells.push(cellImage(ink, Math.floor(i / GRID), i % GRID, options));
      }
      var inked = cells.filter(Boolean).length;
      if (inked === 0) throw new Error('I could not see any digits in the grid.');

      return getWorker().then(function (worker) {
        var digits = new Array(CELLS).fill('0');
        var uncertain = [];
        var confidences = {};
        var chain = Promise.resolve();
        function recognize(canvas, mode) {
          return worker
            .setParameters({ tessedit_pageseg_mode: mode })
            .then(function () {
              return worker.recognize(canvas);
            })
            .then(function (res) {
              var m = /[1-9]/.exec(res.data.text || '');
              return { digit: m ? m[0] : null, confidence: res.data.confidence };
            });
        }
        cells.forEach(function (canvas, idx) {
          if (!canvas) return;
          chain = chain
            .then(function () {
              var modes =
                (options && options.modes) || [PSM_WORD, PSM_CHAR, PSM_LINE];
              if (!options || options.vote !== false) {
                // Ask every layout, take the first answer, and flag the
                // cell if another layout disagrees.
                return modes.reduce(function (p, m) {
                  return p.then(function (all) {
                    return recognize(canvas, m).then(function (r) {
                      all.push(r);
                      return all;
                    });
                  });
                }, Promise.resolve([])).then(function (all) {
                  var seen = all.filter(function (r) { return r.digit; });
                  if (!seen.length) return all[0];
                  var best = seen[0];
                  var disagree = seen.some(function (r) { return r.digit !== best.digit; });
                  return {
                    digit: best.digit,
                    confidence: disagree
                      ? Math.min(best.confidence, DISAGREEMENT_CONFIDENCE)
                      : best.confidence,
                  };
                });
              }
              var p = recognize(canvas, modes[0]);
              modes.slice(1).forEach(function (m) {
                p = p.then(function (r) {
                  return r.digit ? r : recognize(canvas, m);
                });
              });
              return p;
            })
            .then(function (res) {
              if (res.digit) digits[idx] = res.digit;
              confidences[idx] = res.confidence;
              if (!res.digit || res.confidence < MIN_CONFIDENCE) {
                uncertain.push(idx);
              }
            });
        });
        return chain.then(function () {
          var result = { text: digits.join(''), uncertain: uncertain, found: inked, confidences: confidences };
          if (options && options.debug) {
            result.cells = cells.map(function (c) { return c ? c.toDataURL() : null; });
          }
          return result;
        });
      });
    });
  }

  window.sudokuScan = { pickFile: pickFile, readFile: readFile };
})();
