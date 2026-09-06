#r "nuget: Garmin.FIT.Sdk"
#load "liftosaur.fsx"

open System
open System.IO
open System.Text.RegularExpressions
open Dynastream.Fit
open Liftosaur

// ----------------------------------------------------------------------
// CLI
// ----------------------------------------------------------------------

let args =
    fsi.CommandLineArgs
    |> Array.skip 1

if args.Length < 1 then
    failwith
        "Usage: dotnet fsi liftosaur2garmin.fsx -- <n> [output-dir]"

let n = int args[0]

let outputDir =
    if args.Length >= 2 then args[1]
    else "./fit"

let apiKey =
    Environment.GetEnvironmentVariable("LIFTOSAUR_API_KEY")
    |> Option.ofObj
    |> Option.defaultWith (fun () ->
        failwith "Set LIFTOSAUR_API_KEY=lftsk_... first")

Directory.CreateDirectory(outputDir) |> ignore

// ----------------------------------------------------------------------
// Timeline reconstruction
// ----------------------------------------------------------------------

// Rough lifting duration. This is deliberately simple.
//
// 5 reps  -> ~15 sec
// 10 reps -> ~30 sec
// 12 reps -> ~36 sec
let activeDurationSeconds reps =
    max 8.0 (float reps * 3.0)

let sameExercise
    (a: StrengthSet)
    (b: StrengthSet) =
    String.Equals(
        a.Exercise,
        b.Exercise,
        StringComparison.OrdinalIgnoreCase
    )

type TimelineEntry =
    | ActiveSet of StrengthSet * float
    | Rest of string * float
    | Transition of float

let transitionIndices (sets: StrengthSet array) =
    sets
    |> Array.pairwise
    |> Array.mapi (fun index (current, next) ->
        if sameExercise current next then None else Some index)
    |> Array.choose id

let calculateRestScale availableSeconds programmedSeconds =
    if programmedSeconds <= 0.0 || programmedSeconds <= availableSeconds then
        1.0
    else
        availableSeconds / programmedSeconds

let entriesForSet restScale transitionSeconds isTransition set =
    let restSeconds = set.RestAfterSeconds * restScale

    [
        ActiveSet(set, activeDurationSeconds set.Reps)
        if restSeconds > 0.0 then
            Rest(set.Exercise, restSeconds)
        if isTransition && transitionSeconds > 0.0 then
            Transition transitionSeconds
    ]

let buildTimeline (workout: Workout) =
    let sets = List.toArray workout.Sets

    if Array.isEmpty sets then
        []
    else
        let activeSeconds =
            sets |> Array.sumBy (fun set -> activeDurationSeconds set.Reps)

        let programmedRestSeconds =
            sets |> Array.sumBy (fun set -> set.RestAfterSeconds)

        let transitions = transitionIndices sets
        let recordedSeconds = float workout.DurationSeconds
        let availableSeconds = max 0.0 (recordedSeconds - activeSeconds)
        let restScale =
            calculateRestScale availableSeconds programmedRestSeconds

        let leftoverSeconds =
            max 0.0 (
                recordedSeconds
                - activeSeconds
                - programmedRestSeconds * restScale
            )

        let transitionSeconds =
            if Array.isEmpty transitions then 0.0
            else leftoverSeconds / float transitions.Length

        let transitions = Set.ofArray transitions

        sets
        |> Array.mapi (fun index set ->
            entriesForSet
                restScale
                transitionSeconds
                (transitions.Contains index)
                set)
        |> Array.toList
        |> List.concat

// ----------------------------------------------------------------------
// Garmin mapping
// ----------------------------------------------------------------------

// Keeping this separate makes it easy to extend later.
let exerciseCategory (name: string) =
    match name.Trim().ToLowerInvariant() with

    | "bench press"
    | "bench press, barbell" ->
        Some(
            ExerciseCategory.BenchPress,
            BenchPressExerciseName.BarbellBenchPress
        )

    | "squat"
    | "squat, barbell" ->
        Some(
            ExerciseCategory.Squat,
            SquatExerciseName.BarbellBackSquat
        )

    | "deadlift"
    | "deadlift, barbell" ->
        Some(
            ExerciseCategory.Deadlift,
            DeadliftExerciseName.BarbellDeadlift
        )

    | "overhead press"
    | "overhead press, barbell" ->
        Some(
            ExerciseCategory.ShoulderPress,
            ShoulderPressExerciseName.OverheadBarbellPress
        )

    | "bent over row"
    | "bent over row, barbell" ->
        Some(
            ExerciseCategory.Row,
            RowExerciseName.BentOverRowWithBarbell
        )

    | "push up"
    | "push-up" ->
        Some(
            ExerciseCategory.PushUp,
            PushUpExerciseName.PushUp
        )

    | "lat pulldown" ->
        Some(ExerciseCategory.PullUp, UInt16.MaxValue)

    | "hanging leg raise" ->
        Some(ExerciseCategory.LegRaise, UInt16.MaxValue)

    | _ ->
        None

