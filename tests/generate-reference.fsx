#load "../garminFit.fsx"

open System.IO
open WorkoutCore
open GarminFit

let fixtures = Path.Combine(__SOURCE_DIRECTORY__, "fixtures")
let output = Path.Combine(__SOURCE_DIRECTORY__, "output")
Directory.CreateDirectory(output) |> ignore
for fixture in Directory.GetFiles(fixtures, "*.txt") do
    let workout = File.ReadAllText(fixture) |> parseWorkout
    writeFitFile workout (Path.Combine(output, Path.GetFileNameWithoutExtension(fixture) + ".fit"))
printfn "Generated .NET reference FIT files."
