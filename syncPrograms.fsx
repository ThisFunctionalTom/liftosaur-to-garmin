// Usage: dotnet fsi syncPrograms.fsx -- push|pull
// Set LIFTOSAUR_API_KEY first. Programs live beside this script in programs/*.liftoscript.
// Each .name sidecar contains the original program name, used for updates and creation.
// Without a sidecar, push matches sanitized remote names or creates using the filename.
// Pull downloads all programs, overwriting local files. Neither command deletes.
#load "liftosaur.fsx"

open System
open System.IO
open System.Collections.Generic
open Liftosaur

let requireUniqueNames (comparer: IEqualityComparer<string>) (names: string list) =
    let seen = HashSet<string>(comparer)
    for name in names do
        if not (seen.Add(name)) then
            failwith $"Duplicate program name: '{name}'. Rename the duplicates before syncing."

let safeProgramName (name: string) =
    let invalidChars = Path.GetInvalidFileNameChars()
    let sanitized =
        name
        |> Seq.map (fun c ->
            if Array.contains c invalidChars then '-' else c)
        |> Seq.toArray
        |> fun chars -> String(chars).TrimEnd('.', ' ')
    let sanitized = if String.IsNullOrWhiteSpace(sanitized) then "Program" else sanitized
    let stem = (sanitized.Split('.')[0]).ToUpperInvariant()
    let reserved =
        [ "CON"; "PRN"; "AUX"; "NUL"
          for n in 1 .. 9 do
              $"COM{n}"
              $"LPT{n}" ]
    if List.contains stem reserved then "_" + sanitized else sanitized

let localPath directory name =
    Path.Combine(directory, safeProgramName name + ".liftoscript")

let push http directory =
    async {
        if not (Directory.Exists(directory)) then
            failwith $"Directory does not exist: {directory}. Create it with .liftoscript programs, or run pull first."
        let files =
            Directory.GetFiles(directory)
            |> Array.filter (fun path -> Path.GetExtension(path) = ".liftoscript")
            |> Array.sort
        let local =
            files |> Array.map (fun path ->
                let namePath = Path.ChangeExtension(path, ".name")
                let explicitName =
                    if File.Exists(namePath) then
                        let name = File.ReadAllText(namePath).TrimEnd('\r', '\n')
                        if String.IsNullOrWhiteSpace(name) then
                            failwith $"Program name is empty: {namePath}"
                        Some name
                    else None
                Path.GetFileNameWithoutExtension(path), explicitName, File.ReadAllText(path))
        let! remote = listPrograms http
        requireUniqueNames StringComparer.OrdinalIgnoreCase (remote |> List.map (fun p -> safeProgramName p.Name))
        let byName = remote |> List.map (fun p -> p.Name, p.Id) |> Map.ofList
        let originalNames = remote |> List.map (fun p -> safeProgramName p.Name, p.Name) |> Map.ofList
        let local =
            local |> Array.map (fun (filename, explicitName, text) ->
                let name =
                    explicitName
                    |> Option.defaultWith (fun () ->
                        Map.tryFind filename originalNames |> Option.defaultValue filename)
                name, text)
        requireUniqueNames StringComparer.Ordinal (local |> Array.map fst |> Array.toList)
        for name, text in local do
            match Map.tryFind name byName with
            | Some id ->
                let! _ = updateProgram http id None text
                printfn "Updated %s" name
            | None ->
                let! _ = uploadProgram http name text
                printfn "Created %s" name
        printfn "Pushed %d program(s)." local.Length
    }

let pull http directory =
    async {
        let! programs = downloadPrograms http
        // Validate all filenames before overwriting anything.
        requireUniqueNames StringComparer.OrdinalIgnoreCase (programs |> List.map (fun p -> safeProgramName p.Name))
        let files =
            programs |> List.collect (fun p ->
                let path = localPath directory p.Name
                [ path, p.Text; Path.ChangeExtension(path, ".name"), p.Name ])
        let existing =
            if Directory.Exists(directory) then Directory.GetFiles(directory) else [||]
        for path, _ in files do
            for current in existing do
                if String.Equals(path, current, StringComparison.OrdinalIgnoreCase) && path <> current then
                    failwith $"Filename casing conflict: '{current}' and '{path}'. Rename the local file before pulling."
        Directory.CreateDirectory(directory) |> ignore
        for path, text in files do
            File.WriteAllText(path, text)
            printfn "Downloaded %s" (Path.GetFileName(path))
        printfn "Pulled %d program(s)." programs.Length
    }

let main (args: string array) =
    try
        let sync =
            match args with
            | [| "push" |] -> push
            | [| "pull" |] -> pull
            | _ -> failwith "Usage: dotnet fsi syncPrograms.fsx -- push|pull"
        let apiKey = Environment.GetEnvironmentVariable("LIFTOSAUR_API_KEY")
        if String.IsNullOrWhiteSpace(apiKey) then
            failwith "Set LIFTOSAUR_API_KEY first."
        use http = createClient apiKey
        sync http (Path.Combine(__SOURCE_DIRECTORY__, "programs")) |> Async.RunSynchronously
        0
    with error ->
        eprintfn "%s" error.Message
        1

// Loading this script for tests does not run the CLI.
if Path.GetFullPath(fsi.CommandLineArgs[0]) = Path.Combine(__SOURCE_DIRECTORY__, __SOURCE_FILE__) then
    exit (main (fsi.CommandLineArgs |> Array.skip 1))
