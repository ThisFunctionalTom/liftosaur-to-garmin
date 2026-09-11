import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fetchHistory } from '../api.js';

test('reject malformed history, unsafe IDs, and pagination that cannot advance', async t => {
  for (const data of [
    {}, { records: [{ id: 9007199254740992, text: 'text' }] },
    { records: [{ id: 1, text: 2 }] },
    { records: [{ id: 1, text: 'text' }], hasMore: true },
    { records: [{ id: 1, text: 'text' }], hasMore: true, nextCursor: 42 },
    { records: [], hasMore: true, nextCursor: 43 },
  ]) {
    t.mock.method(globalThis, 'fetch', async () => Response.json({ data }));
    await assert.rejects(fetchHistory('test', 42), /unexpected workout format|invalid next page/);
    t.mock.restoreAll();
  }
});

test('network and server errors never echo response content', async t => {
  t.mock.method(globalThis, 'fetch', async () => { throw new Error('secret response'); });
  await assert.rejects(fetchHistory('test'), { message: 'Could not reach Liftosaur. Check your connection and try again.' });
  t.mock.restoreAll();
  t.mock.method(globalThis, 'fetch', async () => new Response('secret response', { status: 503 }));
  await assert.rejects(fetchHistory('test'), { message: 'Liftosaur returned an error (503). Try again later.' });
});
