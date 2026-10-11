using Toybox.Application.Storage;
using Toybox.Attention;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.Timer;

class LiftosaurStore {
    var api;
    var state;
    var changed;
    var ticker;
    var requestBusy;
    var retryAfter;

    function initialize() {
        api = new LiftosaurApi();
        state = Storage.getValue("workoutState");
        if (state == null) {
            state = { "phase" => "loading", "queue" => [], "status" => "" };
        }
        changed = null;
        requestBusy = false;
        retryAfter = 0;
        ticker = new Timer.Timer();
    }

    function setChanged(callback) {
        changed = callback;
    }

    function isText(value, expected) {
        return value != null && value.equals(expected);
    }

    function copyField(source, destination, key) {
        var value = source.get(key);
        if (value != null) { destination[key] = value; }
    }

    function compactWorkout(workout) {
        var compact = {};
        copyField(workout, compact, "programId");
        copyField(workout, compact, "dayName");
        copyField(workout, compact, "startTime");

        var dayData = workout.get("dayData");
        if (dayData != null) {
            var compactDay = {};
            copyField(dayData, compactDay, "week");
            copyField(dayData, compactDay, "dayInWeek");
            compact["dayData"] = compactDay;
        }

        var entries = workout.get("entries");
        var compactEntries = [];
        for (var i = 0; i < entries.size(); i += 1) {
            var entry = entries[i];
            var compactEntry = {};
            copyField(entry, compactEntry, "entryId");
            copyField(entry, compactEntry, "name");
            compactEntry["hasSuperset"] = entry.get("superset") != null;
            var prompted = entry.get("promptedVars");
            compactEntry["hasPromptedVars"] = prompted != null && prompted.size() > 0;

            var compactSets = [];
            var warmupSets = entry.get("warmupSets");
            if (warmupSets != null) {
                for (var j = 0; j < warmupSets.size(); j += 1) {
                    compactSets.add(compactSet(warmupSets[j], true));
                }
            }
            var sets = entry.get("sets");
            if (sets != null) {
                for (var k = 0; k < sets.size(); k += 1) {
                    compactSets.add(compactSet(sets[k], false));
                }
            }
            compactEntry["sets"] = compactSets;
            compactEntries.add(compactEntry);
        }
        compact["entries"] = compactEntries;
        return compact;
    }

    function compactSet(set, isWarmup) {
        var compact = {};
        copyField(set, compact, "setId");
        compact["isWarmup"] = isWarmup || set.get("isWarmup") == true;
        copyField(set, compact, "reps");
        copyField(set, compact, "weight");
        copyField(set, compact, "isAmrap");
        copyField(set, compact, "timer");
        copyField(set, compact, "askWeight");
        copyField(set, compact, "logRpe");
        copyField(set, compact, "isUnilateral");
        compact["hasSetTimer"] = set.get("setTimer") != null;

        var completed = set.get("completed");
        if (completed != null) {
            var compactCompleted = {};
            copyField(completed, compactCompleted, "reps");
            copyField(completed, compactCompleted, "weight");
            compact["completed"] = compactCompleted;
        }
        return compact;
    }

    function notify() {
        System.println("[Liftosaur] notify phase=" + state.get("phase").toString() + " status=" + state.get("status").toString());
        // A workout response can exceed the simulator/device's remaining
        // object-store capacity. A failed save must not prevent the UI from
        // showing the response that was just received.
        try {
            System.println("[Liftosaur] notify: saving state");
            save();
            System.println("[Liftosaur] notify: state saved");
        } catch (ex) {
            System.println("[Liftosaur] Storage.setValue failed");
            ex.printStackTrace();
            state["status"] = "Workout loaded; watch storage is full";
        }
        System.println("[Liftosaur] notify: requesting view update");
        refreshView();
        System.println("[Liftosaur] notify: view update requested");
    }

    function refreshView() {
        if (changed != null) {
            changed.invoke();
        }
    }

    function save() {
        Storage.setValue("workoutState", state);
    }

