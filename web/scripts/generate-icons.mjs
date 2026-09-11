import { chromium } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

// Rasterize the source SVG for Android launchers; no external images or fonts.
const browser = await chromium.launch({ channel: process.env.PLAYWRIGHT_CHANNEL || undefined });
try {
  const page = await browser.newPage({ deviceScaleFactor: 1 });
  const svg = readFileSync(new URL('../public/icon.svg', import.meta.url), 'utf8');
  for (const [size, filename] of [[192, 'icon-192.png'], [512, 'icon-512.png'], [512, 'icon-maskable-512.png']]) {
    await page.setViewportSize({ width: size, height: size });
    await page.setContent(`<style>body{margin:0}svg{display:block;width:100vw;height:100vh}</style>${svg}`);
    await page.screenshot({ path: fileURLToPath(new URL(`../public/${filename}`, import.meta.url)) });
  }
} finally {
  await browser.close();
}
