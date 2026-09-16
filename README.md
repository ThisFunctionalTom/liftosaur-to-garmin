# Liftosaur tools

Download Liftosaur workout history and convert it to Garmin FIT activity files:

```powershell
$env:LIFTOSAUR_API_KEY = 'your-key'
dotnet fsi liftosaur2garmin.fsx -- 10 ./fit
```

## Browser app roadmap

1. Extract shared F# parsing, workout types, timeline reconstruction, and naming;
   preserve the CLI and add conversion regression checks. **Done.**
2. Create a Fable browser project and a Garmin JavaScript SDK adapter. Compile the
   shared sources with Fable and compare generated FIT messages against the CLI. **Done.**
3. Add API-key entry, recent-workout selection, and FIT downloads (ZIP for batches).
   Verify authenticated browser requests to Liftosaur. Keep keys out of source and
   deployment artifacts; remembering a key on the device should be optional. **Done.**
4. Add a PWA manifest and service worker. **Implemented and browser-tested.**
   Physical Android installation/download testing follows HTTPS deployment in step 5.
   Local-file import remains a possible later enhancement.
5. Create a GitHub repository, connect it using Jujutsu, and deploy the static app
   to GitHub Pages. **Done: public repository and HTTPS deployment.**

## Shared code

- `shared/WorkoutCore.fs`: workout types and API workout-text parsing.
- `shared/WorkoutConversion.fs`: timeline reconstruction and workout naming.
- `liftosaur.fsx`: .NET API client plus compatibility aliases for existing callers.
- `garminFit.fsx`: Garmin .NET SDK encoding, also used to generate test references.
- `liftosaur2garmin.fsx`: CLI.
- `web/Converter.fs`: Fable boundary using the shared parsing and timeline modules.
- `web/fit.js`: Garmin JavaScript SDK adapter.
- `web/api.js`: read-only browser API client with cursor pagination.
- `web/downloads.js`: workout descriptions, FIT filenames, and ZIP downloads.

The shared files have no HTTP, filesystem, or Garmin SDK dependencies and compile
with Fable. Garmin-specific mappings live in each SDK adapter; fixture comparisons
cover every mapping to detect differences.

## Run the browser converter

Requires .NET SDK 10 and Node.js 22.12+ (tested with 22.19).
From the repository root:

```powershell
dotnet tool restore
npm ci --prefix web
npm run dev --prefix web
```

Open the local URL printed by Vite, enter your Liftosaur API key, and select
**Load workouts**. Select workouts from the list, then **Convert selected**. One
selected workout downloads as FIT; multiple workouts download as a ZIP containing
one FIT per workout. Only the last five workouts are displayed. **Convert selected**
starts the download immediately. To download again, press **Convert selected** again.
**Open Garmin import** opens Garmin Connect Web's import page. Sign in and choose
the FIT file from Downloads; extract a batch ZIP before selecting its FIT files.

For a single-step shortcut, select **Send last workout to Garmin** after entering
your API key. It fetches your latest workout, downloads its converted FIT file,
and opens Garmin's import page. Select the downloaded file there to upload it.
If your browser blocks the tab, use **Open Garmin import** after the download.
On Android, **Open in Android browser** requests an external app handoff using
Android's link settings, with the normal Garmin URL as a fallback. Tap it directly
after downloading; automatic redirects cannot reliably launch external apps.
Android may show an app chooser or use an associated app, so a particular browser
cannot be guaranteed. Normal Custom Tabs share their host browser's cookies; if
Garmin repeatedly asks you to sign in, check which browser/profile is opening it.