    function open() {
        if (state.get("workout") != null) {
            state["workout"] = compactWorkout(state.get("workout"));
        }
        System.println("[Liftosaur] open; API key present=" + api.hasKey().toString());
        if (!api.hasKey()) {
            state["phase"] = "error";
            state["status"] = "Missing API key\ncheck Connect IQ settings";
            notify();
            return;
        }

        if (isActive()) { startTicker(); }
        requestCurrent();
    }

    function isActive() {
        var phase = state.get("phase");
        return isText(phase, "working") || isText(phase, "editing") || isText(phase, "rest") || isText(phase, "complete") || isText(phase, "finishing") || isText(phase, "actions") || isText(phase, "confirm-finish") || isText(phase, "confirm-discard") || isText(phase, "discarding");
    }

    function requestCurrent() {
        if (requestBusy) { return; }
        System.println("[Liftosaur] GET /workout/current");
        requestBusy = true;
        state["status"] = "Checking workout";
        notify();
        api.get("/workout/current", method(:onCurrent));
    }

    function onCurrent(code, data) {
        System.println("[Liftosaur] /workout/current callback code=" + code.toString() + " data=" + (data == null ? "null" : "present"));
        requestBusy = false;
        if (code == 200 && data != null) {
            var envelope = data.get("data");
            var workout = envelope == null ? null : envelope.get("workout");
            if (workout != null) {
                var savedPhase = state.get("phase");
                var viewedSet = currentSet();
                var preserveViewedSet = viewedSet != null && viewedSet.get("completed") != null;
                state["workout"] = compactWorkout(workout);
                state["startedAt"] = workout.get("startTime");
                workout = null;
                envelope = null;
                data = null;
                if (!isActive()) { state["phase"] = "working"; }
                state["status"] = "";
                if (!preserveViewedSet) { normalizeCursor(); }
                if (state.get("finishPending") == true) {
                    state["phase"] = "finishing";
                } else if (isText(savedPhase, "rest")) {
                    state["phase"] = "rest";
                } else if (isText(savedPhase, "editing") && currentSet() != null) {
                    state["phase"] = "editing";
                } else if (isText(savedPhase, "actions") && currentSet() != null) {
                    state["phase"] = "actions";
                } else if (isText(savedPhase, "confirm-finish")) {
                    state["phase"] = "confirm-finish";
                } else if (isText(savedPhase, "confirm-discard")) {
                    state["phase"] = "confirm-discard";
                } else if (isText(savedPhase, "discarding")) {
                    state["phase"] = "confirm-discard";
                    state["status"] = "Tap START to retry discard";
                }
                notify();
                if (state.get("discardPending") == true) {
                    state["discardPending"] = false;
                    discardWorkout();
                    return;
                }
                if (state.get("finishPending") == true && state.get("queue").size() == 0) {
                    sendFinish();
                } else {
                    flushQueue();
                }
                return;
            }
            if (state.get("finishPending") == true) {
                clearWorkout("Workout saved");
                loadNext();
                return;
            }
            if (state.get("queue").size() > 0) {
                state["status"] = "Waiting for saved sets to sync";
                notify();
                flushQueue();
                return;
            }
            clearWorkout("");
            System.println("[Liftosaur] no current workout; fetching next");
            loadNext();
            return;
        }

        if (isActive()) {
            state["status"] = "Offline - workout is saved on the watch";
            notify();
            return;
        }
        setError(code, data);
    }

    function loadNext() {
        if (requestBusy) { return; }
        System.println("[Liftosaur] GET /workout/next");
        requestBusy = true;
        state["phase"] = "loading";
        state["status"] = "Loading next workout";
        notify();
        api.get("/workout/next", method(:onNext));
    }

    function onNext(code, data) {
        requestBusy = false;
        System.println("[Liftosaur] /workout/next callback code=" + code.toString() + " data=" + (data == null ? "null" : "present"));
        if (code == 200 && data != null) {
            var envelope = data.get("data");
            var workout = envelope == null ? null : envelope.get("workout");
            System.println("[Liftosaur] next workout=" + (workout == null ? "null" : "present"));
            if (workout != null) {
                state = { "phase" => "preview", "workout" => compactWorkout(workout), "queue" => [], "status" => "" };
                workout = null;
                envelope = null;
                data = null;
                notify();
                return;
            }
        }
        setError(code, data);
    }

