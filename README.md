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
   shared sources with Fable and compare generated FIT messages against the CLI.
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
- `liftosaur2garmin.fsx`: CLI and Garmin .NET SDK encoding.

The shared files have no HTTP, filesystem, or Garmin SDK dependencies. Browser
compatibility will be verified in step 2; extraction alone does not verify Fable
compilation. Garmin-specific exercise mappings remain with the .NET encoder for now.

## Checks

```powershell
dotnet fsi conversion.tests.fsx
dotnet fsi liftosaur.tests.fsx
dotnet fsi syncPrograms.tests.fsx
```

These checks use synthetic workouts and mocked HTTP responses; no API key is needed.
