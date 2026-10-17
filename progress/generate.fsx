#load "../liftosaur.fsx"

open System
open System.Globalization
open System.IO
open System.Text.Json
open Liftosaur

type WeekSummary =
    { WeekStart: string
      Workouts: int }

type StrengthPoint =
    { Date: string
      WeightKg: float
      Reps: int
      Estimated1RmKg: float }

type ExerciseSummary =
    { Name: string
      Points: StrengthPoint array }

type ProgressData =
    { GeneratedAtUtc: string
      TotalWorkouts: int
      Weeks: WeekSummary array
      Exercises: ExerciseSummary array }

let apiKey = Environment.GetEnvironmentVariable("LIFTOSAUR_API_KEY")

if String.IsNullOrWhiteSpace(apiKey) then
    failwith "Set the LIFTOSAUR_API_KEY environment variable before generating progress data."

let fetchAllWorkouts (client: System.Net.Http.HttpClient) =
    let records = ResizeArray<LiftosaurRecord>()
    let mutable cursor: int64 option = None
    let mutable hasMore = true

    while hasMore do
        let page = getPage client 200 cursor |> Async.RunSynchronously
        records.AddRange(page.Records)

        if page.HasMore then
            match page.NextCursor with
            | Some next when Some next <> cursor && page.Records.Length > 0 ->
                cursor <- Some next
            | _ ->
                failwith "Liftosaur returned an invalid history cursor. No output was written."
        else
            hasMore <- false

    records |> Seq.toArray

let dateText (date: DateTime) =
    date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)

let weekStart (date: DateTime) =
    let daysSinceMonday = (int date.DayOfWeek + 6) % 7
    date.Date.AddDays(-float daysSinceMonday)

let canonicalLift (exercise: string) =
    match exercise.Trim().ToLowerInvariant() with
    | "squat"
    | "squat, barbell" -> Some "Squat"
    | "bench press"
    | "bench press, barbell" -> Some "Bench press"
    | "deadlift"
    | "deadlift, barbell" -> Some "Deadlift"
    | "overhead press"
    | "overhead press, barbell"
    | "strict military press" -> Some "Overhead press"
    | _ -> None

let client = createClient apiKey
let records = fetchAllWorkouts client

let workouts =
    records
    |> Array.map (fun record ->
        try
            record, parseWorkout record.Text
        with error ->
            raise (InvalidDataException($"Could not parse Liftosaur workout {record.Id}.", error)))

let weekCounts =
    workouts
    |> Seq.groupBy (fun (_, workout) -> weekStart workout.Start.Date)
    |> Seq.map (fun (week, items) -> week, Seq.length items)
    |> Map.ofSeq

let weeks =
    match weekCounts |> Map.toSeq |> Seq.map fst |> Seq.toArray with
    | [||] -> [||]
    | dates ->
        let first = Array.min dates
        let last = Array.max dates
        [| for offset in 0 .. int ((last - first).TotalDays / 7.0) do
               let date = first.AddDays(float (offset * 7))
               yield
                   { WeekStart = dateText date
                     Workouts = weekCounts |> Map.tryFind date |> Option.defaultValue 0 } |]

let exercisePoints =
    workouts
    |> Seq.collect (fun (_, workout) ->
        workout.Sets
        |> Seq.filter (fun set -> not set.IsWarmup && set.WeightKg > 0.0 && not (String.IsNullOrWhiteSpace(set.Exercise)))
        |> Seq.choose (fun set -> canonicalLift set.Exercise |> Option.map (fun name -> name, set))
        |> Seq.groupBy fst
        |> Seq.map (fun (name, namedSets) ->
            let sets = namedSets |> Seq.map snd
            let best = sets |> Seq.maxBy (fun set -> set.WeightKg, set.Reps)
            name,
            { Date = dateText workout.Start.Date
              WeightKg = best.WeightKg
              Reps = best.Reps
              Estimated1RmKg = best.WeightKg * (1.0 + float best.Reps / 30.0) }))
    |> Seq.groupBy fst
    |> Seq.map (fun (name, entries) ->
        { Name = name
          Points =
            entries
            |> Seq.map snd
            |> Seq.sortBy (fun point -> point.Date)
            |> Seq.toArray })
    |> Seq.sortBy (fun exercise -> exercise.Name.ToLowerInvariant())
    |> Seq.toArray

let data =
    { GeneratedAtUtc = DateTime.UtcNow.ToString("O", CultureInfo.InvariantCulture)
      TotalWorkouts = workouts.Length
      Weeks = weeks
      Exercises = exercisePoints }

let options = JsonSerializerOptions(WriteIndented = true, PropertyNamingPolicy = JsonNamingPolicy.CamelCase)
let outputPath = Path.Combine(__SOURCE_DIRECTORY__, "site", "data.json")
Directory.CreateDirectory(Path.GetDirectoryName(outputPath)) |> ignore
File.WriteAllText(outputPath, JsonSerializer.Serialize(data, options))
client.Dispose()

printfn "Generated public summaries from %d workouts: %s" workouts.Length outputPath