    function startWorkout() {
        if (requestBusy) { return; }
        requestBusy = true;
        state["status"] = "Starting workout";
        notify();
        var dayData = state.get("workout").get("dayData");
        var startBody = {
            "programId" => state.get("workout").get("programId"),
            "week" => dayData.get("week"),
            "dayInWeek" => dayData.get("dayInWeek")
        };
        api.post("/workout/start", startBody, method(:onStartWorkout));
    }

    function onStartWorkout(code, data) {
        requestBusy = false;
        if (code == 200 && data != null) {
            var envelope = data.get("data");
            var workout = envelope == null ? null : envelope.get("workout");
            if (workout != null) {
                state["workout"] = compactWorkout(workout);
                state["phase"] = "working";
                state["startedAt"] = workout.get("startTime");
                workout = null;
                envelope = null;
                data = null;
                state["entryIndex"] = 0;
                state["setIndex"] = 0;
                state["undo"] = null;
                state["queue"] = [];
                state["status"] = "";
                normalizeCursor();
                startTicker();
                notify();
                return;
            }
        }
        setError(code, data);
    }

    function entryAt(index) {
        var entries = state.get("workout").get("entries");
        return index < entries.size() ? entries[index] : null;
    }

    function setAt(entryIndex, setIndex) {
        var entry = entryAt(entryIndex);
        if (entry == null) { return null; }
        var sets = entry.get("sets");
        return setIndex < sets.size() ? sets[setIndex] : null;
    }

    function normalizeCursor() {
        if (state.get("workout") == null) { return; }
        if (state.get("entryIndex") == null) { state["entryIndex"] = 0; }
        if (state.get("setIndex") == null) { state["setIndex"] = 0; }
        var entries = state.get("workout").get("entries");
        var entryIndex = state.get("entryIndex");
        var setIndex = state.get("setIndex");
        while (entryIndex < entries.size()) {
            var entry = entries[entryIndex];
            var sets = entry.get("sets");
            while (setIndex < sets.size()) {
                var set = sets[setIndex];
                if (set.get("completed") == null) {
                    state["entryIndex"] = entryIndex;
                    state["setIndex"] = setIndex;
                    return;
                }
                setIndex += 1;
            }
            entryIndex += 1;
            setIndex = 0;
        }
        state["phase"] = "complete";
        state["entryIndex"] = entries.size();
        state["setIndex"] = 0;
    }

    function currentEntry() {
        return entryAt(state.get("entryIndex") == null ? 0 : state.get("entryIndex"));
    }

    function currentSet() {
        return setAt(state.get("entryIndex") == null ? 0 : state.get("entryIndex"), state.get("setIndex") == null ? 0 : state.get("setIndex"));
    }

    function select() {
        var phase = state.get("phase");
        if (isText(phase, "preview")) {
            if (!supportsWorkout(state.get("workout"))) {
                state["phase"] = "error";
                state["status"] = "This workout has set types not supported in v1";
                notify();
                return;
            }
            startWorkout();
        } else if (isText(phase, "editing")) {
            saveEditedSet();
        } else if (isText(phase, "rest")) {
            var nextSet = currentSet();
            if (nextSet != null && nextSet.get("isAmrap") == true) {
                System.println("[Liftosaur] START during rest; opening AMRAP reps editor");
                skipRest();
                beginEdit(true);
            }
        } else if (isText(phase, "working")) {
            var set = currentSet();
            if (set != null && set.get("completed") != null) {
                state["status"] = "Set already logged";
                notify();
                return;
            }
            if (set != null && set.get("isAmrap") == true) {
                beginEdit(true);
            } else {
                logCurrentSet();
            }
        } else if (isText(phase, "complete")) {
            finishWorkout();
        } else if (isText(phase, "actions")) {
            if (state.get("selectedAction") == 1) {
                state["phase"] = "confirm-discard";
                state["status"] = "This permanently deletes this workout";
                notify();
            } else {
                state["phase"] = "confirm-finish";
                state["status"] = "Press SELECT to finish early";
                notify();
            }
        } else if (isText(phase, "confirm-finish")) {
            finishWorkout();
        } else if (isText(phase, "confirm-discard")) {
            discardWorkout();
        } else if (isText(phase, "rest-done")) {
            finishWorkout();
        }
    }

