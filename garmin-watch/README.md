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
