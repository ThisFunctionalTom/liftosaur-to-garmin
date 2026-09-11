const installButton = document.querySelector('#install-app');
const updateButton = document.querySelector('#update-app');
const appStatus = document.querySelector('#app-status');
const connectionStatus = document.querySelector('#connection-status');
let installPrompt;

function updateConnection() {
  connectionStatus.hidden = navigator.onLine;
  connectionStatus.textContent = 'You’re offline. You can convert already loaded workouts. Loading history needs a connection.';
}
window.addEventListener('online', updateConnection);
window.addEventListener('offline', updateConnection);
updateConnection();

window.addEventListener('beforeinstallprompt', event => {
  event.preventDefault();
  installPrompt = event;
  installButton.hidden = false;
});
installButton.addEventListener('click', async () => {
  if (!installPrompt) return;
  const prompt = installPrompt;
  installPrompt = undefined;
  installButton.hidden = true;
  try { await prompt.prompt(); await prompt.userChoice; }
  catch { appStatus.textContent = 'Use your browser menu to install this app.'; }
});
window.addEventListener('appinstalled', () => {
  installPrompt = undefined;
  installButton.hidden = true;
  appStatus.textContent = 'App installed. You can open it from your home screen.';
});

if (import.meta.env.PROD && 'serviceWorker' in navigator) {
  let reloading = false;
  let requestedUpdate = false;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (requestedUpdate && !reloading) { reloading = true; location.reload(); }
  });
  navigator.serviceWorker.register(new URL('sw.js', document.baseURI), { updateViaCache: 'none' }).then(registration => {
    function showUpdate() {
      if (!registration.waiting) return;
      updateButton.hidden = false;
      appStatus.textContent = 'An update is ready. Convert any selected workouts before reloading.';
    }
    updateButton.addEventListener('click', () => {
      if (!registration.waiting) return;
      requestedUpdate = true;
      registration.waiting.postMessage('ACTIVATE_UPDATE');
    });
    showUpdate();
    registration.addEventListener('updatefound', () => {
      const worker = registration.installing;
      worker?.addEventListener('statechange', () => {
        if (worker.state === 'installed') {
          if (navigator.serviceWorker.controller) showUpdate();
          else appStatus.textContent = 'Ready to reopen offline. Loading workouts needs a connection.';
        }
      });
    });
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') registration.update().catch(() => {});
    });
  }).catch(() => {
    appStatus.textContent = 'Offline setup did not finish. Reopen the app while online to try again.';
  });
}