    function menu() {
        var phase = state.get("phase");
        if (isText(phase, "working") || isText(phase, "rest")) {
            state["phase"] = "actions";
            state["selectedAction"] = 0;
            notify();
        } else if (isText(phase, "actions")) {
            cancelActions();
        } else if (isText(phase, "editing")) {
            return;
        } else if (isText(phase, "confirm-finish")) {
            cancelFinish();
        } else if (isText(phase, "confirm-discard")) {
            cancelDiscard();
        } else if (isActive()) {
            state["phase"] = "confirm-finish";
            state["status"] = "Press SELECT to finish early";
            notify();
        }
    }

    function beginEdit(amrap) {
        var set = currentSet();
        if (set == null) { return; }
        var completed = set.get("completed");
        var reps = completed != null && completed.get("reps") != null ? completed.get("reps") : set.get("reps");
        state["editReps"] = reps == null ? 1 : reps;
        state["editWeight"] = completed != null && completed.get("weight") != null ? completed.get("weight") : set.get("weight");
        state["editField"] = "reps";
        state["editAmrap"] = amrap;
        state["editCompleted"] = completed != null;
        state["phase"] = "editing";
        state["status"] = completed != null ? "Correct logged reps" : "UP/DOWN reps, START log, BACK cancel";
        notify();
    }

    function adjust(direction) {
        if (isText(state.get("phase"), "actions")) {
            var selectedAction = state.get("selectedAction") + direction;
            if (selectedAction < 0) { selectedAction = 1; }
            if (selectedAction > 1) { selectedAction = 0; }
            state["selectedAction"] = selectedAction;
            notify();
            return;
        }
        if (isText(state.get("phase"), "working")) {
            moveSet(direction);
            return;
        }
        if (!isText(state.get("phase"), "editing")) { return; }
        {
            // UP is direction -1 in the navigation layer but adds a rep;
            // DOWN is direction +1 and removes one.
            var newReps = state.get("editReps") - direction;
            state["editReps"] = newReps < 1 ? 1 : newReps;
        }
        notify();
    }

    function moveSet(direction) {
        var workout = state.get("workout");
        if (workout == null) { return; }
        var entries = workout.get("entries");
        var positions = [];
        for (var i = 0; i < entries.size(); i += 1) {
            var sets = entries[i].get("sets");
            for (var j = 0; j < sets.size(); j += 1) {
                positions.add([i, j]);
            }
        }
        if (positions.size() == 0) { return; }
        var current = 0;
        for (var k = 0; k < positions.size(); k += 1) {
            if (positions[k][0] == state.get("entryIndex") && positions[k][1] == state.get("setIndex")) { current = k; break; }
        }
        var next = current + direction;
        if (next < 0) { next = positions.size() - 1; }
        if (next >= positions.size()) { next = 0; }
        state["entryIndex"] = positions[next][0];
        state["setIndex"] = positions[next][1];
        var selected = setAt(positions[next][0], positions[next][1]);
        state["status"] = selected.get("completed") == null ? "" : "Already logged";
        notify();
    }

    function editCurrentReps() {
        var set = currentSet();
        if (set == null) { return; }
        beginEdit(set.get("isAmrap") == true);
    }

    function adjustWeight(direction) {
        var weight = state.get("editWeight");
        if (weight == null) { return; }
        var chars = weight.toCharArray();
        var splitAt = chars.size();
        for (var i = 0; i < chars.size(); i += 1) {
            var c = chars[i].toString().toLower();
            if (c.equals("k") || c.equals("l")) { splitAt = i; break; }
        }
        var value = parseWeight(weight);
        if (value == null) { return; }
        var step = 1.0;
        var newValue = value + (direction * step);
        if (newValue < 0) { newValue = 0; }
        var suffix = weight.substring(splitAt, chars.size());
        state["editWeight"] = newValue.toString() + suffix;
    }

    function parseWeight(weight) {
        if (weight == null) { return null; }
        var chars = weight.toCharArray();
        var splitAt = chars.size();
        for (var i = 0; i < chars.size(); i += 1) {
            var c = chars[i].toString().toLower();
            if (c.equals("k") || c.equals("l")) { splitAt = i; break; }
        }
        return weight.substring(0, splitAt).toFloat();
    }

