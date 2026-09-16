import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { unzipSync } from 'fflate';
import { Decoder, Stream } from '@garmin/fitsdk';

const fixture = readFileSync(new URL('../../../tests/fixtures/standard.txt', import.meta.url), 'utf8');
const api = 'https://www.liftosaur.com/api/v1/history*';
const fakeKey = 'lftsk_browser_test_only';
const storedKey = 'liftosaur-converter.api-key';

async function load(page) {
  await page.goto('/');
  await page.getByLabel('Liftosaur API key', { exact: true }).fill(fakeKey);
  await page.getByRole('button', { name: 'Load workouts', exact: true }).click();
}

function verifyFit(bytes) {
  const decoder = new Decoder(Stream.fromByteArray(bytes));
  expect(decoder.checkIntegrity()).toBe(true);
  const decoded = decoder.read();
  expect(decoded.errors).toEqual([]);
  expect(decoded.messages.sessionMesgs[0].subSport).toBe('strengthTraining');
}

test('last five workouts fit on screen and Convert starts FIT and ZIP downloads', async ({ page }) => {
  const requests = [];
  await page.route(api, async route => {
    const request = route.request();
    expect(request.method()).toBe('GET');
    expect(request.headers().authorization).toBe(`Bearer ${fakeKey}`);
    expect(request.url()).not.toContain(fakeKey);
    const url = new URL(request.url());
    expect(url.searchParams.get('limit')).toBe('5');
    requests.push(url.searchParams.get('cursor'));
    // Even an oversized response must not create a list longer than five rows.
    const data = { records: Array.from({ length: 7 }, (_, index) => ({ id: index + 1, text: fixture })), hasMore: true, nextCursor: 42 };
    await route.fulfill({ json: { data } });
  });
  await load(page);
  await expect(page.locator('#history-status')).toContainText('5 workouts loaded');
  await expect(page.locator('textarea')).toHaveCount(0);
  await expect(page.locator('#workout-list li')).toHaveCount(5);
  await expect(page.locator('#workout-list li').first()).toBeInViewport();
  await expect(page.locator('#workout-list li').last()).toBeInViewport();
  await expect(page.locator('#convert-selected')).toBeInViewport();
  expect(await page.evaluate(key => localStorage.getItem(key), storedKey)).toBeNull();
  await page.locator('#workout-list input').first().check();
  let pendingDownload = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Convert selected (1)', exact: true }).click();
  let download = await pendingDownload;
  expect(download.suggestedFilename()).toBe('2026-03-01T10-00-00_Push-Day_1.fit');
  verifyFit(readFileSync(await download.path()));
  await expect(page.locator('a[download]')).toHaveCount(0);
  await expect(page.locator('#batch-import a')).toHaveAttribute('href', 'https://connect.garmin.com/app/import-data');
  expect(requests).toEqual([null]);
  await page.getByLabel('Select all loaded workouts').check();
  pendingDownload = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Convert selected (5)', exact: true }).click();
  download = await pendingDownload;
  expect(download.suggestedFilename()).toBe('liftosaur-workouts.zip');
  const files = unzipSync(readFileSync(await download.path()));
  expect(Object.keys(files)).toEqual(Array.from({ length: 5 }, (_, index) => `2026-03-01T10-00-00_Push-Day_${index + 1}.fit`));
  Object.values(files).forEach(verifyFit);
  await page.locator('#workout-list input').first().uncheck();
  await expect(page.locator('#batch-import')).toBeHidden();
});

