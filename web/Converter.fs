module Converter

open System
open WorkoutCore
open WorkoutConversion

// Plain records form the boundary between shared F# and the Garmin JS adapter.
type FitSet =
    { startTime: float
      timestamp: float
      duration: float
      active: bool
      exercise: string
      repetitions: int
      weight: float }

type FitWorkout =
    { startTime: float
      timestamp: float
      duration: int
      name: string
      description: string
      exercises: string array
      exerciseNotes: string array
      sets: FitSet array }

let fitSeconds (date: DateTimeOffset) =
    // Keep fractional time while building the timeline; FIT timestamps use seconds.
    float (date.ToUnixTimeMilliseconds()) / 1000.0 - 631065600.0

let prepareWorkout text =
    let workout = parseWorkout text
    if workout.Sets.IsEmpty then
        invalidArg "text" "No completed sets found. Paste a Liftosaur API workout record."
    let mutable current = fitSeconds workout.Start
    let sets = ResizeArray<FitSet>()
    for entry in buildTimeline workout do
        match entry with
        | Transition seconds -> current <- current + seconds
        | ActiveSet(_, _) | Rest(_, _) ->
            let seconds, active, exercise, reps, weight =
                match entry with
                | ActiveSet(set, seconds) -> seconds, true, set.Exercise, set.Reps, exportedWeight set
                | Rest(exercise, seconds) -> seconds, false, exercise, 0, 0.0
                | Transition _ -> failwith "Unexpected transition"
            let finish = current + seconds
            sets.Add
                { startTime = floor current
                  timestamp = floor finish
                  duration = seconds
                  active = active
                  exercise = exercise
                  repetitions = reps
                  weight = weight }
            current <- finish
    { startTime = floor (fitSeconds workout.Start)
      timestamp = floor (fitSeconds (workout.Start.AddSeconds(float workout.DurationSeconds)))
      duration = workout.DurationSeconds
      name = workoutName workout
      description = workoutDescription workout
      exercises = workoutExercises workout |> List.toArray
      exerciseNotes = workoutExercises workout |> List.map (exerciseNotes workout) |> List.toArray
      sets = sets.ToArray() }
