// Runs web/scan/scan.js in headless Chromium over the images made by
// gen_images.py and reports how many digits it read right. See README.md.
const http = require('http'), fs = require('fs'), path = require('path');
const { chromium } = require('playwright-core');

const imagesDir = path.resolve(process.argv[2] || 'images');
const scanDir = path.resolve(__dirname, '../../web/scan');
const chrome = process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const types = { '.html': 'text/html', '.js': 'text/javascript', '.jpg': 'image/jpeg', '.gz': 'application/gzip' };

const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  let file;
  if (url === '/') {
    res.writeHead(200, { 'content-type': 'text/html' });
    return res.end('<!doctype html><base href="/"><script src="scan/scan.js"></script>');
  } else if (url.startsWith('/scan/')) file = path.join(scanDir, url.slice(6));
  else if (url.startsWith('/images/')) file = path.join(imagesDir, url.slice(8));
  else { res.writeHead(404); return res.end(); }
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'content-type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(0, async () => {
  const browser = await chromium.launch({ executablePath: chrome, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.goto(`http://localhost:${server.address().port}/`);
  const truth = JSON.parse(fs.readFileSync(path.join(imagesDir, 'truth.json')));
  const total = { right: 0, wrong: 0, silent: 0, missed: 0, images: 0 };
  for (const [name, answer] of Object.entries(truth)) {
    const result = await page.evaluate(async (f) => {
      try {
        const blob = await (await fetch('/images/' + f)).blob();
        return await window.sudokuScan.readFile(new File([blob], f));
      } catch (e) { return { error: String(e.message || e) }; }
    }, name + '.jpg');
    if (result.error) { console.log(name, 'ERROR', result.error); continue; }
    let right = 0, wrong = 0, silent = 0, missed = 0;
    for (let i = 0; i < 81; i++) {
      const want = answer[i], got = result.text[i];
      if (want === got) { if (want !== '0') right++; }
      else if (got === '0') missed++;
      else if (want !== '0') { wrong++; if (!result.uncertain.includes(i)) silent++; }
    }
    console.log(name.padEnd(18), `right ${right} wrong ${wrong} (unflagged ${silent}) missed ${missed}`);
    total.right += right; total.wrong += wrong; total.silent += silent; total.missed += missed; total.images++;
  }
  console.log('TOTAL', JSON.stringify(total));
  await browser.close();
  server.close();
});
