#load "syncPrograms.fsx"

open System
open System.IO
open System.Net
open System.Net.Http
open System.Text.Json
open Liftosaur
open SyncPrograms

let check condition message =
    if not condition then failwith message

type MockApi(initial: LiftosaurProgram list) =
    inherit HttpMessageHandler()
    let programs = ResizeArray<LiftosaurProgram>(initial)
    let writes = ResizeArray<string>()
    member _.Programs = programs
    member _.Writes = writes
    override _.SendAsync(request, _) =
        task {
            let path = request.RequestUri.AbsolutePath
            let programJson (p: LiftosaurProgram) =
                JsonSerializer.Serialize({| id = p.Id; name = p.Name; text = p.Text; isCurrent = p.IsCurrent |})
            let! json = task {
                if request.Method = HttpMethod.Get then
                    if path.EndsWith("/programs") then
                        return "{\"programs\":[" + (programs |> Seq.map programJson |> String.concat ",") + "]}"
                    else
                        let id = path.Substring(path.LastIndexOf('/') + 1)
                        return programs |> Seq.find (fun p -> p.Id = id) |> programJson
                else
                    writes.Add(request.Method.Method)
                    let! body = request.Content.ReadAsStringAsync()
                    use doc = JsonDocument.Parse(body)
                    let text = doc.RootElement.GetProperty("text").GetString()
                    if request.Method = HttpMethod.Post then
                        let p = { Id = Guid.NewGuid().ToString(); Name = doc.RootElement.GetProperty("name").GetString(); Text = text; IsCurrent = false }
                        programs.Add(p)
                        return programJson p
                    else
                        check (request.Method = HttpMethod.Put) "Unexpected mutation"
                        let id = path.Substring(path.LastIndexOf('/') + 1)
                        let index = programs |> Seq.findIndex (fun p -> p.Id = id)
                        let p = { programs[index] with Text = text }
                        programs[index] <- p
                        return programJson p
            }
            let response = new HttpResponseMessage(HttpStatusCode.OK)
            response.Content <- new StringContent("{\"data\":" + json + "}")
            return response
        }

let expectFailure fragment action =
    let error =
        try action (); None
        with error -> Some error.Message
    check (error |> Option.exists (fun message -> message.Contains(fragment: string))) $"Expected error containing {fragment}"