    function toggleEditField() {
        if (isText(state.get("phase"), "editing") && state.get("editAmrap") != true) {
            state["editField"] = isText(state.get("editField"), "reps") ? "weight" : "reps";
            notify();
        }
    }

    function saveEditedSet() {
        if (!isText(state.get("phase"), "editing")) { return; }
        if (state.get("editCompleted") == true) {
            correctLoggedSet();
            return;
        }
        logCurrentSet();
    }

    function correctLoggedSet() {
        var entry = currentEntry();
        var set = currentSet();
        if (entry == null || set == null || set.get("completed") == null) { return; }
        var completed = { "reps" => state.get("editReps") };
        var weight = state.get("editWeight");
        if (weight != null) { completed["weight"] = weight; }
        enqueue({
            "kind" => "set",
            "correction" => true,
            "entryId" => entry.get("entryId"),
            "setId" => set.get("setId"),
            "completed" => completed,
            "entryIndex" => state.get("entryIndex"),
            "setIndex" => state.get("setIndex")
        });
        state["phase"] = "working";
        state["editCompleted"] = false;
        state["status"] = "Saving correction";
        notify();
        flushQueue();
    }

    function cancelEdit() {
        if (!isText(state.get("phase"), "editing")) { return; }
        state["phase"] = "working";
        state["editCompleted"] = false;
        state["status"] = "";
        notify();
    }

    function cancelFinish() {
        if (!isText(state.get("phase"), "confirm-finish")) { return; }
        state["phase"] = state.get("restEnd") != null && remainingRest() > 0 ? "rest" : (state.get("lastSet") == true ? "complete" : "working");
        state["status"] = "";
        notify();
    }

    function cancelDiscard() {
        if (!isText(state.get("phase"), "confirm-discard")) { return; }
        state["phase"] = state.get("restEnd") != null && remainingRest() > 0 ? "rest" : (state.get("lastSet") == true ? "complete" : "working");
        state["status"] = "Discard canceled";
        notify();
    }

    function cancelActions() {
        if (isText(state.get("phase"), "confirm-finish")) {
            cancelFinish();
            return;
        }
        if (!isText(state.get("phase"), "actions")) { return; }
        state["phase"] = state.get("restEnd") != null && remainingRest() > 0 ? "rest" : (state.get("lastSet") == true ? "complete" : "working");
        state["status"] = "";
        notify();
    }

    function supportsWorkout(workout) {
        if (workout == null) { return false; }
        var entries = workout.get("entries");
        for (var i = 0; i < entries.size(); i += 1) {
            var entry = entries[i];
            if (entry.get("hasSuperset") == true || entry.get("hasPromptedVars") == true) { return false; }
            var sets = entry.get("sets");
            for (var j = 0; j < sets.size(); j += 1) {
                var set = sets[j];
                if (set.get("isWarmup") == true) { continue; }
                if (set.get("askWeight") == true || set.get("logRpe") == true || set.get("isUnilateral") == true || set.get("hasSetTimer") == true) { return false; }
            }
        }
        return true;
    }

    function logCurrentSet() {
        var entry = currentEntry();
        var set = currentSet();
        if (entry == null || set == null) { return; }
        var reps = isText(state.get("phase"), "editing") ? state.get("editReps") : set.get("reps");
        var weight = isText(state.get("phase"), "editing") ? state.get("editWeight") : set.get("weight");
        var completed = { "reps" => reps };
        if (weight != null) { completed["weight"] = weight; }
        var action = {
            "kind" => "set",
            "entryId" => entry.get("entryId"),
            "setId" => set.get("setId"),
            "completed" => completed,
            "entryIndex" => state.get("entryIndex"),
            "setIndex" => state.get("setIndex")
        };
        state["undo"] = action;
        enqueue(action);
        var loggedTimer = set.get("timer");
        state["restEnd"] = Time.now().value() + (loggedTimer == null ? 0 : loggedTimer);
        state["phase"] = "rest";
        state["status"] = "";
        state["entryIndex"] = state.get("entryIndex");
        state["setIndex"] = state.get("setIndex") + 1;
        normalizeCursor();
        state["lastSet"] = isText(state.get("phase"), "complete");
        state["phase"] = "rest";
        startTicker();
        notify();
        flushQueue();
    }