// ----------------------------------------------------------------------
// FIT helpers
// ----------------------------------------------------------------------

let fitEpoch =
    DateTimeOffset(
        1989, 12, 31,
        0, 0, 0,
        TimeSpan.Zero
    )

let fitTime (time: DateTimeOffset) =
    let seconds =
        (time.ToUniversalTime() - fitEpoch)
            .TotalSeconds
        |> uint32

    Dynastream.Fit.DateTime(seconds)

let safeName (s: string) =
    Regex.Replace(
        s,
        @"[^A-Za-z0-9._-]+",
        "-"
    ).Trim('-')

let workoutName (workout: Workout) =
    if not (String.IsNullOrWhiteSpace(workout.DayName)) then
        workout.DayName.Trim()
    elif not (String.IsNullOrWhiteSpace(workout.Program)) then
        workout.Program.Trim()
    else
        "Strength Training"

let workoutExercises (workout: Workout) =
    workout.Sets
    |> List.map (fun set -> set.Exercise.Trim())
    |> List.filter (String.IsNullOrWhiteSpace >> not)
    |> List.distinctBy (fun exercise -> exercise.ToLowerInvariant())

let workoutDescription workout =
    workoutExercises workout
    |> String.concat ", "

// ----------------------------------------------------------------------
// FIT generation
// ----------------------------------------------------------------------

let createFileId (serial: uint32) (startTime: Dynastream.Fit.DateTime) =
    let message = FileIdMesg()
    message.SetType(Dynastream.Fit.File.Activity)
    message.SetManufacturer(Manufacturer.Development)
    message.SetProduct(1us)
    message.SetSerialNumber(serial)
    message.SetTimeCreated(startTime)
    message

let createDeviceInfo (serial: uint32) (startTime: Dynastream.Fit.DateTime) =
    let message = DeviceInfoMesg()
    message.SetDeviceIndex(DeviceIndex.Creator)
    message.SetManufacturer(Manufacturer.Development)
    message.SetProduct(1us)
    message.SetProductName("Liftosaur Import")
    message.SetSerialNumber(serial)
    message.SetSoftwareVersion(1.0f)
    message.SetTimestamp(startTime)
    message

let createTimerEvent
    (timestamp: Dynastream.Fit.DateTime)
    (eventType: EventType) =
    let message = EventMesg()
    message.SetTimestamp(timestamp)
    message.SetEvent(Event.Timer)
    message.SetEventType(eventType)
    message

let createWorkoutSummary workout =
    let exercises = workoutExercises workout
    let message = WorkoutMesg()
    message.SetWktName(workoutName workout)
    message.SetWktDescription(workoutDescription workout)
    message.SetSport(Sport.Training)
    message.SetSubSport(SubSport.StrengthTraining)
    message.SetNumValidSteps(uint16 exercises.Length)
    message

let createWorkoutStep index (exercise: string) =
    let message = WorkoutStepMesg()
    message.SetMessageIndex(uint16 index)
    message.SetWktStepName(exercise)
    message.SetNotes(exercise)
    message.SetDurationType(WktStepDuration.Open)
    message.SetTargetType(WktStepTarget.Open)

    match exerciseCategory exercise with
    | Some(category, subtype) ->
        message.SetExerciseCategory(category)
        if subtype <> UInt16.MaxValue then
            message.SetExerciseName(subtype)
    | None -> ()

    message

let createWorkoutMessages workout =
    let summary = createWorkoutSummary workout :> Mesg
    let steps =
        workoutExercises workout
        |> List.mapi (fun index exercise ->
            createWorkoutStep index exercise :> Mesg)

    summary :: steps

let createSetMessage
    (index: uint16)
    (startDate: DateTimeOffset)
    (duration: float)
    (setType: byte) =
    let message = SetMesg()
    let endDate = startDate.AddSeconds(duration)
    message.SetMessageIndex(index)
    message.SetStartTime(fitTime startDate)
    message.SetTimestamp(fitTime endDate)
    message.SetDuration(float32 duration)
    message.SetSetType(Nullable setType)
    message, endDate

let addExerciseMetadata (set: StrengthSet) (message: SetMesg) =
    match exerciseCategory set.Exercise with
    | Some(category, subtype) ->
        message.SetCategory(0, category)
        if subtype <> UInt16.MaxValue then
            message.SetCategorySubtype(0, subtype)
    | None ->
        message.SetCategory(0, ExerciseCategory.Unknown)

let createActiveSet index startDate duration (set: StrengthSet) =
    let message, endDate =
        createSetMessage index startDate duration SetType.Active

    message.SetRepetitions(uint16 set.Reps)
    message.SetWeight(float32 set.WeightKg)
    addExerciseMetadata set message
    message, endDate

let createRestSet index startDate duration =
    createSetMessage index startDate duration SetType.Rest

