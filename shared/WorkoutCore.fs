module WorkoutCore

open System
open System.Text.RegularExpressions

type StrengthSet =
    { Exercise: string
      Reps: int
      WeightKg: float
      IsWarmup: bool
      RestAfterSeconds: float }

type Workout =
    { Start: DateTimeOffset
      DurationSeconds: int
      Program: string
      DayName: string
      Sets: StrengthSet list }

let quotedField name (text: string) =
    let m =
        Regex.Match(
            text,
            $"""{Regex.Escape(name)}:\s*"([^"]*)"""
        )

    if m.Success then
        m.Groups[1].Value
    else
        ""

let toKg value (unitName: string) =
    match unitName.ToLowerInvariant() with
    | "kg" ->
        value

    | "lb"
    | "lbs" ->
        value * 0.45359237

    | _ ->
        value

// Parses:
//   1x5 42.5kg
//   3x5 32.5kg
//
// Expands 3x5 into three individual sets.
let parseCompletedSets exercise isWarmup (text: string) =
    Regex.Matches(
        text,
        @"(\d+)x(\d+)\s+([0-9]+(?:\.[0-9]+)?)(kg|lb|lbs)"
    )
    |> Seq.cast<Match>
    |> Seq.collect (fun m ->

        let count =
            int m.Groups[1].Value

        let reps =
            int m.Groups[2].Value

        let weight =
            float m.Groups[3].Value

        let unitName =
            m.Groups[4].Value

        seq {
            for _ in 1 .. count do
                yield
                    reps,
                    toKg weight unitName
        })
    |> Seq.map (fun (reps, kg) ->
        { Exercise = exercise
          Reps = reps
          WeightKg = kg
          IsWarmup = isWarmup
          RestAfterSeconds = 0.0 })
    |> Seq.toList

// Parses target timing:
//
//   1x5 32.5kg 180s,
//   1x5 37.5kg 180s,
//   1x5+ 42.5kg 240s,
//   3x5 32.5kg 120s
//
// and expands it to:
//   [180; 180; 240; 120; 120; 120]
let parseTargetRests (text: string) =
    Regex.Matches(
        text,
        @"(\d+)x(?:\d+|\d+\+)\s+" +
        @"[0-9]+(?:\.[0-9]+)?(?:kg|lb|lbs|%)\s+" +
        @"(\d+)s"
    )
    |> Seq.cast<Match>
    |> Seq.collect (fun m ->

        let count =
            int m.Groups[1].Value

        let seconds =
            float m.Groups[2].Value

        seq {
            for _ in 1 .. count do
                yield seconds
        })
    |> Seq.toList

let tryExerciseSection name (parts: string array) =
    let prefix = name + ":"

    parts
    |> Array.skip 2
    |> Array.tryFind (fun part ->
        part.TrimStart().StartsWith(
            prefix,
            StringComparison.OrdinalIgnoreCase
        ))
    |> Option.map (fun part ->
        part.Substring(part.IndexOf(':') + 1))

let assignRestSeconds defaultSeconds restSeconds sets =
    sets
    |> List.mapi (fun index set ->
        { set with
            RestAfterSeconds =
                restSeconds
                |> List.tryItem index
                |> Option.defaultValue defaultSeconds })

let removeFinalRest sets =
    match List.rev sets with
    | [] -> []
    | last :: preceding ->
        { last with RestAfterSeconds = 0.0 } :: preceding
        |> List.rev

let regexGroupOrDefault
    (pattern: string)
    (groupName: string)
    defaultValue
    (text: string) =
    let result = Regex.Match(text, pattern)
    if result.Success then result.Groups[groupName].Value else defaultValue

let parseExerciseLine (line: string) =
    let parts =
        line.Trim().Split(
            " / ",
            StringSplitOptions.None
        )

    if parts.Length < 2 then
        []
    else
        let exercise = parts[0].Trim()
        let working =
            parseCompletedSets exercise false parts[1]

        let warmups =
            tryExerciseSection "warmup" parts
            |> Option.map (parseCompletedSets exercise true)
            |> Option.defaultValue []

        let targetRests =
            tryExerciseSection "target" parts
            |> Option.map parseTargetRests
            |> Option.defaultValue []

        let warmupsWithRest =
            warmups
            |> List.map (fun set ->
                { set with RestAfterSeconds = 60.0 })

        let workingWithRest =
            assignRestSeconds 90.0 targetRests working

        warmupsWithRest @ workingWithRest
        |> removeFinalRest

let parseWorkoutStart (text: string) =
    let firstSlash = text.IndexOf(" / ")
    if firstSlash < 0 then
        failwith $"Cannot parse workout: {text}"

    text.Substring(0, firstSlash).Trim()
    |> fun timestamp ->
        DateTimeOffset.Parse(
            timestamp,
            Globalization.CultureInfo.InvariantCulture)

let parseWorkoutSets text =
    regexGroupOrDefault
        @"exercises:\s*\{(?<body>[\s\S]*?)\}\s*$"
        "body"
        ""
        text
    |> fun block ->
        block.Split(
            [| '\r'; '\n' |],
            StringSplitOptions.RemoveEmptyEntries)
    |> Array.collect (parseExerciseLine >> List.toArray)
    |> Array.toList

let parseWorkout (text: string) =
    let duration =
        regexGroupOrDefault @"duration:\s*(?<seconds>\d+)s" "seconds" "3600" text
        |> int

    { Start = parseWorkoutStart text
      DurationSeconds = duration
      Program = quotedField "program" text
      DayName = quotedField "dayName" text
      Sets = parseWorkoutSets text }
