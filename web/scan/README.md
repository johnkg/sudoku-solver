# Vendored OCR files

`scan.js` is our code: it finds the grid in a photo, flattens it, and reads each
cell. The rest of this folder is third-party [Tesseract.js](https://github.com/naptha/tesseract.js)
and Tesseract OCR, copied here so the scan works offline and from GitHub Pages
without a CDN.

| File | What it is |
| --- | --- |
| `tesseract.min.js`, `worker.min.js` | Tesseract.js (Apache-2.0, see `tesseract.min.js.LICENSE.txt`) |
| `tesseract-core-lstm.wasm.js` | Tesseract core, plain WebAssembly (Apache-2.0, see `LICENSE.tesseract-core.txt`) |
| `tesseract-core-simd-lstm.wasm.js` | Same core, SIMD build, used when the browser supports it |
| `eng.traineddata.gz` | English trained data (Apache-2.0) |

## Cost

These files add about 10 MB to the deployed site but **cost visitors nothing
until they scan**: `scan.js` is the only file the page loads up front, and it
adds the others (`getWorker` in `scan.js`) the first time someone scans a photo.
The browser's normal HTTP cache keeps them after that.

## Integrity

`SHA256SUMS` lists the hash of each vendored file. CI checks it, so an edit or a
bad merge cannot change them by accident.

```sh
cd web/scan && sha256sum -c SHA256SUMS
```

## Updating

The exact upstream version was not recorded when these files were added. When
you next update them:

1. Take `tesseract.min.js`, `worker.min.js`, both `tesseract-core*-lstm.wasm.js`
   files and `eng.traineddata.gz` from the same Tesseract.js release.
2. Write the version number in this file.
3. Regenerate the hashes: `cd web/scan && sha256sum <files> > SHA256SUMS`.
4. Re-run the photo checks in [`tool/scan/README.md`](../../tool/scan/README.md).
