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
   deployment artifacts; remembering a key on the device should be optional.
4. Add a PWA manifest and service worker, then test installation and downloads on
   Android. Consider local-file import as a later enhancement; the current parser
   consumes API workout text, not arbitrary Liftosaur backup formats.
5. Create a GitHub repository, connect it using Jujutsu, and deploy the static app
   to GitHub Pages. No GitHub repository or hosting is required for steps 1–4.

## Shared code

- `shared/WorkoutCore.fs`: workout types and API workout-text parsing.
- `shared/WorkoutConversion.fs`: timeline reconstruction and workout naming.
- `liftosaur.fsx`: .NET API client plus compatibility aliases for existing callers.
- `garminFit.fsx`: Garmin .NET SDK encoding, also used to generate test references.
- `liftosaur2garmin.fsx`: CLI.
- `web/Converter.fs`: Fable boundary using the shared parsing and timeline modules.
- `web/fit.js`: Garmin JavaScript SDK adapter.

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

Open the local URL printed by Vite. Select **Try an example**, or paste the `text`
field of a Liftosaur API history record, then convert and download the FIT file.
The page processes data locally. API downloads and PWA installation are later steps.
This is not an importer for full Liftosaur JSON backups.

For F# edits, rerun `npm run compile --prefix web` (or restart the dev command).
JavaScript and HTML edits are picked up by Vite automatically.

`npm run build --prefix web` produces the standalone static site in `web/dist`.
Asset URLs are relative so it can later be deployed beneath a GitHub Pages project
path. Generated JavaScript, build output, and dependencies are ignored by Jujutsu.

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

For the browser download check using installed Edge on Windows:

```powershell
$env:PLAYWRIGHT_CHANNEL = 'msedge'
npm run test:browser --prefix web
```

Alternatively, run `npx playwright install chromium` from `web` and omit the channel
environment variable. The check runs the production build at a phone-sized viewport;
testing on a physical Android device is still part of step 4.
