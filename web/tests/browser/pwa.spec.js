import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { Decoder, Stream } from '@garmin/fitsdk';

const app = 'http://127.0.0.1:4174/liftosaur/';
const fixture = readFileSync(new URL('../../../tests/fixtures/standard.txt', import.meta.url), 'utf8');

async function loadWorkout(page) {
  await page.route('https://www.liftosaur.com/api/v1/history*', route => route.fulfill({ json: { records: [{ id: 1, text: fixture }], hasMore: false } }));
  await page.getByLabel('Liftosaur API key', { exact: true }).fill('lftsk_pwa_test_only');
  await page.getByRole('button', { name: 'Load workouts', exact: true }).click();
  await expect(page.locator('#workout-list li')).toHaveCount(1);
  await page.locator('#workout-list input').check();
}

async function openApp(page) {
  await page.goto(app);
  await page.evaluate(async () => { await navigator.serviceWorker.ready; });
  await page.waitForFunction(() => !!navigator.serviceWorker.controller);
}

test('cached app reopens offline and already loaded workouts convert offline', async ({ page, context }) => {
  await openApp(page);
  const manifest = await page.evaluate(async () => {
    const link = document.querySelector('link[rel="manifest"]');
    const data = await (await fetch(link.href)).json();
    return { data, url: link.href };
  });
  expect(new URL(manifest.data.start_url, manifest.url).href).toBe(app);
  expect(new URL(manifest.data.scope, manifest.url).href).toBe(app);
  expect(manifest.data.display).toBe('standalone');
  expect(manifest.data.name).toBe('Liftosaur to Garmin');
  expect(manifest.data.short_name).toBe('Liftosaur to Garmin');
  await expect(page).toHaveTitle('Liftosaur to Garmin');
  for (const icon of manifest.data.icons) {
    const dimensions = await page.evaluate(async url => {
      const image = new Image();
      image.src = url;
      await image.decode();
      return `${image.naturalWidth}x${image.naturalHeight}`;
    }, new URL(icon.src, manifest.url).href);
    expect(dimensions).toBe(icon.sizes);
  }
  await loadWorkout(page);
  const cachedUrls = await page.evaluate(async () => {
    const requests = await Promise.all((await caches.keys()).map(async name => (await caches.open(name)).keys()));
    return requests.flat().map(request => request.url);
  });
  expect(cachedUrls.length).toBeGreaterThan(0);
  expect(cachedUrls.every(url => url.startsWith(app) && !url.includes('history') && !url.includes('lftsk'))).toBe(true);
  await context.setOffline(true);
  await expect(page.locator('#connection-status')).toContainText('You’re offline');
  const pending = page.waitForEvent('download');
  await page.locator('#convert-selected').click();
  await expect(page.locator('#batch-status')).toContainText('Download started');
  const decoder = new Decoder(Stream.fromByteArray(readFileSync(await (await pending).path())));
  expect(decoder.checkIntegrity()).toBe(true);
  await expect(page.locator('a[download]')).toHaveCount(0);
  await page.reload();
  await expect(page.getByLabel('Liftosaur API key', { exact: true })).toHaveValue('');
  await expect(page.locator('#workout-list li')).toHaveCount(0);
  await expect(page.locator('textarea')).toHaveCount(0);
  await expect(page.locator('#connection-status')).toContainText('You’re offline');
  await context.setOffline(false);
  await expect(page.locator('#connection-status')).toBeHidden();
});

test('an update waits for consent, then reloads and cleans only this app’s old cache', async ({ page, request }) => {
  await openApp(page);
  await page.evaluate(() => caches.open('another-app:keep'));
  await loadWorkout(page);
  await request.post('http://127.0.0.1:4174/__update');
  await page.evaluate(async () => { const registration = await navigator.serviceWorker.ready; await registration.update(); });
  await expect(page.getByRole('button', { name: 'Update and reload' })).toBeVisible();
  await expect(page.locator('#workout-list input')).toBeChecked();
  await expect(page.locator('#app-status')).toContainText('Convert any selected workouts');
  await Promise.all([
    page.waitForEvent('load'),
    page.getByRole('button', { name: 'Update and reload' }).click(),
  ]);
  await expect(page.getByLabel('Liftosaur API key', { exact: true })).toHaveValue('');
  await expect(page.locator('#workout-list li')).toHaveCount(0);
  const names = await page.evaluate(() => caches.keys());
  expect(names).toContain('another-app:keep');
  expect(names.filter(name => name.startsWith('liftosaur-app:/liftosaur/:'))).toHaveLength(1);
});
