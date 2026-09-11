module WorkoutConversion

open System
open System.Text.RegularExpressions
open WorkoutCore

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
