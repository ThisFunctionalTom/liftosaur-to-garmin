const historyUrl = 'https://www.liftosaur.com/api/v1/history';

export async function fetchHistory(apiKey, cursor = null, signal, limit = 20) {
  const url = new URL(historyUrl);
  url.searchParams.set('limit', String(limit));
  if (cursor !== null) url.searchParams.set('cursor', String(cursor));
  let response;
  try {
    response = await fetch(url, {
      headers: { Authorization: `Bearer ${apiKey.trim()}` },
      credentials: 'omit', cache: 'no-store', redirect: 'error', signal,
    });
  } catch (error) {
    if (signal?.aborted) throw error;
    throw new Error('Could not reach Liftosaur. Check your connection and try again.');
  }
  if (!response.ok) {
    const errors = {
      401: 'The API key was not accepted. Check it in Liftosaur Settings → API Keys.',
      403: 'Liftosaur API access requires an active premium subscription.',
      429: 'Liftosaur is receiving too many requests. Wait a moment and try again.',
    };
    // Do not echo response bodies: they may contain account information or credentials.
    throw new Error(errors[response.status] || `Liftosaur returned an error (${response.status}). Try again later.`);
  }
  let payload;
  try { payload = await response.json(); }
  catch { throw new Error('Liftosaur returned an unreadable response. Try again.'); }
  const data = payload?.data ?? payload;
  if (!Array.isArray(data?.records) || data.records.some(record =>
    !Number.isSafeInteger(record?.id) || typeof record?.text !== 'string')) {
    throw new Error('Liftosaur returned an unexpected workout format.');
  }
  const hasMore = data.hasMore === true;
  if (hasMore && (!Number.isSafeInteger(data.nextCursor) || data.nextCursor === cursor || !data.records.length)) {
    throw new Error('Liftosaur returned an invalid next page. Try loading your workouts again.');
  }
  return { records: data.records, nextCursor: hasMore ? data.nextCursor : null };
}
