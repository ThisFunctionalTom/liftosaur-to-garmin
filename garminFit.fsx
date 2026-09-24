#r "nuget: Garmin.FIT.Sdk"
#load "liftosaur.fsx"
#load "shared/WorkoutConversion.fs"

open System
open System.IO
open Dynastream.Fit
open WorkoutCore
open WorkoutConversion

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

    // Assisted variants use the base movement; unmatched equipment gets category only.
    | "lat pulldown"
    | "lat pulldown, machine" ->
        Some(ExerciseCategory.PullUp, PullUpExerciseName.LatPulldown)

    | "hanging leg raise" ->
        Some(ExerciseCategory.LegRaise, LegRaiseExerciseName.HangingLegRaise)

    | "hanging knee raise" ->
        Some(ExerciseCategory.LegRaise, LegRaiseExerciseName.HangingKneeRaise)

    | "pull up, assisted"
    | "pull up, leverage machine" ->
        Some(ExerciseCategory.PullUp, PullUpExerciseName.PullUp)

    | "chin up, assisted"
    | "chin up, leverage machine" ->
        Some(ExerciseCategory.PullUp, PullUpExerciseName.ChinUp)

    | "triceps dip"
    | "triceps dip, leverage machine"
    | "chest dip, assisted" ->
        Some(ExerciseCategory.TricepsExtension, TricepsExtensionExerciseName.BodyWeightDip)

    | "seated row" ->
        Some(ExerciseCategory.Row, RowExerciseName.SeatedCableRow)

    | "seated row, machine" ->
        Some(ExerciseCategory.Row, RowExerciseName.Row)

    | "lunge, dumbbell" ->
        Some(ExerciseCategory.Lunge, LungeExerciseName.DumbbellLunge)

    | "incline push up" ->
        Some(ExerciseCategory.PushUp, PushUpExerciseName.InclinePushUp)

    | "bench press, smith machine" ->
        Some(ExerciseCategory.BenchPress, BenchPressExerciseName.SmithMachineBenchPress)

    | "incline bench press" ->
        Some(ExerciseCategory.BenchPress, BenchPressExerciseName.InclineBarbellBenchPress)

    | "incline bench press, dumbbell" ->
        Some(ExerciseCategory.BenchPress, BenchPressExerciseName.InclineDumbbellBenchPress)

    | "overhead press, dumbbell" ->
        Some(ExerciseCategory.ShoulderPress, ShoulderPressExerciseName.OverheadDumbbellPress)

    | "overhead press, smith machine" ->
        Some(ExerciseCategory.ShoulderPress, ShoulderPressExerciseName.SmithMachineOverheadPress)

    | "strict military press" ->
        Some(ExerciseCategory.ShoulderPress, ShoulderPressExerciseName.MilitaryPress)

    | "stiff leg deadlift" ->
        Some(ExerciseCategory.Deadlift, DeadliftExerciseName.BarbellStraightLegDeadlift)

    | "zercher squat" ->
        Some(ExerciseCategory.Squat, SquatExerciseName.ZercherSquat)

    | "squat, machine" ->
        Some(ExerciseCategory.Squat, SquatExerciseName.Squat)

    | "leg press" ->
        Some(ExerciseCategory.Squat, SquatExerciseName.LegPress)

    | "lying leg curl, machine" ->
        Some(ExerciseCategory.LegCurl, LegCurlExerciseName.LegCurl)

    | "seated calf raise, machine" ->
        Some(ExerciseCategory.CalfRaise, CalfRaiseExerciseName.SeatedCalfRaise)

    | "crunch, machine"
    | "decline crunch" ->
        Some(ExerciseCategory.Crunch, CrunchExerciseName.Crunch)

    | "bicep curl" ->
        Some(ExerciseCategory.Curl, CurlExerciseName.DumbbellBicepsCurl)

    | "lateral raise" ->
        Some(ExerciseCategory.LateralRaise, LateralRaiseExerciseName.DumbbellLateralRaise)

    | "back extension"
    | "back extension, machine" ->
        Some(ExerciseCategory.Hyperextension, UInt16.MaxValue)

    | "bicep curl, machine" ->
        Some(ExerciseCategory.Curl, UInt16.MaxValue)

    | "chest fly" ->
        Some(ExerciseCategory.Flye, UInt16.MaxValue)

    | "chest press, machine"
    | "iso-lateral chest press, machine"
    | "incline chest press" ->
        Some(ExerciseCategory.BenchPress, UInt16.MaxValue)

    | "shoulder press, machine" ->
        Some(ExerciseCategory.ShoulderPress, UInt16.MaxValue)

    | "lateral raise, machine" ->
        Some(ExerciseCategory.LateralRaise, UInt16.MaxValue)

    | "hip thrust" ->
        Some(ExerciseCategory.HipRaise, UInt16.MaxValue)

    | "hip abductor, machine"
    | "hip adductor, machine"
    | "glute kickback, machine" ->
        Some(ExerciseCategory.HipStability, UInt16.MaxValue)

    | "skullcrusher" ->
        Some(ExerciseCategory.TricepsExtension, UInt16.MaxValue)

    | "triceps pushdown, cable, straight bar" ->
        Some(ExerciseCategory.TricepsExtension, TricepsExtensionExerciseName.TricepsPressdown)

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
