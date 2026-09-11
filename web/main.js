import { convertWorkout } from './fit.js';
import './pwa.js';
import { fetchHistory } from './api.js';
import { createDownload, describeRecord } from './downloads.js';

const input = document.querySelector('#workout');
const status = document.querySelector('#status');
const download = document.querySelector('#download');
let downloadUrl;

function clearDownload() {
  if (downloadUrl) URL.revokeObjectURL(downloadUrl);
  downloadUrl = undefined;
  download.hidden = true;
  download.removeAttribute('href');
  document.querySelector('#manual-import').hidden = true;
}

input.addEventListener('input', () => { clearDownload(); status.textContent = ''; });
document.querySelector('#sample').addEventListener('click', () => {
  clearDownload();
  status.textContent = '';
  input.value = `2026-03-01T10:00:00Z / program: "Example" / dayName: "Push Day" / duration: 600s / exercises: {
Bench Press, Barbell / 2x5 100lb / warmup: 1x5 20kg / target: 2x5 100lb 120s
Overhead Press / 1x10 20kg
}`;
});
document.querySelector('#converter').addEventListener('submit', event => {
  event.preventDefault();
  clearDownload();
  try {
    const result = convertWorkout(input.value);
    downloadUrl = URL.createObjectURL(new Blob([result.bytes], { type: 'application/octet-stream' }));
    download.href = downloadUrl;
    download.download = `${result.name.replace(/[^A-Za-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '') || 'workout'}.fit`;
    download.hidden = false;
    download.click();
    document.querySelector('#manual-import').hidden = false;
    status.textContent = `${result.name}: ${result.sets} completed sets. Download started.`;
  } catch (error) {
    status.textContent = `Could not convert this workout: ${error.message}`;
  }
});
window.addEventListener('pagehide', clearDownload);

const keyInput = document.querySelector('#api-key');
const remember = document.querySelector('#remember-key');
const storageStatus = document.querySelector('#storage-status');
const historyStatus = document.querySelector('#history-status');
const loadButton = document.querySelector('#load-workouts');
const cancelButton = document.querySelector('#cancel-load');
const selection = document.querySelector('#workout-selection');
const list = document.querySelector('#workout-list');
const selectAll = document.querySelector('#select-all');
const convertButton = document.querySelector('#convert-selected');
const batchStatus = document.querySelector('#batch-status');
const batchDownload = document.querySelector('#batch-download');
const storageKey = 'liftosaur-converter.api-key';
let records = [];
let selected = new Set();
let pending;
let batchUrl;

try {
  const saved = localStorage.getItem(storageKey);
  if (saved) { keyInput.value = saved; remember.checked = true; }
} catch {
  storageStatus.textContent = 'Browser storage is unavailable. Your key will only be used for this visit.';
}

function savePreference() {
  try {
    if (remember.checked && keyInput.value.trim()) {
      localStorage.setItem(storageKey, keyInput.value.trim());
      storageStatus.textContent = 'Key saved in this browser. Use Forget key to remove it.';
    } else {
      localStorage.removeItem(storageKey);
      storageStatus.textContent = 'Key is not saved in this browser.';
    }
  } catch {
    storageStatus.textContent = 'Could not update browser storage. You can clear this site’s data in browser settings.';
  }
}
remember.addEventListener('change', savePreference);

function clearBatch() {
  if (batchUrl) URL.revokeObjectURL(batchUrl);
  batchUrl = undefined;
  batchDownload.hidden = true;
  batchDownload.removeAttribute('href');
  batchStatus.textContent = '';
  document.querySelector('#batch-import').hidden = true;
}

function updateSelection() {
  const available = records.filter(record => !record.unavailable);
  selectAll.checked = available.length > 0 && selected.size === available.length;
  selectAll.indeterminate = selected.size > 0 && selected.size < available.length;
  selectAll.disabled = !available.length;
  convertButton.disabled = !selected.size || !!pending;
  convertButton.textContent = selected.size ? `Convert selected (${selected.size})` : 'Convert selected';
}

function setLoading() {
  loadButton.disabled = !!pending;
  cancelButton.hidden = !pending;
  updateSelection();
}

