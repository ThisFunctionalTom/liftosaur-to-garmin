# Garmin exercise mappings

Edit [shared/exercise-mappings.json](../shared/exercise-mappings.json).
It is the single mapping source for both the PWA and the F# CLI.
The browser adapter is `web/exercise-mappings.js`; the .NET adapter in
`garminFit.fsx` reads the same JSON and resolves symbols in its own Garmin SDK.
There are no separate JavaScript and F# mapping tables to synchronize.

See the [full catalog coverage report](exercise-catalog-audit.md) for every
built-in exercise, its mapping, and any limitation. The catalog snapshot was
retrieved through Liftosaur MCP on 2026-09-24. Additional historical aliases and
custom imported names are retained separately in the same shared mapping file.

## Matching and mapping decisions

Names match exactly after trimming and lowercasing. Equipment suffixes are
significant. A name with an unspecified equipment suffix uses Liftosaur's default,
checked against its [exercise definitions](https://github.com/astashov/liftosaur/blob/master/src/models/exercise.ts).
For example, Bicep Curl uses dumbbells, Face Pull uses a band, Skullcrusher uses
an EZ bar, and Snatch uses a dumbbell.

Each entry contains an array of names, Garmin category/subtype symbol names, a
quality field, and a note:

- `exact`: a corresponding movement/equipment subtype.
- `generic`: a broader movement subtype, with the lost detail explained.
- `category`: a relevant category but no suitable subtype; subtype is null.
- `unsupported`: no suitable mapping; category and subtype are both null.

Do not strip equipment suffixes or match unfamiliar names by similarity. A machine
press should not silently turn into a dumbbell or barbell press. Do not substitute
a different movement to hide an Unknown label. For example, FIT's crunch
`legExtensions` is not the machine knee-extension exercise; the banded extension
code is used only for the explicitly banded variant.

Assisted pull-ups, chin-ups, and dips use the base movement as a documented
generic match. Assisted exercises export **0 kg added weight**, with assistance
in kg listed in workout step notes in set order (including marked warmups).
Garmin may not display these notes in every activity view. The shared logic in
`shared/WorkoutConversion.fs` recognizes names containing the word `Assisted`,
machine-assisted chin-ups, pull-ups, triceps dips and pistol squats, and band-assisted
pull-ups/chin-ups. Other machine and band exercises retain their resistance weights.
FIT's standard set weight is unsigned, so negative assistance cannot be stored there.

Garmin may still show category-only and unsupported entries as Unknown.
Original exercise names remain in workout step names and notes. FIT profile
support does not guarantee identical exercise labels in every Garmin client.

## Updating and validating

1. Update the shared JSON. Use symbols present in the installed Garmin FIT SDK,
   not guessed numeric codes. Explain all generic or incomplete matches.
2. Refresh `tests/liftosaur-exercises.json` from Liftosaur MCP when its catalog
   changes. This is an independent coverage snapshot, not a generated copy of
   the mapping table.
3. Run `npm run audit:mappings --prefix web` to regenerate the coverage report.
4. Run `npm test --prefix web`. Tests cover every snapshot name, duplicate aliases,
   explicit unsupported decisions, equipment differences, SDK symbol validity,
   and decoded FIT step/set metadata compared with the .NET message writers.
5. Run `npm run build --prefix web` to verify the shared JSON bundles into the PWA.

The .NET CLI requires the shared JSON alongside the repository scripts.
The PWA bundles it locally and continues to convert loaded workouts offline.

Reconvert workouts to include new mappings. Activities already imported into
Garmin are not changed automatically.
