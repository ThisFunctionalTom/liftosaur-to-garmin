#load "shared/WorkoutCore.fs"
#load "shared/WorkoutConversion.fs"

open System
open WorkoutCore
open WorkoutConversion

let check condition message =
    if not condition then failwith message

let close expected actual message =
    check (abs (expected - actual) < 0.0001) message

let text = """2026-03-01T10:00:00Z / program: "Test" / dayName: "Push Day" / duration: 600s / exercises: {
Bench Press, Barbell / 2x5 100lb / warmup: 1x5 20kg / target: 2x5 100lb 120s
Overhead Press / 1x10 20kg
}"""

let workout = parseWorkout text
check (workout.Start = DateTimeOffset(2026, 3, 1, 10, 0, 0, TimeSpan.Zero)) "Workout start changed"
check (workout.DurationSeconds = 600 && workout.Sets.Length = 4) "Workout structure changed"
check workout.Sets.Head.IsWarmup "Warmup must precede working sets"
close 45.359237 workout.Sets[1].WeightKg "Pounds conversion changed"
check (workout.Sets |> List.map (fun s -> s.RestAfterSeconds) = [60.; 120.; 0.; 0.]) "Rest assignment changed"
check (workoutName workout = "Push Day") "Workout name changed"
check (workoutDescription workout = "Bench Press, Barbell, Overhead Press") "Exercise order changed"

let duration = function
    | ActiveSet(_, seconds) | Rest(_, seconds) | Transition seconds -> seconds

let timeline = buildTimeline workout
close 600. (timeline |> List.sumBy duration) "Timeline must fill recorded duration"
check (timeline |> List.filter (function ActiveSet _ -> true | _ -> false) |> List.length = 4) "Active sets lost"
close 345. (timeline |> List.sumBy (function Transition s -> s | _ -> 0.)) "Leftover time must go to exercise transition"

let compressed = buildTimeline { workout with DurationSeconds = 120 }
close 120. (compressed |> List.sumBy duration) "Programmed rests must shrink to fit"
close 45. (compressed |> List.sumBy (function Rest(_, s) -> s | _ -> 0.)) "Compressed rest budget incorrect"

// Preserve the existing estimate when recorded time is shorter than active sets.
let short = buildTimeline { workout with DurationSeconds = 10 }
close 75. (short |> List.sumBy duration) "Active duration estimate changed"
check (buildTimeline { workout with Sets = [] } = []) "Empty workout must have no timeline"
check (workoutName { workout with DayName = " "; Program = "" } = "Strength Training") "Fallback name changed"
printfn "Conversion regression tests passed."
