// Renders AppIcon-*.svg to 1024x1024 PNGs using the preinstalled Playwright Chromium.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
(async () => {
  const dir = process.argv[2];
  const outDir = process.argv[3];
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
  for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.svg'))) {
    await page.setContent(`<html><body style="margin:0">${fs.readFileSync(path.join(dir, f), 'utf8')}</body></html>`);
    await page.screenshot({ path: path.join(outDir, f.replace('.svg', '.png')), omitBackground: false });
  }
  await browser.close();
})();