function cancelPending() {
  pending?.abort();
  pending = undefined;
  setLoading();
}

function resetHistory() {
  cancelPending();
  records = [];
  selected.clear();
  list.replaceChildren();
  selection.hidden = true;
  historyStatus.textContent = '';
  clearBatch();
  updateSelection();
}

keyInput.addEventListener('input', () => { resetHistory(); savePreference(); });
document.querySelector('#forget-key').addEventListener('click', () => {
  keyInput.value = '';
  remember.checked = false;
  savePreference();
  resetHistory();
  keyInput.focus();
});
cancelButton.addEventListener('click', () => {
  cancelPending();
  historyStatus.textContent = 'Loading cancelled.';
});

function renderRecords() {
  list.replaceChildren();
  for (const record of records) {
    const item = document.createElement('li');
    const label = document.createElement('label');
    label.className = 'choice';
    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.disabled = !!record.unavailable;
    checkbox.checked = selected.has(record.id);
    checkbox.addEventListener('change', () => {
      if (checkbox.checked) selected.add(record.id); else selected.delete(record.id);
      clearBatch();
      updateSelection();
    });
    const description = document.createElement('span');
    description.textContent = record.unavailable
      ? `Workout ${record.id}: cannot convert this record’s format.`
      : `${record.summary.date.toLocaleString()} · ${record.summary.name} · ${record.summary.sets} sets`;
    label.append(checkbox, description);
    item.append(label);
    list.append(item);
  }
  selection.hidden = !records.length;
  updateSelection();
}

async function loadHistory() {
  if (pending || !keyInput.value.trim()) return;
  resetHistory();
  savePreference();
  const controller = new AbortController();
  pending = controller;
  setLoading();
  historyStatus.textContent = 'Loading workouts…';
  let timedOut = false;
  const timeout = setTimeout(() => { timedOut = true; controller.abort(); }, 30000);
  try {
    const page = await fetchHistory(keyInput.value, null, controller.signal, 5);
    if (pending !== controller) return;
    const known = new Set(records.map(record => record.id));
    for (const record of page.records.slice(0, 5)) {
      if (known.has(record.id)) continue;
      known.add(record.id);
      try { records.push({ ...record, summary: describeRecord(record) }); }
      catch { records.push({ ...record, unavailable: true }); }
    }
    renderRecords();
    historyStatus.textContent = records.length
      ? `${records.length} workouts loaded. Select the ones to convert.`
      : 'No workouts found in your Liftosaur history.';
    if (records.length) selection.scrollIntoView({ block: 'start' });
  } catch (error) {
    if (pending !== controller) return;
    historyStatus.textContent = timedOut ? 'Liftosaur took too long to respond. Try again.' : error.message;
  } finally {
    clearTimeout(timeout);
    if (pending === controller) { pending = undefined; setLoading(); }
  }
}

document.querySelector('#history-form').addEventListener('submit', event => {
  event.preventDefault();
  loadHistory();
});
selectAll.addEventListener('change', () => {
  selected = new Set(selectAll.checked ? records.filter(record => !record.unavailable).map(record => record.id) : []);
  clearBatch();
  renderRecords();
});
convertButton.addEventListener('click', () => {
  clearBatch();
  try {
    const result = createDownload(records.filter(record => selected.has(record.id)));
    batchUrl = URL.createObjectURL(new Blob([result.bytes], { type: result.type }));
    batchDownload.href = batchUrl;
    batchDownload.download = result.filename;
    batchDownload.textContent = selected.size === 1 ? 'Download selected FIT' : `Download ZIP (${selected.size} workouts)`;
    batchDownload.hidden = false;
    batchDownload.click();
    document.querySelector('#batch-import').hidden = false;
    batchStatus.textContent = selected.size === 1
      ? 'Workout converted. Download started.'
      : `${selected.size} workouts converted. ZIP download started. Extract the FIT files before importing into Garmin.`;
  } catch {
    batchStatus.textContent = 'Could not convert the selection. Try selecting the workouts individually.';
  }
});
window.addEventListener('pagehide', () => { cancelPending(); clearBatch(); });