test('last workout shortcut downloads a valid FIT and opens Garmin import', async ({ page, context }) => {
  await context.route('https://connect.garmin.com/**', route => route.fulfill({ body: 'Garmin import' }));
  await page.route(api, route => {
    expect(new URL(route.request().url()).searchParams.get('limit')).toBe('1');
    expect(route.request().headers().authorization).toBe(`Bearer ${fakeKey}`);
    return route.fulfill({ json: { records: [{ id: 9, text: fixture }, { id: 8, text: fixture }], hasMore: false } });
  });
  await page.goto('/');
  await page.getByLabel('Liftosaur API key', { exact: true }).fill(fakeKey);
  const pendingDownload = page.waitForEvent('download');
  const pendingPopup = page.waitForEvent('popup');
  await page.getByRole('button', { name: 'Send last workout to Garmin', exact: true }).click();
  const download = await pendingDownload;
  expect(download.suggestedFilename()).toBe('2026-03-01T10-00-00_Push-Day_9.fit');
  verifyFit(readFileSync(await download.path()));
  const popup = await pendingPopup;
  await expect(popup).toHaveURL('https://connect.garmin.com/app/import-data');
  expect(await popup.evaluate(() => window.opener)).toBeNull();
  await expect(page.locator('#workout-list li')).toHaveCount(1);
  await expect(page.locator('#history-status')).toContainText('Last workout converted');
});

test('last workout shortcut provides a manual import link when popups are blocked', async ({ page }) => {
  await page.addInitScript(() => { window.open = () => null; });
  await page.route(api, route => route.fulfill({ json: { records: [{ id: 1, text: fixture }], hasMore: false } }));
  await page.goto('/');
  await page.getByLabel('Liftosaur API key', { exact: true }).fill(fakeKey);
  const pendingDownload = page.waitForEvent('download');
  await page.locator('#send-latest').click();
  verifyFit(readFileSync(await (await pendingDownload).path()));
  await expect(page.locator('#batch-import a')).toBeVisible();
  await expect(page.locator('#batch-status')).toContainText('Use Open Garmin import');
});

for (const scenario of [
  { name: 'empty history', response: { json: { records: [], hasMore: false } }, message: 'No workouts found' },
  { name: 'unsupported workout', response: { json: { records: [{ id: 1, text: '{}' }], hasMore: false } }, message: 'Could not convert your last workout' },
  { name: 'API error', response: { status: 401 }, message: 'API key was not accepted' },
]) {
  test(`last workout shortcut closes its waiting tab on ${scenario.name}`, async ({ page }) => {
    await page.route(api, route => route.fulfill(scenario.response));
    await page.goto('/');
    await page.getByLabel('Liftosaur API key', { exact: true }).fill(fakeKey);
    const downloads = [];
    page.on('download', download => downloads.push(download));
    const pendingPopup = page.waitForEvent('popup');
    await page.locator('#send-latest').click();
    const popup = await pendingPopup;
    await expect(page.locator('#history-status')).toContainText(scenario.message);
    await expect.poll(() => popup.isClosed()).toBe(true);
    await expect(page.locator('#send-latest')).toBeEnabled();
    expect(downloads).toEqual([]);
  });
}

test('cancelling the last workout shortcut closes its waiting tab', async ({ page }) => {
  let release;
  const gate = new Promise(resolve => { release = resolve; });
  await page.route(api, async route => {
    await gate;
    await route.fulfill({ json: { records: [{ id: 1, text: fixture }], hasMore: false } }).catch(() => {});
  });
  await page.goto('/');
  await page.getByLabel('Liftosaur API key', { exact: true }).fill(fakeKey);
  const pendingPopup = page.waitForEvent('popup');
  await page.locator('#send-latest').click();
  const popup = await pendingPopup;
  await expect(page.locator('#send-latest')).toBeDisabled();
  await expect(page.locator('#load-workouts')).toBeDisabled();
  await page.getByRole('button', { name: 'Cancel', exact: true }).click();
  release();
  await expect.poll(() => popup.isClosed()).toBe(true);
  await expect(page.locator('#history-status')).toHaveText('Loading cancelled.');
  await expect(page.locator('#send-latest')).toBeEnabled();
  await expect(page.locator('#workout-list li')).toHaveCount(0);
});

