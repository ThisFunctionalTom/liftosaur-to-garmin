#load "garminFit.fsx"

open System
open System.IO
open GarminFit
open Liftosaur
open WorkoutConversion

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
