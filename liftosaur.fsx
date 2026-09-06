// Usage from another script:
// #load "liftosaur.fsx"
// open Liftosaur
// use client = createClient "lftsk_..."
// let records = downloadWorkouts client 10 None [] |> Async.RunSynchronously
// let workouts = records |> List.map (fun record -> parseWorkout record.Text)
// let programs = downloadPrograms client |> Async.RunSynchronously
// let current = downloadProgram client "current" |> Async.RunSynchronously
// let created = uploadProgram client "My Program" current.Text |> Async.RunSynchronously
// let updated = updateProgram client created.Id None current.Text |> Async.RunSynchronously

open System
open System.Net.Http
open System.Net.Http.Headers
open System.Text
open System.Text.Json
open System.Text.RegularExpressions

// ----------------------------------------------------------------------
// Types
// ----------------------------------------------------------------------

type LiftosaurProgramSummary =
    { Id: string
      Name: string
      IsCurrent: bool }

type LiftosaurProgram =
    { Id: string
      Name: string
      Text: string
      IsCurrent: bool }

type LiftosaurRecord =
    { Id: int64
      Text: string }

type LiftosaurPage =
    { Records: LiftosaurRecord list
      HasMore: bool
      NextCursor: int64 option }

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

// ----------------------------------------------------------------------
// Liftosaur API
// ----------------------------------------------------------------------

// The caller owns and disposes the client.
let createClient (apiKey: string) =
    let http = new HttpClient()
    http.BaseAddress <- Uri("https://www.liftosaur.com/api/v1/")
    http.DefaultRequestHeaders.Authorization <-
        AuthenticationHeaderValue("Bearer", apiKey)
    http

let responseData (root: JsonElement) =
    match root.TryGetProperty("data") with
    | true, data -> data
    | _ -> root

let parseRecord (element: JsonElement) : LiftosaurRecord =
    { Id = element.GetProperty("id").GetInt64()
      Text = element.GetProperty("text").GetString() }

let booleanProperty (name: string) (element: JsonElement) =
    match element.TryGetProperty(name) with
    | true, value -> value.GetBoolean()
    | _ -> false

let int64Property (name: string) (element: JsonElement) =
    match element.TryGetProperty(name) with
    | true, value when value.ValueKind = JsonValueKind.Number ->
        Some(value.GetInt64())
    | _ -> None

let parseProgram (element: JsonElement) : LiftosaurProgram =
    { Id = element.GetProperty("id").GetString()
      Name = element.GetProperty("name").GetString()
      Text = element.GetProperty("text").GetString()
      IsCurrent = booleanProperty "isCurrent" element }

let programPath (programId: string) =
    if String.IsNullOrWhiteSpace(programId) then
        invalidArg "programId" "A program ID or 'current' is required."
    "programs/" + Uri.EscapeDataString(programId)

let requestProgramData
    (http: HttpClient)
    (method: HttpMethod)
    (path: string)
    (body: string option) =
    async {
        use request = new HttpRequestMessage(method, path)
        body |> Option.iter (fun json ->
            request.Content <- new StringContent(json, Encoding.UTF8, "application/json"))

        use! response = http.SendAsync(request) |> Async.AwaitTask
        let! json = response.Content.ReadAsStringAsync() |> Async.AwaitTask

        if not response.IsSuccessStatusCode then
            // Include Liftoscript validation errors and their line numbers.
            raise (HttpRequestException(
                $"Liftosaur API returned {int response.StatusCode} ({response.ReasonPhrase}): {json}",
                null,
                Nullable response.StatusCode))

        use doc = JsonDocument.Parse(json)
        return (responseData doc.RootElement).Clone()
    }

// Lists program metadata; use downloadProgram to retrieve Liftoscript source.
let listPrograms (http: HttpClient) =
    async {
        let! data = requestProgramData http HttpMethod.Get "programs" None
        return
            data.GetProperty("programs").EnumerateArray()
            |> Seq.map (fun element ->
                { Id = element.GetProperty("id").GetString()
                  Name = element.GetProperty("name").GetString()
                  IsCurrent = booleanProperty "isCurrent" element })
            |> Seq.toList
    }

// Pass "current" to download the active program.
let downloadProgram (http: HttpClient) (programId: string) =
    async {
        let! data = requestProgramData http HttpMethod.Get (programPath programId) None
        return parseProgram data
    }

// Downloads the full source for every program, in the order returned by the API.
let downloadPrograms (http: HttpClient) =
    async {
        let! summaries = listPrograms http
        let programs = ResizeArray<LiftosaurProgram>()
        for summary in summaries do
            let! program = downloadProgram http summary.Id
            programs.Add(program)
        return Seq.toList programs
    }

// Creates a new program from Liftoscript and returns its assigned ID and source.
let uploadProgram (http: HttpClient) (name: string) (text: string) =
    async {
        let body = JsonSerializer.Serialize({| name = name; text = text |})
        let! data = requestProgramData http HttpMethod.Post "programs" (Some body)
        return parseProgram data
    }

// Replaces an existing program's source. None keeps its name; Some renames it.
// Pass "current" as the ID to update the active program.
let updateProgram (http: HttpClient) (programId: string) (name: string option) (text: string) =
    async {
        let body =
            match name with
            | Some name -> JsonSerializer.Serialize({| name = name; text = text |})
            | None -> JsonSerializer.Serialize({| text = text |})
        let! data = requestProgramData http HttpMethod.Put (programPath programId) (Some body)
        return parseProgram data
    }

let getPage (http: HttpClient) limit cursor =
    async {
        let cursorPart =
            cursor
            |> Option.map (fun x -> $"&cursor={x}")
            |> Option.defaultValue ""

        let url =
            $"history?limit={limit}{cursorPart}"

        use! response =
            http.GetAsync(url)
            |> Async.AwaitTask

        response.EnsureSuccessStatusCode() |> ignore

        let! json =
            response.Content.ReadAsStringAsync()
            |> Async.AwaitTask

        use doc = JsonDocument.Parse(json)

        // Some API responses wrap this in "data", some don't.
        let data = responseData doc.RootElement

        let records =
            data.GetProperty("records").EnumerateArray()
            |> Seq.map parseRecord
            |> Seq.toList

        return
            { Records = records
              HasMore = booleanProperty "hasMore" data
              NextCursor = int64Property "nextCursor" data }
    }

let rec downloadWorkouts (http: HttpClient) remaining cursor acc =
    async {
        if remaining <= 0 then
            return List.rev acc

        else
            let limit = min remaining 200
            let! page = getPage http limit cursor

            let acc' =
                List.rev page.Records @ acc

            let remaining' =
                remaining - page.Records.Length

            if page.HasMore && remaining' > 0 then
                return!
                    downloadWorkouts
                        http
                        remaining'
                        page.NextCursor
                        acc'
            else
                return List.rev acc'
    }

// ----------------------------------------------------------------------
// Parsing helpers
// ----------------------------------------------------------------------

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

