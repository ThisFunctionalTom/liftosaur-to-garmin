import { convertWorkout } from './fit.js';

const input = document.querySelector('#workout');
const status = document.querySelector('#status');
const download = document.querySelector('#download');
let downloadUrl;

function clearDownload() {
  if (downloadUrl) URL.revokeObjectURL(downloadUrl);
  downloadUrl = undefined;
  download.hidden = true;
  download.removeAttribute('href');
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
    status.textContent = `${result.name}: ${result.sets} completed sets. Your FIT file is ready.`;
  } catch (error) {
    status.textContent = `Could not convert this workout: ${error.message}`;
  }
});
window.addEventListener('pagehide', clearDownload);
