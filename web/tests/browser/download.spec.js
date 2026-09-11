import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { Decoder, Stream } from '@garmin/fitsdk';

test('convert example and download a valid strength activity at phone width', async ({ page }) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('/');
  await page.getByRole('button', { name: 'Try an example' }).click();
  await page.getByRole('button', { name: 'Convert workout' }).click();
  await expect(page.locator('#status')).toContainText('4 completed sets');
  const pendingDownload = page.waitForEvent('download');
  await page.getByRole('link', { name: 'Download FIT' }).click();
  const download = await pendingDownload;
  expect(download.suggestedFilename()).toBe('Push-Day.fit');
  const decoder = new Decoder(Stream.fromByteArray(readFileSync(await download.path())));
  expect(decoder.checkIntegrity()).toBe(true);
  const { messages, errors: decodeErrors } = decoder.read();
  expect(decodeErrors).toEqual([]);
  expect(messages.sessionMesgs[0].subSport).toBe('strengthTraining');
  expect(messages.setMesgs.filter(set => set.setType === 'active')).toHaveLength(4);
  await page.getByLabel('Liftosaur API workout text').fill('invalid workout');
  await expect(page.getByRole('link', { name: 'Download FIT' })).toBeHidden();
  await page.getByRole('button', { name: 'Convert workout' }).click();
  await expect(page.locator('#status')).toContainText('Could not convert');
  expect(errors).toEqual([]);
});
