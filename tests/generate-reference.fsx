#load "../garminFit.fsx"

open System.IO
open System
open System.Text.Json
open WorkoutCore
open GarminFit

let fixtures = Path.Combine(__SOURCE_DIRECTORY__, "fixtures")
let output = Path.Combine(__SOURCE_DIRECTORY__, "output")
Directory.CreateDirectory(output) |> ignore
for fixture in Directory.GetFiles(fixtures, "*.txt") do
    let workout = File.ReadAllText(fixture) |> parseWorkout
    writeFitFile workout (Path.Combine(output, Path.GetFileNameWithoutExtension(fixture) + ".fit"))
printfn "Generated .NET reference FIT files."

// Exercise every shared mapping through the actual .NET message writers.
// The browser tests compare these SDK-resolved numeric fields with decoded FIT output.
let number (value: Nullable<uint16>) =
    if value.HasValue && value.Value <> UInt16.MaxValue then int value.Value else -1
let metadata =
    exerciseMappings
    |> Map.toArray
    |> Array.map (fun (name, _) ->
        let step = createWorkoutStep 0 name
        let set = { Exercise = name; Reps = 5; WeightKg = 10.; IsWarmup = false; RestAfterSeconds = 0. }
        let message, _ = createActiveSet 0us (DateTimeOffset(2026, 3, 1, 10, 0, 0, TimeSpan.Zero)) 60. set
        {| name = name
           stepCategory = number (step.GetExerciseCategory())
           stepSubtype = number (step.GetExerciseName())
           setCategory = number (message.GetCategory(0))
           setSubtype = number (message.GetCategorySubtype(0)) |})
File.WriteAllText(Path.Combine(output, "exercise-mappings.json"), JsonSerializer.Serialize(metadata))