Keys are sent directly to Liftosaur in the Authorization header. They stay in memory
unless **Remember key on this device** is selected; that option stores the key in
this browser's localStorage. **Forget key** removes the saved key and clears the
loaded workout list and generated batch download. Workout history is not persisted.
The [Liftosaur API](https://www.liftosaur.com/doc/api) requires Premium.

The app converts workouts fetched from Liftosaur; it has no paste or backup-import area.

For F# edits, rerun `npm run compile --prefix web` (or restart the dev command).
JavaScript and HTML edits are picked up by Vite automatically.

`npm run build --prefix web` produces the standalone static site in `web/dist`.
Asset URLs are relative so it can later be deployed beneath a GitHub Pages project
path. Generated JavaScript, build output, and dependencies are ignored by Jujutsu.

## Install and use offline

The production build includes a manifest, Android launcher icons, and a service
worker. On Android, open the deployed HTTPS site in Chrome, then tap **Install app**
when offered, or use Chrome's menu **Add to home screen / Install app**. Launch it
from its home-screen icon. The browser controls when its install prompt is available.

After the first successful online load, the app can reopen offline. Workouts already
loaded in the current tab can be converted offline, but history is not retained
across reloads. Fetching history needs a connection.
Only the app's static assets are cached; API requests, keys, and workout responses
are never added to the service worker cache. Optional key storage is separate.

When a new version is ready, **Update and reload** appears. Convert any selected
workouts before selecting it: reloading clears loaded history and an unsaved key.
The app does not reload automatically while you are working.

To test the production PWA on this computer:

```powershell
npm run build --prefix web
npm run preview --prefix web
```

Open the printed localhost URL. Service workers are enabled in production builds,
not the Vite development server. A phone opening an ordinary HTTP LAN address is
not sufficient for PWA testing: installation/service workers require HTTPS (localhost
is an exception). See [MDN's installability guide](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable).

After HTTPS deployment, verify on the physical Android phone:

1. Install from Chrome and launch from the home screen in its standalone window.
2. Load history, then download one FIT and a multi-workout ZIP; open them from Downloads.
3. Load workouts, switch to airplane mode, and convert/download a selected workout.
   Reopen offline to verify the shell loads; reconnect to load history again.
4. Reconnect, and verify a future update is offered without interrupting your work.

The launcher source is `web/public/icon.svg`. To regenerate the PNG variants with
installed Edge: set `PLAYWRIGHT_CHANNEL=msedge` and run
`node web/scripts/generate-icons.mjs`. The centered artwork fits Android's maskable safe area.

## GitHub Pages deployment

The [public repository](https://github.com/ThisFunctionalTom/liftosaur-to-garmin)
deploys to [liftosaur-to-garmin](https://thisfunctionaltom.github.io/liftosaur-to-garmin/).
The full publication history, tracked files, and built website passed a Gitleaks
scan before publication, plus checks for embedded Liftosaur API keys.

`.github/workflows/pages.yml` runs the F# tests, FIT comparisons, browser download
checks, and offline/update tests on pushes to `main` and pull requests. Pages deployment
is disabled unless the repository variable `PAGES_ENABLED` is set to `true`.
When enabled, successful main-branch builds publish only `web/dist`. No Liftosaur API
key is needed in GitHub Actions.

Pages uses **Settings → Pages → Build and deployment → GitHub Actions** and the
repository variable `PAGES_ENABLED=true`. The public repository allows Pages on
GitHub Free. No API keys belong in source, build configuration, or workflow secrets;
enter your key in the browser when using the app.

After committing the deployment files with Jujutsu, connect and push the committed
revision (these commands assume it is the working copy's parent):

```powershell
jj git remote add origin https://github.com/ThisFunctionalTom/liftosaur-to-garmin.git
jj bookmark create main -r @-
jj git push --remote origin --bookmark main
```

For later releases, commit changes, move the bookmark with `jj bookmark set main -r @-`,
and push it. The workflow also supports manual runs from GitHub's Actions tab.
Wait for **Build and deploy PWA** to succeed before opening the site on Android.

## Checks

```powershell
dotnet fsi conversion.tests.fsx
dotnet fsi liftosaur.tests.fsx
dotnet fsi syncPrograms.tests.fsx
npm test --prefix web
```

These checks use synthetic workouts and mocked HTTP responses; no API key is needed.
The browser converter tests validate FIT integrity and compare decoded messages
against freshly generated .NET FIT files, ignoring only generated serial numbers.
API tests cover malformed responses, pagination, and error handling. Browser tests
cover selection, FIT and ZIP downloads, optional key storage, and cancellation.
PWA tests serve the production build under `/liftosaur/`, verify icon dimensions and
manifest paths, reopen/convert/download offline, and exercise the waiting-worker
update lifecycle and cache cleanup. These do not substitute for physical Android tests.

For the browser download check using installed Edge on Windows:

```powershell
$env:PLAYWRIGHT_CHANNEL = 'msedge'
npm run test:browser --prefix web
```

Alternatively, run `npx playwright install chromium` from `web` and omit the channel
environment variable. The check runs the production build at a phone-sized viewport;
testing on a physical Android device is still part of step 4.

To include the optional live API check, set `LIFTOSAUR_LIVE_CHECK=1` and provide
`LIFTOSAUR_API_KEY` in the environment before running the browser tests. It makes
one authenticated browser GET request with `limit=1` and checks the response shape;
it does not print or save the key or workout data. This check passed against the
live API during step 3. Ordinary test runs skip it.