    function undo() {
        if (state.get("undo") == null || !isActive() || isText(state.get("phase"), "finishing")) { return; }
        var last = state.get("undo");
        var undoAction = {
            "kind" => "set",
            "entryId" => last.get("entryId"),
            "setId" => last.get("setId"),
            "completed" => null
        };
        enqueue(undoAction);
        state["entryIndex"] = last.get("entryIndex");
        state["setIndex"] = last.get("setIndex");
        state["phase"] = "working";
        state["restEnd"] = null;
        state["status"] = "Set undone";
        state["undo"] = null;
        ticker.stop();
        notify();
        flushQueue();
    }

    function skipRest() {
        if (!isText(state.get("phase"), "rest")) { return; }
        ticker.stop();
        state["restEnd"] = null;
        state["phase"] = state.get("lastSet") == true ? "complete" : "working";
        state["status"] = "Rest skipped";
        notify();
    }

    function enqueue(action) {
        var queue = state.get("queue");
        if (queue == null) { queue = []; }
        queue.add(action);
        state["queue"] = queue;
    }

    function flushQueue() {
        var queue = state.get("queue");
        if (queue == null || queue.size() == 0) { return; }
        if (requestBusy) {
            System.println("[Liftosaur] set sync skipped; request already busy queue=" + queue.size().toString());
            return;
        }
        requestBusy = true;
        var action = queue[0];
        if (isText(action.get("kind"), "set")) {
            System.println("[Liftosaur] set sync sending setId=" + action.get("setId").toString() + " queue=" + queue.size().toString());
            var body = {
                "entryId" => action.get("entryId"),
                "setId" => action.get("setId"),
                "completed" => action.get("completed")
            };
            api.post("/workout/set", body, method(:onSetSynced));
        }
    }

    function onSetSynced(code, data) {
        var responseQueue = state.get("queue");
        System.println("[Liftosaur] set sync callback code=" + code.toString() + " data=" + (data == null ? "null" : "present") + " queue=" + (responseQueue == null ? "null" : responseQueue.size().toString()));
        requestBusy = false;
        if (code != 200 || data == null) {
            state["status"] = code <= 0 ? "Offline - set saved on watch" : "Set not accepted - check supported set types";
            retryAfter = Time.now().value() + (code <= 0 ? 15 : 60);
            if (state.get("discardPending") == true) {
                state["discardPending"] = false;
                discardWorkout();
                return;
            }
            notify();
            return;
        }
        var pendingQueue = state.get("queue");
        var syncedAction = pendingQueue.size() > 0 ? pendingQueue[0] : null;
        var isCorrection = syncedAction != null && syncedAction.get("correction") == true;
        var savedPhase = state.get("phase");
        var viewedSet = currentSet();
        var preserveViewedSet = isText(savedPhase, "working") && viewedSet != null && viewedSet.get("completed") != null;
        var envelope = data.get("data");
        var updatedWorkout = envelope == null ? null : envelope.get("workout");
        if (updatedWorkout != null) {
            state["workout"] = compactWorkout(updatedWorkout);
            updatedWorkout = null;
            envelope = null;
            data = null;
            if (isCorrection) {
                state["entryIndex"] = syncedAction.get("entryIndex");
                state["setIndex"] = syncedAction.get("setIndex");
                state["phase"] = "working";
            } else if (preserveViewedSet) {
                // A sync may arrive after the lifter has browsed back to a
                // completed set. Keep that view instead of snapping forward.
            } else {
                normalizeCursor();
                if (isText(savedPhase, "rest")) { state["phase"] = "rest"; }
            }
        }
        var queue = state.get("queue");
        if (queue.size() > 0) { queue.remove(queue[0]); }
        state["queue"] = queue;
        if (queue.size() == 0) { state["status"] = isCorrection ? "Reps corrected" : ""; }
        notify();
        if (state.get("discardPending") == true) {
            state["discardPending"] = false;
            discardWorkout();
            return;
        }
        if (queue.size() > 0) {
            flushQueue();
        } else if (state.get("finishPending") == true) {
            sendFinish();
        }
    }