let createFitSets (startDate: DateTimeOffset) timeline =
    let messages = ResizeArray<SetMesg>()
    let mutable currentDate = startDate
    let mutable messageIndex = 0us

    let addMessage create =
        let message, endDate = create messageIndex currentDate
        messages.Add(message)
        currentDate <- endDate
        messageIndex <- messageIndex + 1us

    for entry in timeline do
        match entry with
        | ActiveSet(set, duration) ->
            addMessage (fun index date ->
                createActiveSet index date duration set)
        | Rest(_, duration) ->
            addMessage (fun index date ->
                createRestSet index date duration)
        | Transition duration ->
            currentDate <- currentDate.AddSeconds(duration)

    messages

let createLap
    (startTime: Dynastream.Fit.DateTime)
    (endTime: Dynastream.Fit.DateTime)
    (duration: float32) =
    let message = LapMesg()
    message.SetMessageIndex(0us)
    message.SetTimestamp(endTime)
    message.SetStartTime(startTime)
    message.SetTotalElapsedTime(duration)
    message.SetTotalTimerTime(duration)
    message.SetSport(Sport.Training)
    message.SetSubSport(SubSport.StrengthTraining)
    message

let createSession
    (startTime: Dynastream.Fit.DateTime)
    (endTime: Dynastream.Fit.DateTime)
    (duration: float32)
    (name: string) =
    let message = SessionMesg()
    message.SetMessageIndex(0us)
    message.SetTimestamp(endTime)
    message.SetStartTime(startTime)
    message.SetTotalElapsedTime(duration)
    message.SetTotalTimerTime(duration)
    message.SetSport(Sport.Training)
    message.SetSubSport(SubSport.StrengthTraining)
    message.SetSportProfileName(name)
    message.SetFirstLapIndex(0us)
    message.SetNumLaps(1us)
    message

let createActivity
    (endTime: Dynastream.Fit.DateTime)
    (duration: float32) =
    let message = ActivityMesg()
    message.SetTimestamp(endTime)
    message.SetNumSessions(1us)
    message.SetTotalTimerTime(duration)
    message

let encodeFitFile
    path
    (messagesBeforeSets: Mesg list)
    (setMessages: SetMesg seq)
    (messagesAfterSets: Mesg list) =
    use stream =
        new FileStream(
            path,
            FileMode.Create,
            FileAccess.ReadWrite,
            FileShare.Read
        )

    let encoder = Encode(ProtocolVersion.V20)
    encoder.Open(stream)
    messagesBeforeSets |> List.iter encoder.Write
    setMessages |> Seq.iter encoder.Write
    messagesAfterSets |> List.iter encoder.Write
    encoder.Close()

let writeFitFile (workout: Workout) path =
    let timeline = buildTimeline workout
    let startTime = fitTime workout.Start
    let endDate =
        workout.Start.AddSeconds(float workout.DurationSeconds)
    let endTime = fitTime endDate
    let duration = float32 workout.DurationSeconds
    let serial = uint32 (abs (Guid.NewGuid().GetHashCode()))

    let messagesBeforeSets =
        [ createFileId serial startTime :> Mesg
          createDeviceInfo serial startTime :> Mesg ]
        @ createWorkoutMessages workout
        @ [ createTimerEvent startTime EventType.Start :> Mesg ]

    let messagesAfterSets =
        [ createTimerEvent endTime EventType.StopAll :> Mesg
          createLap startTime endTime duration :> Mesg
          createSession
              startTime
              endTime
              duration
              (workoutName workout) :> Mesg
          createActivity endTime duration :> Mesg ]

    let setMessages = createFitSets workout.Start timeline
    encodeFitFile
        path
        messagesBeforeSets
        setMessages
        messagesAfterSets

// ----------------------------------------------------------------------
// Main
// ----------------------------------------------------------------------

let workoutPath outputDir recordId (workout: Workout) =
    let day =
        if String.IsNullOrWhiteSpace(workout.DayName) then
            "strength"
        else
            safeName workout.DayName

    let date = workout.Start.ToString("yyyy-MM-dd_HHmmss")
    Path.Combine(outputDir, $"{date}_{day}_{recordId}.fit")

let countTimelineEntries predicate timeline =
    timeline
    |> List.sumBy (fun entry -> if predicate entry then 1 else 0)

let writeWorkout outputDir record =
    let workout = parseWorkout record.Text
    let path = workoutPath outputDir record.Id workout
    let timeline = buildTimeline workout
    let activeCount =
        countTimelineEntries (function ActiveSet _ -> true | _ -> false) timeline
    let restCount =
        countTimelineEntries (function Rest _ -> true | _ -> false) timeline

    writeFitFile workout path
    printfn
        "Wrote %s (%d active sets, %d rests, %ds session)"
        path
        activeCount
        restCount
        workout.DurationSeconds

let records =
    use http = createClient apiKey
    downloadWorkouts http n None []
    |> Async.RunSynchronously

printfn "Downloaded %d Liftosaur workout(s)." records.Length
records |> List.iter (writeWorkout outputDir)
