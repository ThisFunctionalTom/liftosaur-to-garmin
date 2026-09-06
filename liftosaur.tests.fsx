#load "liftosaur.fsx"

open System
open System.Net
open System.Net.Http
open System.Text.Json
open System.Threading.Tasks
open Liftosaur

let check condition message =
    if not condition then failwith message

let source = "# Week 1\n## Day 1\n// \"quoted\" \\ café\nSquat / 3x5 / 20kg"
let programJson = JsonSerializer.Serialize({| id = "abc"; name = "Test"; text = source |})
let requests = ResizeArray<string * string * string>()

type MockHandler() =
    inherit HttpMessageHandler()
    override _.SendAsync(request, _) =
        task {
            let! body =
                if isNull request.Content then Task.FromResult("")
                else request.Content.ReadAsStringAsync()
            let path = request.RequestUri.AbsolutePath
            requests.Add(request.Method.Method, path, body)
            if request.Method <> HttpMethod.Get then
                check (request.Content.Headers.ContentType.MediaType = "application/json") "Expected JSON"
            let status, json =
                if path.EndsWith("/invalid") then
                    HttpStatusCode.UnprocessableEntity, "{\"error\":\"Invalid Liftoscript at line 3\"}"
                elif path.EndsWith("/missing") then
                    HttpStatusCode.NotFound, "{\"error\":\"Program not found\"}"
                elif path.EndsWith("/programs") && request.Method = HttpMethod.Get then
                    HttpStatusCode.OK, "{\"data\":{\"programs\":[{\"id\":\"abc\",\"name\":\"Test\",\"isCurrent\":true}]}}"
                elif request.Method = HttpMethod.Post then
                    HttpStatusCode.Created, programJson
                else
                    HttpStatusCode.OK, "{\"data\":" + programJson + "}"
            let response = new HttpResponseMessage(status)
            response.Content <- new StringContent(json)
            return response
        }

let run = Async.RunSynchronously

let testPrograms () =
    use http = new HttpClient(new MockHandler())
    http.BaseAddress <- Uri("https://example.test/api/v1/")
    let summaries = listPrograms http |> run
    check (summaries.Length = 1 && summaries.Head.IsCurrent) "Program metadata missing"
    requests.Clear()
    let programs = downloadPrograms http |> run
    check (programs.Length = 1 && programs.Head.Text = source) "Full program download failed"
    check (requests.Count = 2) "Expected list followed by source download"
    downloadProgram http "current" |> run |> ignore
    check (let _, path, _ = requests[2] in path.EndsWith("/current")) "Current program route incorrect"
    check (programPath "a/b?c" = "programs/a%2Fb%3Fc") "Program ID was not escaped"

    let created = uploadProgram http "Test" source |> run
    check (created.Id = "abc" && created.Text = source && not created.IsCurrent) "Create response incorrect"
    let method, _, body = requests[3]
    use payload = JsonDocument.Parse(body)
    check (method = "POST" && payload.RootElement.GetProperty("text").GetString() = source) "Upload corrupted source"
    updateProgram http created.Id None source |> run |> ignore
    let method, _, body = requests[4]
    use payload = JsonDocument.Parse(body)
    check (method = "PUT" && not (fst (payload.RootElement.TryGetProperty("name")))) "Update must omit absent name"
    updateProgram http created.Id (Some "Renamed") source |> run |> ignore
    let _, _, body = requests[5]
    use payload = JsonDocument.Parse(body)
    check (payload.RootElement.GetProperty("name").GetString() = "Renamed") "Rename missing"

    for id, status, message in
        [ "invalid", HttpStatusCode.UnprocessableEntity, "line 3"
          "missing", HttpStatusCode.NotFound, "Program not found" ] do
        try
            updateProgram http id None source |> run |> ignore
            failwith "Expected HTTP failure"
        with :? HttpRequestException as error ->
            check (error.StatusCode = Nullable status && error.Message.Contains(message)) "API error details lost"

testPrograms ()
printfn "Program API tests passed."