    function finishWorkout() {
        if (state.get("workout") == null) { return; }
        state["phase"] = "finishing";
        state["finishPending"] = true;
        state["endTime"] = Time.now().value() * 1000;
        state["status"] = "Saving workout";
        notify();
        if (state.get("queue").size() > 0) {
            flushQueue();
        } else {
            sendFinish();
        }
    }

    function discardWorkout() {
        if (requestBusy) {
            state["discardPending"] = true;
            state["phase"] = "discarding";
            state["status"] = "Waiting for sync to discard";
            notify();
            return;
        }
        if (state.get("workout") == null || state.get("startedAt") == null) { return; }
        requestBusy = true;
        state["phase"] = "discarding";
        state["status"] = "Discarding workout";
        System.println("[Liftosaur] DELETE /workout/current startTime=" + state.get("startedAt").toString());
        notify();
        api.delete("/workout/current", { "startTime" => state.get("startedAt") }, method(:onDiscarded));
    }

    function onDiscarded(code, data) {
        requestBusy = false;
        System.println("[Liftosaur] DELETE /workout/current callback code=" + code.toString());
        System.println("[Liftosaur] discard response=" + (data == null ? "null" : data.toString()));
        if (code == 200) {
            clearWorkout("Workout discarded");
            loadNext();
        } else {
            state["discardPending"] = false;
            state["phase"] = "confirm-discard";
            state["status"] = code <= 0 ? "Offline - discard not sent" : "Discard failed: " + code.toString();
            notify();
        }
    }

    function sendFinish() {
        if (requestBusy || state.get("finishPending") != true) { return; }
        if (state.get("queue").size() > 0) { flushQueue(); return; }
        requestBusy = true;
        api.post("/workout/finish", {
            "startTime" => state.get("startedAt"),
            "endTime" => state.get("endTime")
        }, method(:onFinished));
    }

    function onFinished(code, data) {
        requestBusy = false;
        if (code == 200) {
            clearWorkout("Workout saved");
            loadNext();
        } else {
            state["phase"] = "finishing";
            state["status"] = "Offline - finish will sync when connected";
            retryAfter = Time.now().value() + 15;
            notify();
        }
    }

    function clearWorkout(message) {
        ticker.stop();
        state = { "phase" => "loading", "queue" => [], "status" => message };
        notify();
    }

    function startTicker() {
        ticker.start(method(:tick), 1000, true);
    }

    function tick() {
        if (isActive() && state.get("queue") != null && state.get("queue").size() > 0 && !requestBusy && Time.now().value() >= retryAfter) {
            System.println("[Liftosaur] set sync retry timer queue=" + state.get("queue").size().toString());
            retryAfter = Time.now().value() + 15;
            flushQueue();
        }
        if (isText(state.get("phase"), "rest") && state.get("restEnd") != null) {
            var remaining = state.get("restEnd") - Time.now().value();
            if (remaining <= 0) {
                ticker.stop();
                if (Attention has :vibrate) {
                    Attention.vibrate([ new Attention.VibeProfile(100, 500) ]);
                }
                if (state.get("lastSet") == true) {
                    state["phase"] = "complete";
                } else {
                    state["phase"] = "working";
                }
                state["status"] = "";
                notify();
                return;
            }
            refreshView();
        } else if (isText(state.get("phase"), "finishing")) {
            if (Time.now().value() >= retryAfter) {
                retryAfter = Time.now().value() + 15;
                if (state.get("queue").size() > 0) { flushQueue(); }
                else { sendFinish(); }
            }
        }
    }

    function remainingRest() {
        if (state.get("restEnd") == null) { return 0; }
        var remaining = state.get("restEnd") - Time.now().value();
        return remaining < 0 ? 0 : remaining;
    }

    function setError(code, data) {
        state["phase"] = "error";
        if (code == 401) {
            state["status"] = "Check API key in Connect IQ settings";
        } else if (code == 403) {
            state["status"] = "Liftosaur Premium is required";
        } else if (code <= 0) {
            state["status"] = "No connection - try again";
        } else {
            state["status"] = "Liftosaur request failed: " + code.toString();
        }
        notify();
    }
}
