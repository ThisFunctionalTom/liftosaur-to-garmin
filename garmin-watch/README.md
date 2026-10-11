# Liftosaur for Garmin fēnix 5

Personal Connect IQ watch app for controlling Liftosaur workouts. It previews the
next workout, starts it on the watch, records work sets, runs rest countdowns, and
finishes the Liftosaur session. Liftosaur remains the source of truth for targets,
history, progression, and the next workout.

## First-version scope

- Target: fēnix 5 (Connect IQ API level 3.1, button controls).
- The watch needs a Liftosaur Premium API key, entered in Connect IQ app settings.
- The watch fetches the next workout; Select starts it.
- Select logs a planned set. AMRAP sets open the reps editor; hold Select edits
  reps on any set. Up/Down changes reps in the editor. Select saves the set or
  correction.
- Back during rest skips the timer without undoing the completed set. Back during
  work undoes the most recently logged set.
- Menu opens Finish Early and Discard Workout. The watch vibrates when rest ends.
- Set completions queue on the watch during a connection loss and retry later.
  Fetching and starting a workout require a connection.
- Warmup sets are included before work sets. Supersets, unilateral sets, timed
  sets, RPE prompts, and other prompted set types are not supported in v1; the
  app refuses to start a workout containing them.
- The app writes to Liftosaur only. It does not record a Garmin Connect activity.

Every Liftosaur write includes the required stable device ID and client headers.
The local queue is stored in Connect IQ app storage and survives app restarts.

## State machine and tests

`STATE_MACHINE.md` documents the phases and transitions. Button and rest-timer
events use a reducer in `source/LiftosaurUpdate.mc`; effects are run by the store.
Run the simulator unit tests with:

```powershell
./run-tests.ps1
```

The suite includes memory regression tests for releasing views, repeated
32-set workouts, and repeated corrections with storage writes. These use
synthetic workouts, send no HTTP requests, and use a separate temporary storage
key rather than the saved workout. Test classes are excluded from normal builds.

## Memory investigation

The October 2026 audit found a view/store reference cycle: the view owned the
store, which retained a callback bound to the view. Removing that callback and
requesting UI updates directly reduced retained memory after releasing 20 test
views from 8,320 bytes to zero. App shutdown now stops both timers before saving.
The app normally creates one view, so this cycle alone did not explain growth
after every completed set.

On the fenix 5 simulator, ten repeated synthetic 32-set workouts and 100
corrections with storage writes each showed zero retained growth after warmup.
A live 32-set model originally grew by 9,672 bytes as completion records were
added. With compact arrays it grows by 1,992 bytes; that data is released when
the model is released. Offline queued writes also take
space until acknowledged. These are retained data, not evidence of a leak.

Set records now use fixed-position arrays, accessed through `LiftosaurSet`,
with completed values stored as `[reps, weight]`. The layout is persisted and
its positions must stay stable. Old dictionary-based saves are accepted and
converted on open. Queued writes accept either completion format and convert
to JSON objects at the HTTP boundary. The state machine, exercise records,
messages, and queued action metadata still use dictionaries.

The simulator's comparison for 35 synthetic sets measured allocations for the
set list, excluding application code, other model fields, and HTTP responses:

| Set data | Dictionaries (bytes) | Arrays (bytes) |
| --- | ---: | ---: |
| Planned | 26,688 | 5,416 |
| Completed | 34,808 | 6,920 |

The tests cover old-save migration, storage round trips, API completion payloads,
AMRAP editing, correction, undo, and preserving warmup/support flags.

These tests do not exercise actual HTTP callbacks or establish a safe maximum
workout size. Full workout responses and storage serialization can still create
large temporary peaks. In File > View Memory, click Refresh for each snapshot
and enable Peak Memory Detection before reproducing a peak. Sizes including
children under API Callbacks include the reachable store/model; growth there
does not by itself mean the number of callbacks is increasing.

## Build

Install Garmin's Connect IQ SDK and create a developer key for personal testing.
The SDK is not included in this repository. From this directory, run:

```powershell
./build.ps1
```

The script reads the active SDK path from
`%APPDATA%/Garmin/ConnectIQ/current-sdk.cfg` and uses `~/.garmin/developer_key`
for the signing key. It invokes the SDK's `bin/monkeyc.bat` compiler launcher
(or `monkeyc.exe` if present). Pass `-SdkPath` or `-DeveloperKey` to override
either path.

This writes `bin/Liftosaur.prg`. To launch it in the Garmin simulator, use the
SDK's `monkeydo` command with the fēnix 5 simulator. The real watch must be paired
with a phone running Garmin Connect for Connect IQ HTTP requests.

Open the app's settings in Garmin Connect IQ mobile, enter the Liftosaur API key,
and sync the setting to the watch. API keys are not stored in this repository.

To build the app, start the simulator, and launch it with one command, run:

```powershell
./run-simulator.ps1
```

To build the app and copy it to a watch mounted as `F:\`, run:

```powershell
./install.ps1
```

The script copies `bin/Liftosaur.prg` to `F:\GARMIN\APPS\Liftosaur.prg`.
Pass `-WatchDrive G:` if Windows mounted the watch under another drive letter.
Safely eject the watch after copying, then disconnect it to finish installation.