let testSync () =
    let directory = Path.Combine(__SOURCE_DIRECTORY__, ".sync-test-" + Guid.NewGuid().ToString("N"))
    Directory.CreateDirectory(directory) |> ignore
    try
        let existing = { Id = "existing"; Name = "Existing"; Text = "old"; IsCurrent = true }
        let remoteOnly = { existing with Id = "remote"; Name = "Remote only" }
        use api = new MockApi([ existing; remoteOnly ])
        use http = new HttpClient(api, false)
        http.BaseAddress <- Uri("https://example.test/api/v1/")
        let localText = "# Week 1\n## Day 1\n// \"quotes\" café\nSquat / 3x5 / 20kg"
        File.WriteAllText(Path.Combine(directory, "Existing.liftoscript"), localText)
        File.WriteAllText(Path.Combine(directory, "New.liftoscript"), "new source")
        File.WriteAllText(Path.Combine(directory, "ignored.txt"), "ignore me")
        push http directory |> Async.RunSynchronously
        check (api.Programs.Count = 3 && Seq.toList api.Writes = [ "PUT"; "POST" ]) "Push must update and create by name"
        check (api.Programs[0].Text = localText && api.Programs[1] = remoteOnly) "Push lost source or changed an unrelated program"
        push http directory |> Async.RunSynchronously
        check (api.Programs.Count = 3) "Repeated push created duplicates"

        api.Programs[0] <- { existing with Text = "remote edits" }
        File.WriteAllText(Path.Combine(directory, "Orphan.liftoscript"), "keep me")
        pull http directory |> Async.RunSynchronously
        check (File.ReadAllText(Path.Combine(directory, "Existing.liftoscript")) = "remote edits") "Pull did not overwrite"
        check (File.ReadAllText(Path.Combine(directory, "Remote only.liftoscript")) = "old") "Pull missed a remote program"
        check (File.ReadAllText(Path.Combine(directory, "Orphan.liftoscript")) = "keep me") "Pull deleted a local program"

        let writesBefore = api.Writes.Count
        api.Programs.Add({ existing with Id = "duplicate" })
        expectFailure "Duplicate" (fun () -> push http directory |> Async.RunSynchronously)
        check (api.Writes.Count = writesBefore) "Duplicate check happened after writing"
        expectFailure "Duplicate" (fun () -> pull http directory |> Async.RunSynchronously)
        api.Programs.RemoveAt(api.Programs.Count - 1)
        api.Programs.Add({ existing with Id = "unsafe"; Name = "../escape" })
        let bbb = { existing with Id = "bbb"; Name = "5/3/1: Boring But Big" }
        api.Programs.Add(bbb)
        api.Programs.Add({ existing with Id = "reserved"; Name = "CON" })
        pull http directory |> Async.RunSynchronously
        let bbbPath = Path.Combine(directory, "5-3-1- Boring But Big.liftoscript")
        check (File.ReadAllText(bbbPath) = bbb.Text) "Forbidden characters were not replaced"
        check (File.ReadAllText(Path.ChangeExtension(bbbPath, ".name")) = bbb.Name) "Pull did not save the original name"
        check (File.Exists(Path.Combine(directory, "..-escape.liftoscript"))) "Path separators were not sanitized"
        check (File.Exists(Path.Combine(directory, "_CON.liftoscript"))) "Reserved filename was not handled"
        File.WriteAllText(bbbPath, "updated BBB")
        let countBefore = api.Programs.Count
        // Remove the intentionally local-only fixture before checking a pure round-trip.
        File.Delete(Path.Combine(directory, "Orphan.liftoscript"))
        push http directory |> Async.RunSynchronously
        check (api.Programs.Count = countBefore) "Sanitized filenames created duplicate programs"
        let updated = api.Programs |> Seq.find (fun p -> p.Id = bbb.Id)
        check (updated.Name = bbb.Name && updated.Text = "updated BBB") "Push failed to preserve the original program name"

        api.Programs.Remove(updated) |> ignore
        push http directory |> Async.RunSynchronously
        let recreated = api.Programs |> Seq.find (fun p -> p.Name = bbb.Name)
        check (recreated.Text = "updated BBB" && api.Programs.Count = countBefore) "Recreation lost the sidecar's original name"

        let customPath = Path.Combine(directory, "Custom.liftoscript")
        let customNamePath = Path.ChangeExtension(customPath, ".name")
        File.WriteAllText(customPath, "custom source")
        File.WriteAllText(customNamePath, "Custom: Original Name\r\n")
        push http directory |> Async.RunSynchronously
        check (api.Programs |> Seq.exists (fun p -> p.Name = "Custom: Original Name" && p.Text = "custom source")) "New program ignored its sidecar"
        File.WriteAllText(customNamePath, " \r\n")
        let writesBefore = api.Writes.Count
        expectFailure "empty" (fun () -> push http directory |> Async.RunSynchronously)
        check (api.Writes.Count = writesBefore) "Empty sidecar validation happened after writes"
        File.WriteAllText(customNamePath, bbb.Name)
        expectFailure "Duplicate" (fun () -> push http directory |> Async.RunSynchronously)
        check (api.Writes.Count = writesBefore) "Duplicate local names were not rejected before writes"
        File.WriteAllText(customNamePath, "Custom: Original Name")

        api.Programs.Add({ existing with Id = "collision"; Name = "5-3-1- Boring But Big" })
        api.Programs[0] <- { existing with Text = "must not write" }
        let writesBefore = api.Writes.Count
        expectFailure "Duplicate" (fun () -> pull http directory |> Async.RunSynchronously)
        expectFailure "Duplicate" (fun () -> push http directory |> Async.RunSynchronously)
        check (api.Writes.Count = writesBefore) "Filename collision check happened after remote writes"
        check (File.ReadAllText(Path.Combine(directory, "Existing.liftoscript")) = "remote edits") "Filename collision check happened after local writes"
    finally
        // Only remove files inside this test's unique directory; no recursive deletion.
        Directory.GetFiles(directory) |> Array.iter File.Delete
        Directory.Delete(directory)

testSync ()
printfn "Program sync tests passed."