test('key persistence is opt-in and Forget key clears account data', async ({ page }) => {
  await page.route(api, route => route.fulfill({ json: { records: [{ id: 1, text: fixture }], hasMore: false } }));
  await load(page);
  await expect(page.locator('#workout-list li')).toHaveCount(1);
  await page.reload();
  await expect(page.getByLabel('Liftosaur API key', { exact: true })).toHaveValue('');
  await page.getByLabel('Liftosaur API key', { exact: true }).fill(fakeKey);
  await page.getByLabel('Remember key on this device').check();
  await page.reload();
  await expect(page.getByLabel('Liftosaur API key', { exact: true })).toHaveValue(fakeKey);
  await page.getByRole('button', { name: 'Load workouts', exact: true }).click();
  await expect(page.locator('#workout-list li')).toHaveCount(1);
  await page.getByRole('button', { name: 'Forget key' }).click();
  await expect(page.getByLabel('Liftosaur API key', { exact: true })).toHaveValue('');
  await expect(page.locator('#workout-list li')).toHaveCount(0);
  expect(await page.evaluate(key => localStorage.getItem(key), storedKey)).toBeNull();
});

test('API errors are safe and retry works; unsupported records cannot be selected', async ({ page }) => {
  let attempt = 0;
  await page.route(api, route => {
    attempt++;
    if (attempt === 1) return route.fulfill({ status: 401, body: `Do not display ${fakeKey}` });
    return route.fulfill({ json: { data: { records: [{ id: 1, text: '{}' }], hasMore: false } } });
  });
  await load(page);
  await expect(page.locator('#history-status')).toContainText('API key was not accepted');
  await expect(page.locator('body')).not.toContainText(fakeKey);
  await page.getByRole('button', { name: 'Load workouts', exact: true }).click();
  await expect(page.locator('#workout-list input')).toBeDisabled();
  await expect(page.locator('#convert-selected')).toBeDisabled();
});

test('empty history and failed refresh clear obsolete selections', async ({ page }) => {
  let attempt = 0;
  await page.route(api, route => {
    attempt++;
    if (attempt === 1) return route.fulfill({ json: { records: [], hasMore: false } });
    if (attempt === 2) return route.fulfill({ json: { records: [{ id: 1, text: fixture }], hasMore: true, nextCursor: 42 } });
    return route.fulfill({ status: 429 });
  });
  await load(page);
  await expect(page.locator('#history-status')).toContainText('No workouts found');
  await page.getByRole('button', { name: 'Load workouts', exact: true }).click();
  await page.locator('#workout-list input').check();
  await page.getByRole('button', { name: 'Load workouts', exact: true }).click();
  await expect(page.locator('#history-status')).toContainText('too many requests');
  await expect(page.locator('#workout-list input')).toHaveCount(0);
  await expect(page.locator('#convert-selected')).toBeDisabled();
});

test('forgetting a key cancels an in-flight request', async ({ page }) => {
  let release;
  const gate = new Promise(resolve => { release = resolve; });
  await page.route(api, async route => {
    await gate;
    await route.fulfill({ json: { records: [{ id: 1, text: fixture }], hasMore: false } }).catch(() => {});
  });
  await load(page);
  await expect(page.locator('#history-status')).toContainText('Loading workouts');
  await page.getByRole('button', { name: 'Forget key' }).click();
  release();
  await expect(page.locator('#workout-list li')).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Load workouts', exact: true })).toBeEnabled();
});

test('live authenticated browser request (explicit opt-in)', async ({ page }) => {
  test.skip(process.env.LIFTOSAUR_LIVE_CHECK !== '1', 'Set LIFTOSAUR_LIVE_CHECK=1 to perform a real read-only API check.');
  expect(Boolean(process.env.LIFTOSAUR_API_KEY)).toBe(true);
  await page.goto('/');
  // Return only status/shape information. Never save or print keys or workout text.
  const result = await page.evaluate(async key => {
    try {
      const response = await fetch('https://www.liftosaur.com/api/v1/history?limit=1', {
        headers: { Authorization: `Bearer ${key}` }, credentials: 'omit', cache: 'no-store',
        redirect: 'error', signal: AbortSignal.timeout(20000),
      });
      if (!response.ok) return { ok: false, status: response.status };
      const payload = await response.json();
      const data = payload.data ?? payload;
      return { ok: true, valid: Array.isArray(data.records) && data.records.every(r => Number.isSafeInteger(r.id) && typeof r.text === 'string') };
    } catch { return { ok: false, networkError: true }; }
  }, process.env.LIFTOSAUR_API_KEY);
  expect(result).toEqual({ ok: true, valid: true });
});
